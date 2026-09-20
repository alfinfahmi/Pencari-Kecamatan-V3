import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'hisab_detail.dart';

/// Dilempar saat tahun Hijriah yg diminta di luar rentang yg didukung
/// tabel gerak rata-rata Tashilul Amtsilah (1350H-1650H). Pesannya sengaja
/// dalam Bahasa Indonesia krn ditujukan utk ditampilkan langsung ke
/// pengguna (bukan cuma log developer).
class TashilulRentangTahunException implements Exception {
  final int tahunHijriahDiminta;
  TashilulRentangTahunException({required this.tahunHijriahDiminta});

  @override
  String toString() =>
      'Tashilul Amtsilah hanya mendukung tahun ${HisabTashilulAmtsilahService.tahunHijriahMinimum}H-'
      '${HisabTashilulAmtsilahService.tahunHijriahMaksimum}H. '
      'Tahun $tahunHijriahDiminta H di luar rentang tabel rujukan.';
}

/// Hisab Awal Bulan versi kitab Tashilul Amtsilah (Awwalusy Syuhur) --
/// sistem zij klasik (tabel gerak rata-rata + interpolasi, notasi Arab
/// derajat-menit-detik/Burj), di-porting dari file Excel rujukan LF
/// Ma'had 'Aly Lirboyo.
///
/// CATATAN JUJUR -- STATUS PORTING: implementasi ini dikerjakan BERTAHAP
/// lewat proses penelusuran manual formula Excel yang sangat panjang
/// (puluhan sesi). Setiap tahap divalidasi terhadap kasus uji dari file
/// sumber (Ijtimak Shafar 1448H = Selasa 14 Juli 2026, markaz Kediri:
/// φ=-7.7130861, λ=112.205775, TZ=+7). Hasil akhir tervalidasi SANGAT
/// DEKAT (bukan 100% exact -- ada residu beberapa detik busur di sejumlah
/// tahap, sudah didokumentasikan & diterima sesuai keputusan bersama):
///   - Bujur matahari final, deklinasi matahari: EXACT match
///   - Jam ijtimak: 16:40 vs referensi 16:41 (selisih 1 menit)
///   - Tinggi hilal hakiki/mar'i, elongasi: selisih beberapa detik busur
///   - Azimut matahari/bulan: EXACT match (TERVALIDASI thd sheet Output
///     file asli, konvensi "dari titik Barat ke Utara" -- WAJIB dikonversi
///     ke konvensi standar Utara-searah-jarum-jam spy konsisten dgn 3
///     metode lain di aplikasi ini, lihat fungsi hitungLengkap()).
///
/// WAJIB divalidasi ulang terhadap rujukan resmi sebelum dipakai
/// operasional, sama seperti disclaimer 3 metode hisab lain di aplikasi.
///
/// Ditemukan & didokumentasikan 2 typo di file Excel sumber (bug referensi
/// baris-12 yg diperbaiki mengikuti pola baris-14 yg benar; formula tanda
/// "OC459" yg seharusnya "OC45=9", diikuti pola simetri yg jelas).
///
/// Data tabel: assets/data/tashilul/data_tabel.json (21 tabel gabungan,
/// diekstrak dari file Excel sumber).
class HisabTashilulAmtsilahService {
  HisabTashilulAmtsilahService._();
  static final HisabTashilulAmtsilahService instance = HisabTashilulAmtsilahService._();

  Map<String, dynamic>? _data;
  bool _dimuat = false;

  Future<void> _muatData() async {
    if (_dimuat) return;
    final raw = await rootBundle.loadString('assets/data/tashilul/data_tabel.json');
    _data = json.decode(raw) as Map<String, dynamic>;
    _dimuat = true;
  }

  /// Pemuatan data AWAL, publik -- WAJIB dipanggil (di-await) sekali sebelum
  /// memakai versi *Sync di bawah (dipakai `_metodeList` di
  /// hisab_awal_bulan_screen.dart, yg butuh fungsi SINKRON, bukan Future).
  Future<void> muatDataAwal() => _muatData();

  /// True kalau data tabel sudah siap dipakai versi *Sync.
  bool get sudahSiap => _dimuat;

  // ========================================================================
  // UTILITAS SEXAGESIMAL (derajat-menit-detik dengan Burj/tanda zodiak 0-11)
  // ========================================================================

  /// Menjumlahkan beberapa baris [Burj,derajat,menit,detik] jadi satu hasil,
  /// dengan carry & bungkus-Burj (mod 12) -- pola dari baris "10" Excel
  /// (SUM 4 baris tahun-komposit+tahun-sisa+bulan+hari), pola SAMA dipakai
  /// baris "17" (SUM row10..16, tafawut+proyeksi jam/menit).
  /// 108000 = detik busur dalam 1 Burj (30° x 3600).
  static List<num> jumlahkanSexagesimal(List<List<num>> barisBarisNilai) {
    num totalDetikBusur = 0;
    for (final b in barisBarisNilai) {
      final burj = b[0], d = b[1], m = b[2], s = b[3];
      totalDetikBusur += burj * 108000 + d * 3600 + m * 60 + s;
    }
    var burjHasil = (totalDetikBusur / 108000).floor() % 12;
    if (burjHasil < 0) burjHasil += 12;
    final sisaSetelahBurj = totalDetikBusur % 108000;
    final derajat = (sisaSetelahBurj / 3600).floor();
    final sisaSetelahDerajat = sisaSetelahBurj % 3600;
    final menit = (sisaSetelahDerajat / 60).floor();
    final detik = sisaSetelahDerajat % 60;
    return [burjHasil, derajat, menit, detik];
  }

  /// Konversi [Burj,derajat,menit,detik] ke derajat desimal penuh (0-360).
  static double keDesimal(List<num> bdms) {
    return bdms[0] * 30 + bdms[1] + bdms[2] / 60 + bdms[3] / 3600;
  }

  List<num> _bdms(Map<String, dynamic> baris, String kunci) {
    final l = baris[kunci] as List;
    return l.map((e) => e as num).toList();
  }

  /// Posisi rata-rata (Burj,d,m,s) utk salah satu dari 5 besaran
  /// (ws_matahari/khas_matahari/ws_bulan/khas_bulan/simpul_bulan), gabungan
  /// tahun-komposit + tahun-sisa + bulan + hari -- pola baris 6-10 Excel.
  /// TERVALIDASI EXACT thd kasus uji (113,04056° utk ws_matahari).
  /// Batas tahun Hijriah yg didukung tabel gerak rata-rata (1350H-1650H,
  /// ~1931-2223 M) -- di luar ini, [TashilulRentangTahunException] dilempar
  /// alih-alih diam-diam memberi hasil salah.
  static const tahunHijriahMinimum = 1351;
  static const tahunHijriahMaksimum = 1680;

  List<num> posisiRataRata({
    required int tahunHijriah,
    required int bulanTarget,
    required int tanggalHisab,
    required String kunciBesaran,
  }) {
    final i2 = bulanTarget == 1 ? 12 : bulanTarget - 1;
    final j3 = bulanTarget == 1 ? tahunHijriah - 1 : tahunHijriah;
    final o3 = i2 == 1 ? 12 : i2 - 1;
    final p4 = o3 == 12 ? j3 - 2 : j3 - 1;

    if (p4 < tahunHijriahMinimum || p4 > tahunHijriahMaksimum) {
      throw TashilulRentangTahunException(tahunHijriahDiminta: tahunHijriah);
    }

    final tahunKomposit = _data!['tahun_komposit'] as Map<String, dynamic>;
    final tahunSimple = _data!['tahun_simple'] as Map<String, dynamic>;
    final bulanTabel = _data!['bulan'] as Map<String, dynamic>;
    final hariTabel = _data!['hari'] as Map<String, dynamic>;

    int p6 = 0;
    for (final k in tahunKomposit.keys) {
      final thn = int.parse(k);
      if (thn < p4 && thn > p6) p6 = thn;
    }
    final p7 = p4 - p6;

    final b1 = _bdms(tahunKomposit[p6.toString()] as Map<String, dynamic>, kunciBesaran);
    final b2 = _bdms(tahunSimple[p7.toString()] as Map<String, dynamic>, kunciBesaran);
    final b3 = _bdms(bulanTabel[o3.toString()] as Map<String, dynamic>, kunciBesaran);
    final b4 = _bdms(hariTabel[tanggalHisab.toString()] as Map<String, dynamic>, kunciBesaran);

    return jumlahkanSexagesimal([b1, b2, b3, b4]);
  }

  /// Interpolasi generik ke salah satu dari 10 tabel koreksi besar (equation
  /// matahari, 5 tahap bujur bulan, anomali-tahap2, node, sabq-I/II/III).
  /// Pola Excel: `A - (A-B)*C/1`, A=tabel[floor(kunci)], B=tabel[floor(kunci)+1].
  ///
  /// WRAP: kasus normal, derajat 30 dibungkus ke 0 DALAM Burj yg sama
  /// (`IF(FD46+1<31,FD46+1,0)`, TERVERIFIKASI dari formula asli). KASUS
  /// KHUSUS di titik paling ujung tabel (Burj=11 DAN derajat=30 sekaligus)
  /// -- TERVERIFIKASI dari formula asli (`IF(AND(FD45=11,FD46=30),0,FD45)`)
  /// -- titik B menyeberang ke Burj=0,derajat=0.
  double interpolasiTabel(String namaTabel, int burjTarget, double kunciDerajat) {
    final tabel = _data![namaTabel] as Map<String, dynamic>;
    final jah1 = kunciDerajat.floor();
    final diUjungTabel = burjTarget == 11 && jah1 == 30;
    final burjB = diUjungTabel ? 0 : burjTarget;
    final jah2 = diUjungTabel ? 0 : (jah1 + 1) % 31;
    final baris1 = (tabel[jah1.toString()] as List)[burjTarget] as List;
    final baris2 = (tabel[jah2.toString()] as List)[burjB] as List;
    final a = (baris1[0] as num) + (baris1[1] as num) / 60 + (baris1[2] as num) / 3600;
    final b = (baris2[0] as num) + (baris2[1] as num) / 60 + (baris2[2] as num) / 3600;
    final c = kunciDerajat - jah1;
    return a - (a - b) * c;
  }

  /// Deklinasi matahari dari bujur ekliptika matahari (rumus standar,
  /// obliquity 23°27' -- SAMA persis dgn AP35 Excel).
  double _deklinasiDariBujur(double bujurMatahariDerajat) {
    const obliquity = 23 + 27 / 60;
    final sinDek = math.sin(obliquity * math.pi / 180) * math.sin(bujurMatahariDerajat * math.pi / 180);
    return math.asin(sinDek) * 180 / math.pi;
  }

  /// Sudut waktu (jam) ke ufuk dgn depresi tertentu -- rumus standar SAMA
  /// dgn AP36 Excel: ACOS(-tan(lat)*tan(dek)+sin(depresi)/cos(lat)/cos(dek))/15.
  double _sudutWaktuJam(double lintangDerajat, double deklinasiDerajat, double depresiDerajat) {
    final lat = lintangDerajat * math.pi / 180;
    final dek = deklinasiDerajat * math.pi / 180;
    final dep = depresiDerajat * math.pi / 180;
    final cosH = -math.tan(lat) * math.tan(dek) + math.sin(dep) / math.cos(lat) / math.cos(dek);
    return math.acos(cosH.clamp(-1.0, 1.0)) * 180 / math.pi / 15;
  }

  /// Sudut waktu KASAR (jam) ke ufuk -1°, dari bujur matahari row10 SAJA
  /// (mean, belum tafawut/koreksi) -- dipakai sbg argumen T14/T15 (baris
  /// 14-15 Excel, persis AM38=INT(AP36) & AN38=bagian menitnya).
  double _sudutWaktuKasarUntukProyeksi({
    required List<num> row10WsMatahari,
    required double lintang,
  }) {
    final bujurMatahari = keDesimal(row10WsMatahari);
    final dek = _deklinasiDariBujur(bujurMatahari);
    return _sudutWaktuJam(lintang, dek, -1.0);
  }

  static const _kunciBesaran = ['ws_matahari', 'khas_matahari', 'ws_bulan', 'khas_bulan', 'simpul_bulan'];

  /// Lookup T11 (koreksi tafawut) -- tabel dakaik_tafawut cuma 1 angka per
  /// sel (bukan sexagesimal), dan Excel pakai MATCH APPROXIMATE (bukan
  /// interpolasi linear).
  int _lookupTafawut(int burjMatahari, double derajatMatahari) {
    final tabel = _data!['dakaik_tafawut'] as Map<String, dynamic>;
    final derajatBulat = derajatMatahari.floor().clamp(0, 29);
    final baris = tabel[derajatBulat.toString()] as List;
    return (baris[burjMatahari] as num).toInt();
  }

  /// Lookup dakaik_saah (menit->[menit,detik] per besaran) -- dipakai
  /// baris 11,13,15 Excel (BUKAN 14 -- lihat _lookupGerakPerJam).
  List<num> _lookupDakaikSaah(int menit, String kunciBesaran) {
    if (menit == 0) return [0, 0];
    final tabel = _data!['dakaik_saah'] as Map<String, dynamic>;
    final baris = tabel[menit.toString()] as Map<String, dynamic>;
    final l = baris[kunciBesaran] as List;
    return [l[0] as num, l[1] as num];
  }

  /// Lookup gerak_per_jam (jam 1-24 -> [d,m,s] per besaran) -- dipakai
  /// baris 12 & 14 Excel (proyeksi JAM). BEDA dari dakaik_saah.
  List<num> _lookupGerakPerJam(int jam, String kunciBesaran) {
    if (jam == 0) return [0, 0, 0];
    final tabel = _data!['gerak_per_jam'] as Map<String, dynamic>;
    final baris = tabel[jam.toString()] as Map<String, dynamic>;
    final l = baris[kunciBesaran] as List;
    return [l[0] as num, l[1] as num, l[2] as num];
  }

  /// Rantai baris 10->17 LENGKAP (mean + tafawut + proyeksi jam/menit) utk
  /// KELIMA besaran sekaligus -- mengembalikan Map{kunci: row17 [Burj,d,m,s]}.
  ///
  /// Baris 12 (koreksi jam akibat selisih bujur lokasi vs 112°): file Excel
  /// SUMBER punya bug referensi (kolom tanpa prefix "Data!", + kolom
  /// tersalah). Diperbaiki di sini dgn pola SAMA PERSIS dgn baris 14 (yg
  /// TERBUKTI benar & tervalidasi exact) -- baris 14 & 12 SAMA-SAMA
  /// "proyeksi N jam pakai tabel gerak_per_jam", bedanya cuma sumber N-nya.
  Map<String, List<num>> rantaiMeanTafawutProyeksi({
    required int tahunHijriah,
    required int bulanTarget,
    required int tanggalHisab,
    required double lintang,
    required double bujurLokasi,
  }) {
    final row10 = <String, List<num>>{};
    for (final k in _kunciBesaran) {
      row10[k] = posisiRataRata(
        tahunHijriah: tahunHijriah, bulanTarget: bulanTarget,
        tanggalHisab: tanggalHisab, kunciBesaran: k,
      );
    }

    final burjMatahari = row10['ws_matahari']![0].toInt();
    final derajatMatahari = row10['ws_matahari']![1].toDouble();
    final t11 = _lookupTafawut(burjMatahari, derajatMatahari);
    final tandaT11 = t11 < 0 ? -1 : 1;

    final n12 = (112 - bujurLokasi) / 15;
    final t12 = n12.abs().floor();
    final t13 = ((n12.abs() - t12) * 60).round();
    final tandaN12 = n12 < 0 ? -1 : 1;

    final sudutWaktuKasar = _sudutWaktuKasarUntukProyeksi(row10WsMatahari: row10['ws_matahari']!, lintang: lintang);
    final t14 = sudutWaktuKasar.floor();
    final t15 = ((sudutWaktuKasar - t14) * 60).round();

    // Koreksi "Dhamimah" (periode panjang, khusus bujur bulan) --
    // interpolasi antara 2 tahun Hijriah rujukan terdekat.
    final dhamimahDerajat = _koreksiDhamimah(tahunHijriah);

    final row17 = <String, List<num>>{};
    for (final k in _kunciBesaran) {
      final baris11 = _lookupDakaikSaah(t11.abs(), k);
      final baris12 = _lookupGerakPerJam(t12, k);
      final baris13 = _lookupDakaikSaah(t13, k);
      final baris14 = _lookupGerakPerJam(t14, k);
      final baris15 = _lookupDakaikSaah(t15, k);
      final komponen = <List<num>>[
        row10[k]!,
        [0, 0, tandaT11 * baris11[0], tandaT11 * baris11[1]],
        [0, tandaN12 * baris12[0], tandaN12 * baris12[1], tandaN12 * baris12[2]],
        [0, 0, tandaN12 * baris13[0], tandaN12 * baris13[1]],
        [0, baris14[0], baris14[1], baris14[2]],
        [0, 0, baris15[0], baris15[1]],
      ];
      if (k == 'ws_bulan') {
        komponen.add([0, 0, 0, (dhamimahDerajat * 3600).round()]);
      }
      row17[k] = jumlahkanSexagesimal(komponen);
    }
    return row17;
  }

  /// Koreksi "Dhamimah" (khusus bujur bulan) -- interpolasi antara 2 tahun
  /// Hijriah rujukan terdekat di tabel `dhamimah` (14 titik, tiap ~100
  /// tahun Masehi).
  double _koreksiDhamimah(int tahunHijriah) {
    final tabel = _data!['dhamimah'] as Map<String, dynamic>;
    final tahunTersedia = tabel.keys.map(int.parse).toList()..sort();
    final bawah = tahunTersedia.lastWhere((t) => t < tahunHijriah, orElse: () => tahunTersedia.first);
    final atas = tahunTersedia.firstWhere((t) => t > tahunHijriah, orElse: () => tahunTersedia.last);
    if (bawah == atas) return (tabel[bawah.toString()] as List)[0] / 60 + (tabel[bawah.toString()] as List)[1] / 3600;
    final nilaiBawah = tabel[bawah.toString()] as List;
    final nilaiAtas = tabel[atas.toString()] as List;
    final valBawah = (nilaiBawah[0] as num) / 60 + (nilaiBawah[1] as num) / 3600;
    final valAtas = (nilaiAtas[0] as num) / 60 + (nilaiAtas[1] as num) / 3600;
    final i25 = tahunHijriah - bawah;
    final i26 = atas - bawah;
    return valBawah - (valBawah - valAtas) * i25 / i26;
  }

  /// Equation-of-center matahari (baris 18->19 Excel) -- koreksi bujur
  /// matahari dari MEAN ke TRUE/apparent. TERVALIDASI EXACT (deklinasi
  /// akhir 21,4936° cocok persis referensi).
  double bujurMatahariFinal(Map<String, List<num>> row17) {
    final khasMatahari17 = row17['khas_matahari']!;
    final burjAnomali = khasMatahari17[0].toInt();
    final derajatAnomali = keDesimal(khasMatahari17) - burjAnomali * 30;
    final koreksi = interpolasiTabel('equation_matahari', burjAnomali, derajatAnomali);
    // Tanda TERVERIFIKASI: EA46=IF(DR45>5,"+","-"), DR45=Burj anomali.
    final tanda = (burjAnomali > 5) ? 1 : -1;
    final bujurMean17 = keDesimal(row17['ws_matahari']!);
    var hasil = bujurMean17 + tanda * koreksi;
    hasil = hasil % 360;
    if (hasil < 0) hasil += 360;
    return hasil;
  }

  /// Rantai LENGKAP bulan: bujur (5 tahap), anomali (2 tahap), node (1 tahap).
  ///
  /// TANDA TIAP TAHAP TERVERIFIKASI PERSIS dari formula asli (BEDA-beda,
  /// bukan pola seragam):
  ///   Tahap1 (bujur & anomali, tabel sama): Burj>5 -> "-" (TERBALIK)
  ///   Tahap2 anomali: Burj>5 -> "-" (TERBALIK)
  ///   Tahap2 bujur:   Burj>5 -> "+" (standar)
  ///   Tahap3 bujur:   Burj>5 -> "+" (standar)
  ///   Tahap4 bujur:   Burj>5 -> "-" (TERBALIK)
  ///   Tahap5 bujur:   tabel tanda KHUSUS (bukan threshold sederhana)
  ///   Node:           Burj>5 -> "+" (standar)
  ///
  /// PENTING: rantai anomali (AG) JUGA melewati "tahap2 bujur" (row21,
  /// dgn nilai IDENTIK dgn koreksi tahap2 bujur -- AG20=AC20 tervalidasi
  /// sama persis) SEBELUM koreksi HD52 miliknya sendiri (row23) -- BUKAN
  /// loncat langsung row19->row23.
  ({double bujurBulanFinal, double argLintangF, double duaDMinusM, double anomBurj23, double anomDerajat23, double anomPecahan23}) rantaiBulanLengkap({
    required Map<String, List<num>> row17,
    required double bujurMatahariFinal,
  }) {
    final sunAnomYBurj = row17['khas_matahari']![0].toInt();
    final sunAnomZDerajat = row17['khas_matahari']![1].toDouble();
    final sunAnomZFull = keDesimal(row17['khas_matahari']!) - sunAnomYBurj * 30;

    // === TAHAP 1 (bersama utk bujur+anomali+node): kunci=anomali matahari ===
    final koreksi1Bujur = interpolasiTabel('bujur_bulan_tahap1', sunAnomYBurj, sunAnomZFull);
    final koreksi1Node = interpolasiTabel('node_bulan', sunAnomYBurj, sunAnomZFull);
    final tanda1 = sunAnomYBurj > 5 ? -1 : 1;
    final tanda1Node = sunAnomYBurj > 5 ? 1 : -1;

    final bujurRow19 = keDesimal(row17['ws_bulan']!) + tanda1 * koreksi1Bujur;
    final anomRow19 = keDesimal(row17['khas_bulan']!) + tanda1 * koreksi1Bujur;
    final nodeRow19 = keDesimal(row17['simpul_bulan']!) + tanda1Node * koreksi1Node;

    // === TAHAP 2 BUJUR (kunci = 2D - M', pakai elongasi & anomRow19 SEBELUM
    // koreksi HD) -- JUGA dipakai rantai ANOMALI (row19->21) ===
    final elongasi1 = (bujurRow19 - bujurMatahariFinal) % 360;
    final duaDMinusM = (2 * elongasi1 - anomRow19) % 360;
    final burjKunci2 = (duaDMinusM / 30).floor() % 12;
    final derajatKunci2 = duaDMinusM - burjKunci2 * 30;
    final koreksi2 = interpolasiTabel('bujur_bulan_tahap2', burjKunci2, derajatKunci2);
    final tanda2 = burjKunci2 > 5 ? 1 : -1;
    final bujurRow21 = bujurRow19 + tanda2 * koreksi2;
    final anomRow21 = anomRow19 + tanda2 * koreksi2;

    // === TAHAP 2 ANOMALI (row21->23, kunci=anomali matahari, HD52) ===
    final koreksiAnom2 = interpolasiTabel('anomali_bulan_tahap2', sunAnomYBurj, sunAnomZFull);
    final tandaAnom2 = sunAnomYBurj > 5 ? -1 : 1;
    final anomRow23 = anomRow21 + tandaAnom2 * koreksiAnom2;

    // === TAHAP 3 BUJUR (kunci = anomali bulan setelah tahap1+2+HD) ===
    final anomRow23Wrap = anomRow23 % 360;
    final burjAnom23 = (anomRow23Wrap / 30).floor();
    final derajatAnom23 = anomRow23Wrap - burjAnom23 * 30;
    final koreksi3 = interpolasiTabel('bujur_bulan_tahap3', burjAnom23, derajatAnom23);
    final tanda3 = burjAnom23 > 5 ? 1 : -1;
    final bujurRow23 = bujurRow21 + tanda3 * koreksi3;

    // === TAHAP 4 BUJUR (kunci = elongasi diperhalus, pakai bujurRow23) ===
    final elongasi2 = (bujurRow23 - bujurMatahariFinal) % 360;
    final burjElong2 = (elongasi2 / 30).floor() % 12;
    final derajatElong2 = elongasi2 - burjElong2 * 30;
    final koreksi4 = interpolasiTabel('bujur_bulan_tahap4', burjElong2, derajatElong2);
    final tanda4 = burjElong2 > 5 ? -1 : 1;
    final bujurRow25 = bujurRow23 + tanda4 * koreksi4;

    // === TAHAP 5 BUJUR (kunci = argumen lintang F = node+bujurRow25) ===
    const tanda5Tabel = [-1, -1, -1, -1, 1, 1, -1, -1, -1, 1, 1, 1];
    final argLintang = (nodeRow19 + bujurRow25) % 360;
    final burjF = (argLintang / 30).floor() % 12;
    final derajatF = argLintang - burjF * 30;
    final koreksi5 = interpolasiTabel('bujur_bulan_tahap5_sabqI', burjF, derajatF);
    final tanda5 = tanda5Tabel[burjF];
    var bujurRow27 = bujurRow25 + tanda5 * koreksi5;
    bujurRow27 = bujurRow27 % 360;
    if (bujurRow27 < 0) bujurRow27 += 360;

    return (
      bujurBulanFinal: bujurRow27,
      argLintangF: argLintang,
      duaDMinusM: duaDMinusM,
      anomBurj23: burjAnom23.toDouble(),
      anomDerajat23: derajatAnom23,
      anomPecahan23: derajatAnom23 - derajatAnom23.floor(),
    );
  }

  /// Sabq Al-Qamar (سبق القمر) -- laju sudut bulan (derajat/jam), dipakai
  /// rumus interpolasi ijtimak inti. 3 komponen dijumlahkan (dlm arc-detik)
  /// lalu dibagi 3600. TERVALIDASI PRAKTIS EXACT (0,616732 vs 0,616733).
  ///
  /// Komponen I: tabel KHUSUS (sabq_I, Data!ML8:NU38 -- BEDA dari tabel
  /// Tahap5 Bujur meski formatnya mirip), kunci = anomali bulan SETELAH
  /// tahap1+2+HD (anomRow23, Burj+derajat+pecahan). Hasil interpolasinya
  /// SUDAH lgsg dalam skala arc-detik (via kombinasi menit*60+detik+
  /// pertiga/60, BUKAN format derajat biasa).
  ///
  /// Komponen II & III: tabel sabq_II/sabq_III -- hasil `interpolasiTabel`
  /// standarnya (dlm "derajat") DIKALI 60 SEKALI sebelum masuk penjumlahan
  /// arc-detik. Tanda dari formula kompleks Data!OC53/PC54 (bukan threshold
  /// sederhana).
  double lajuBulanSabqAlQamar({
    required double anomBurj23,
    required double anomDerajat23,
    required double anomPecahan23,
    required double duaDMinusM,
    required double bujurBulanFinal,
    required double bujurMatahariFinal,
  }) {
    final tabelI = _data!['sabq_I'] as Map<String, dynamic>;
    final burjI = anomBurj23.toInt();
    final jah1 = anomDerajat23.toInt();
    final jah2 = (jah1 + 1) % 31;
    final barisI1 = (tabelI[jah1.toString()] as List)[burjI] as List;
    final barisI2 = (tabelI[jah2.toString()] as List)[burjI] as List;
    final aI = (barisI1[0] as num) + (barisI1[1] as num) / 60 + (barisI1[2] as num) / 3600;
    final bI = (barisI2[0] as num) + (barisI2[1] as num) / 60 + (barisI2[2] as num) / 3600;
    final komponenIMenit = aI - (aI - bI) * anomPecahan23;
    final komponenIArcdetik = komponenIMenit * 60;

    final burj2DM = (duaDMinusM / 30).floor() % 12;
    final derajat2DM = duaDMinusM - burj2DM * 30;
    final komponenIIDerajat = interpolasiTabel('sabq_II', burj2DM, derajat2DM);
    final tandaII = _tandaSabqII(burj2DM, derajat2DM.floor());
    final komponenIIArcdetik = komponenIIDerajat * 60 * tandaII;

    final elongasiSejati = (bujurBulanFinal - bujurMatahariFinal) % 360;
    final burjElongSejati = (elongasiSejati / 30).floor() % 12;
    final derajatElongSejati = elongasiSejati - burjElongSejati * 30;
    final komponenIIIDerajat = interpolasiTabel('sabq_III', burjElongSejati, derajatElongSejati);
    final tandaIII = _tandaSabqIII(burjElongSejati, derajatElongSejati.floor());
    final komponenIIIArcdetik = komponenIIIDerajat * 60 * tandaIII;

    final totalArcdetik = komponenIArcdetik + komponenIIArcdetik + komponenIIIArcdetik;
    return totalArcdetik / 3600;
  }

  /// Tanda Komponen II Sabq Al-Qamar -- TERVERIFIKASI dari Data!OC53.
  /// Burj=9 mengikuti typo asli file "OC459" (harusnya "OC45=9"), diikuti
  /// pola simetri jelas di sekitarnya (0,1,2,10,11 semua "-").
  int _tandaSabqII(int burj, int derajat) {
    if (burj == 3 && derajat < 3) return -1;
    if (burj == 8 && derajat > 28) return -1;
    if ([0, 1, 2, 9, 10, 11].contains(burj)) return -1;
    return 1;
  }

  /// Tanda Komponen III Sabq Al-Qamar -- TERVERIFIKASI dari Data!PC54.
  int _tandaSabqIII(int burj, int derajat) {
    if (burj == 1 && derajat < 14) return 1;
    if (burj == 10 && derajat > 13) return 1;
    if (burj == 4 && derajat > 14) return 1;
    if (burj == 7 && derajat < 15) return 1;
    if ([0, 5, 11, 6].contains(burj)) return 1;
    return -1;
  }

  /// Ho (ufuk mar'i) standar -- SAMA formula dgn yg dipakai hisab_service.dart
  /// utk 3 metode lain: -(16'+34.5'+1.76*sqrt(elevasi_meter)/60).
  double _hoStandar(double elevasiMeter) {
    final elevasiTerm = elevasiMeter > 0 ? 1.76 * math.sqrt(elevasiMeter) / 60 : 0;
    return -(16 / 60 + 34.5 / 60 + elevasiTerm);
  }

  /// Jam acuan (BI7 Excel, A37) -- estimasi waktu maghrib yg diperhalus.
  /// TERVALIDASI PRAKTIS EXACT (17,499875 vs referensi 17,499880).
  ({double bi7, double cd9, double cd18}) jamAcuanBI7({
    required double row17WsMatahariDecimal,
    required double bujurMatahariFinal,
    required double deklinasiFinal,
    required double lintang,
    required double bujurLokasi,
    required double zonaWaktuJam,
    required double elevasiMeter,
  }) {
    final cd9 = (180 / math.pi) * math.atan(math.cos(23.45 * math.pi / 180) * math.tan(bujurMatahariFinal * math.pi / 180));
    final burjBmf = (bujurMatahariFinal / 30).floor();
    final int k31;
    if (burjBmf >= 3 && burjBmf <= 8) {
      k31 = 180;
    } else if (burjBmf >= 9 && burjBmf <= 11) {
      k31 = 360;
    } else {
      k31 = burjBmf;
    }
    final a33 = (row17WsMatahariDecimal - (cd9 + k31)) / 15;

    final ho = _hoStandar(elevasiMeter);
    final lat = lintang * math.pi / 180;
    final dek = deklinasiFinal * math.pi / 180;
    final dep = ho * math.pi / 180;
    final cosH = -math.tan(lat) * math.tan(dek) + math.sin(dep) / math.cos(lat) / math.cos(dek);
    final cd18 = math.acos(cosH.clamp(-1.0, 1.0)) * 180 / math.pi;

    final bi7 = 12 - a33 + ((zonaWaktuJam * 15) + cd18 - bujurLokasi) / 15;
    return (bi7: bi7, cd9: cd9, cd18: cd18);
  }

  /// Koreksi laju kecil BI12 ("تعديل سبق الشمس", koreksi Sabq MATAHARI) --
  /// tabel `sabq_matahari` (73 titik, derajat 0-360 step 5), kunci = anomali
  /// matahari row17 (Burj+derajat penuh). TERVALIDASI dekat referensi
  /// (0,0397 vs 0,0393°/jam).
  double _koreksiSabqMatahari(double anomaliMatahariFull) {
    final tabel = _data!['sabq_matahari'] as Map<String, dynamic>;
    final bawah = (anomaliMatahariFull / 5).floor() * 5;
    final atas = bawah + 5;
    final baris1 = tabel[bawah.toString()] as List;
    final baris2 = tabel[atas.toString()] as List;
    final a = (baris1[0] as num) + (baris1[1] as num) / 60 + (baris1[2] as num) / 3600;
    final b = (baris2[0] as num) + (baris2[1] as num) / 60 + (baris2[2] as num) / 3600;
    final c = (anomaliMatahariFull - bawah) / 5;
    final menit = a - (a - b) * c;
    return menit * 60 / 3600; // -> derajat/jam
  }

  /// RUMUS INTI IJTIMAK (BI14 Excel): interpolasi linear klasik --
  /// cari kapan selisih bujur bulan-matahari = 0, dari titik acuan BI7.
  /// [laju] WAJIB SUDAH dikurangi BI12 (laju = BI11 - BI12) SEBELUM
  /// dipanggil -- lihat hitungJamIjtimak() utk contoh pemakaian benar.
  /// TERVALIDASI 16:40 vs referensi 16:41 (selisih 1 menit).
  double jamIjtimak({
    required double bi7,
    required double bujurBulanFinal,
    required double bujurMatahariFinal,
    required double laju,
    required double bujurLokasi,
  }) {
    final selisihBujur = ((bujurMatahariFinal - bujurBulanFinal + 180) % 360) - 180;
    final n12 = (112 - bujurLokasi) / 15;
    final bi14 = bi7 + selisihBujur / laju - n12;
    var jam = bi14 % 24;
    if (jam < 0) jam += 24;
    return jam;
  }

  /// Rantai LENGKAP deklinasi bulan + tinggi hilal (hakiki, mar'i) +
  /// elongasi -- melengkapi laporan spt 3 metode lain di aplikasi.
  /// TERVALIDASI dekat kasus uji (selisih beberapa detik busur).
  ({double deklinasiBulan, double tinggiHilalHakiki, double tinggiHilalMari, double elongasi, double cd18, double cd20}) hilalLengkap({
    required double argLintangF,
    required double bujurBulanFinal,
    required double bujurMatahariFinal,
    required double deklinasiMatahariFinal,
    required double lintang,
    required double elevasiMeter,
  }) {
    const maksInklinasi = 5 + 2 / 60;
    final cd7 = math.asin(math.sin(argLintangF * math.pi / 180) * math.sin(maksInklinasi * math.pi / 180)) * 180 / math.pi;

    const obliquity = 23.45;
    final cd9 = math.atan(math.cos(obliquity * math.pi / 180) * math.tan(bujurMatahariFinal * math.pi / 180)) * 180 / math.pi;
    final ho = _hoStandar(elevasiMeter);
    final lat = lintang * math.pi / 180;
    final dek = deklinasiMatahariFinal * math.pi / 180;
    final dep = ho * math.pi / 180;
    final cosH = -math.tan(lat) * math.tan(dek) + math.sin(dep) / math.cos(lat) / math.cos(dek);
    final cd18 = math.acos(cosH.clamp(-1.0, 1.0)) * 180 / math.pi;

    final cd12 = math.atan(
          (math.sin(bujurBulanFinal * math.pi / 180) * math.cos(obliquity * math.pi / 180) -
              math.tan(cd7 * math.pi / 180) * math.sin(obliquity * math.pi / 180)) /
              math.cos(bujurBulanFinal * math.pi / 180),
        ) *
        180 /
        math.pi;

    final deklinasiBulan = math.asin(
          math.sin(cd7 * math.pi / 180) * math.cos(obliquity * math.pi / 180) +
              math.cos(cd7 * math.pi / 180) * math.sin(obliquity * math.pi / 180) * math.sin(bujurBulanFinal * math.pi / 180),
        ) *
        180 /
        math.pi;

    final cd20 = cd9 - cd12 + cd18;
    final tinggiHakiki = math.asin(
          math.sin(lintang * math.pi / 180) * math.sin(deklinasiBulan * math.pi / 180) +
              math.cos(lintang * math.pi / 180) * math.cos(deklinasiBulan * math.pi / 180) * math.cos(cd20 * math.pi / 180),
        ) *
        180 /
        math.pi;

    // Tinggi mar'i: koreksi paralaks (16'/0.2752, konstanta empiris file
    // sumber) + semi-diameter bulan (16').
    final tinggiMari = tinggiHakiki - ((16 / 60) / 0.2752) * math.cos(tinggiHakiki * math.pi / 180) - (16 / 60);

    // Elongasi SEJATI 3D (bukan cuma selisih bujur) -- pakai lintang
    // ekliptika bulan (CD7).
    final selisihBujur = bujurBulanFinal - bujurMatahariFinal;
    final elongasi = math.acos(math.cos(cd7 * math.pi / 180) * math.cos(selisihBujur * math.pi / 180)) * 180 / math.pi;

    return (
      deklinasiBulan: deklinasiBulan,
      tinggiHilalHakiki: tinggiHakiki,
      tinggiHilalMari: tinggiMari,
      elongasi: elongasi,
      cd18: cd18,
      cd20: cd20,
    );
  }

  /// FUNGSI ORKESTRASI UTAMA -- satu pemanggilan merangkai SEMUA fungsi di
  /// atas, menghasilkan `HasilHisabDetail` yg format & fieldnya SAMA PERSIS
  /// dgn 3 metode lain.
  ///
  /// CATATAN PENTING ttg azimut: file Excel sumber memakai konvensi
  /// "diukur dari titik Barat ke Utara" (TERVERIFIKASI dari sheet Output:
  /// "21°32'11,84'' Dari titik Barat ke Utara" utk matahari, cocok PERSIS
  /// dgn hasil rumus di sini). Ini DIKONVERSI ke konvensi standar (Utara
  /// searah jarum jam, 0-360°) via `(270 + nilai) % 360` supaya KONSISTEN
  /// dgn 3 metode lain di aplikasi -- BUKAN krn rumus aslinya salah, murni
  /// beda konvensi tampilan.
  Future<HasilHisabDetail> hitungLengkap({
    required int tahunHijriah,
    required int bulanTarget,
    required int tanggalHisab,
    required double lintang,
    required double bujurLokasi,
    required double zonaWaktuJam,
    required double elevasiMeter,
  }) async {
    await _muatData();
    return hitungLengkapSync(
      tahunHijriah: tahunHijriah, bulanTarget: bulanTarget, tanggalHisab: tanggalHisab,
      lintang: lintang, bujurLokasi: bujurLokasi, zonaWaktuJam: zonaWaktuJam, elevasiMeter: elevasiMeter,
    );
  }

  /// Versi SINKRON dari [hitungLengkap] -- WAJIB panggil [muatDataAwal]
  /// (di-await) dulu sebelum pakai ini, lihat [sudahSiap]. Dipakai
  /// `_metodeList` di hisab_awal_bulan_screen.dart (butuh fungsi sinkron).
  HasilHisabDetail hitungLengkapSync({
    required int tahunHijriah,
    required int bulanTarget,
    required int tanggalHisab,
    required double lintang,
    required double bujurLokasi,
    required double zonaWaktuJam,
    required double elevasiMeter,
  }) {
    assert(_dimuat, 'Panggil muatDataAwal() (await) dulu sebelum hitungLengkapSync().');

    final row17 = rantaiMeanTafawutProyeksi(
      tahunHijriah: tahunHijriah, bulanTarget: bulanTarget, tanggalHisab: tanggalHisab,
      lintang: lintang, bujurLokasi: bujurLokasi,
    );
    final bujurMatahari = bujurMatahariFinal(row17);
    final deklinasiMatahari = _deklinasiDariBujur(bujurMatahari);

    final rantaiBulan = rantaiBulanLengkap(row17: row17, bujurMatahariFinal: bujurMatahari);

    final acuan = jamAcuanBI7(
      row17WsMatahariDecimal: keDesimal(row17['ws_matahari']!),
      bujurMatahariFinal: bujurMatahari, deklinasiFinal: deklinasiMatahari,
      lintang: lintang, bujurLokasi: bujurLokasi, zonaWaktuJam: zonaWaktuJam, elevasiMeter: elevasiMeter,
    );

    final hilal = hilalLengkap(
      argLintangF: rantaiBulan.argLintangF, bujurBulanFinal: rantaiBulan.bujurBulanFinal,
      bujurMatahariFinal: bujurMatahari, deklinasiMatahariFinal: deklinasiMatahari,
      lintang: lintang, elevasiMeter: elevasiMeter,
    );

    double sind(double x) => math.sin(x * math.pi / 180);
    double cosd(double x) => math.cos(x * math.pi / 180);
    double tand(double x) => math.tan(x * math.pi / 180);
    double atand(double x) => math.atan(x) * 180 / math.pi;

    // Azimut mentah (konvensi file asli: dari Barat ke Utara) -> konversi
    // ke konvensi standar (Utara searah jarum jam).
    final azimutMatahariMentah = atand(tand(deklinasiMatahari) * cosd(lintang) / sind(acuan.cd18) - sind(lintang) / tand(acuan.cd18));
    final azimutBulanMentah = atand(tand(hilal.deklinasiBulan) * cosd(lintang) / sind(hilal.cd20) - sind(lintang) / tand(hilal.cd20));

    double mod360(double x) {
      var r = x % 360;
      if (r < 0) r += 360;
      return r;
    }

    final azimutMatahari = mod360(270 + azimutMatahariMentah);
    final azimutBulan = mod360(270 + azimutBulanMentah);
    final jarakAzimut = azimutBulan - azimutMatahari;
    final lamaHilalJam = hilal.tinggiHilalMari / 15;
    final ghurubHilalJam = acuan.bi7 + lamaHilalJam;
    final nurulHilal = math.sqrt(jarakAzimut * jarakAzimut + hilal.tinggiHilalHakiki * hilal.tinggiHilalHakiki) / 15 * 2.5;

    return HasilHisabDetail(
      namaMetode: 'Tashilul Amtsilah',
      tinggiHilalHakiki: hilal.tinggiHilalHakiki,
      tinggiHilalMari: hilal.tinggiHilalMari,
      elongasi: hilal.elongasi,
      azimutMatahari: azimutMatahari,
      azimutBulan: azimutBulan,
      lamaHilalJam: lamaHilalJam,
      nurulHilal: nurulHilal,
      ghurubMatahariJam: acuan.bi7,
      ghurubHilalJam: ghurubHilalJam,
      tinggiMatahariSaatTerbenam: _hoStandar(elevasiMeter),
      deklinasiMatahari: deklinasiMatahari,
      sudutWaktuMatahari: acuan.cd18,
      bujurMatahari: mod360(bujurMatahari),
      bujurBulan: mod360(rantaiBulan.bujurBulanFinal),
      sudutWaktuBulan: hilal.cd20,
      deklinasiBulan: hilal.deklinasiBulan,
      jarakAzimutMatahariBulan: jarakAzimut,
    );
  }

  /// Fungsi ringkas KHUSUS jam ijtimak saja (tanpa laporan hilal lengkap)
  /// -- dipakai layar Tabel Ijtimak (perbandingan 3 metode + Tashilul).
  Future<double> hitungJamIjtimak({
    required int tahunHijriah,
    required int bulanTarget,
    required int tanggalHisab,
    required double lintang,
    required double bujurLokasi,
    required double zonaWaktuJam,
    required double elevasiMeter,
  }) async {
    await _muatData();
    return hitungJamIjtimakSync(
      tahunHijriah: tahunHijriah, bulanTarget: bulanTarget, tanggalHisab: tanggalHisab,
      lintang: lintang, bujurLokasi: bujurLokasi, zonaWaktuJam: zonaWaktuJam, elevasiMeter: elevasiMeter,
    );
  }

  /// Versi SINKRON dari [hitungJamIjtimak] -- WAJIB [muatDataAwal] dulu.
  double hitungJamIjtimakSync({
    required int tahunHijriah,
    required int bulanTarget,
    required int tanggalHisab,
    required double lintang,
    required double bujurLokasi,
    required double zonaWaktuJam,
    required double elevasiMeter,
  }) {
    assert(_dimuat, 'Panggil muatDataAwal() (await) dulu sebelum hitungJamIjtimakSync().');
    final row17 = rantaiMeanTafawutProyeksi(
      tahunHijriah: tahunHijriah, bulanTarget: bulanTarget, tanggalHisab: tanggalHisab,
      lintang: lintang, bujurLokasi: bujurLokasi,
    );
    final bujurMatahari = bujurMatahariFinal(row17);
    final rantaiBulan = rantaiBulanLengkap(row17: row17, bujurMatahariFinal: bujurMatahari);
    final laju = lajuBulanSabqAlQamar(
      anomBurj23: rantaiBulan.anomBurj23, anomDerajat23: rantaiBulan.anomDerajat23,
      anomPecahan23: rantaiBulan.anomPecahan23, duaDMinusM: rantaiBulan.duaDMinusM,
      bujurBulanFinal: rantaiBulan.bujurBulanFinal, bujurMatahariFinal: bujurMatahari,
    );
    final bi12 = _koreksiSabqMatahari(keDesimal(row17['khas_matahari']!));
    final acuan = jamAcuanBI7(
      row17WsMatahariDecimal: keDesimal(row17['ws_matahari']!),
      bujurMatahariFinal: bujurMatahari, deklinasiFinal: _deklinasiDariBujur(bujurMatahari),
      lintang: lintang, bujurLokasi: bujurLokasi, zonaWaktuJam: zonaWaktuJam, elevasiMeter: elevasiMeter,
    );
    return jamIjtimak(
      bi7: acuan.bi7, bujurBulanFinal: rantaiBulan.bujurBulanFinal,
      bujurMatahariFinal: bujurMatahari, laju: laju - bi12, bujurLokasi: bujurLokasi,
    );
  }

  /// Konversi Hijriah->Masehi MANDIRI (kalender tabular, epoch tetap +
  /// pola kabisat 30-tahun STANDAR: tahun 2,5,7,10,13,16,18,21,24,26,29
  /// dari 30 = kabisat/355 hari, sisanya 354 hari). TERVALIDASI dekat
  /// referensi (1-2 hari, wajar utk kalender tabular vs hisab sesungguhnya):
  ///   1 Muharram 1421H -> 6 April 2000 (referensi umum ~5 April 2000)
  ///   30 Muharram 1448H -> 16 Juli 2026 (referensi kasus uji ~14 Juli 2026)
  ///
  /// CATATAN JUJUR: file Excel sumber SENDIRI py tabel kabisat BERBEDA (12
  /// tahun per siklus, bukan 11 -- lihat dokumentasi) yg kalau dipakai
  /// memberi selisih ~48 hari utk tahun 1448H (TIDAK dipakai di sini,
  /// keputusan pengguna memilih pola STANDAR 11 tahun).
  static const _kabisatTahunStandar = {2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29};
  static const _epochJdn = 1948440; // 1 Muharram 1H (tabular, Jumat 16 Juli 622M Julian)
  static const _panjangBulanHijriah = [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29];

  static bool _isKabisat(int tahunH) {
    final cycle = ((tahunH - 1) % 30) + 1;
    return _kabisatTahunStandar.contains(cycle);
  }

  static int _jdnAwalTahun(int tahunH) {
    var total = 0;
    for (var y = 1; y < tahunH; y++) {
      final cycle = ((y - 1) % 30) + 1;
      total += _kabisatTahunStandar.contains(cycle) ? 355 : 354;
    }
    return _epochJdn + total;
  }

  static int _jdnAwalBulan(int tahunH, int bulanH) {
    final jdnTahun = _jdnAwalTahun(tahunH);
    final kabisat = _isKabisat(tahunH);
    var total = 0;
    for (var m = 1; m < bulanH; m++) {
      total += _panjangBulanHijriah[m - 1] + (m == 12 && kabisat ? 1 : 0);
    }
    return jdnTahun + total;
  }

  /// JDN (Julian Day Number, bilangan bulat di tengah hari UTC) utk 1
  /// tanggal Hijriah (tahunH, bulanH, tanggalH) menurut kalender tabular.
  static int jdnDariHijriah({required int tahunH, required int bulanH, required int tanggalH}) {
    return _jdnAwalBulan(tahunH, bulanH) + (tanggalH - 1);
  }

  /// Konversi JDN -> tanggal Masehi (algoritma standar Fliegel & Van
  /// Flandern, tanpa dependensi luar).
  static DateTime jdnKeMasehi(int jdn) {
    var l = jdn + 68569;
    final n = (4 * l) ~/ 146097;
    l = l - (146097 * n + 3) ~/ 4;
    final i = (4000 * (l + 1)) ~/ 1461001;
    l = l - (1461 * i) ~/ 4 + 31;
    final j = (80 * l) ~/ 2447;
    final day = l - (2447 * j) ~/ 80;
    l = j ~/ 11;
    final month = j + 2 - 12 * l;
    final year = 100 * (n - 49) + i + l;
    return DateTime(year, month, day);
  }

  /// Konversi tanggal Masehi (DateTime, bagian jam diabaikan) -> JDN.
  static int masehiKeJdn(DateTime tanggal) {
    final y = tanggal.year, m = tanggal.month, d = tanggal.day;
    final a = (14 - m) ~/ 12;
    final y2 = y + 4800 - a;
    final m2 = m + 12 * a - 3;
    return d + (153 * m2 + 2) ~/ 5 + 365 * y2 + y2 ~/ 4 - y2 ~/ 100 + y2 ~/ 400 - 32045;
  }

  /// Cari (tahunH, bulanH) yg MENGANDUNG [jdnTarget] menurut kalender
  /// tabular (arah sebaliknya dari [jdnDariHijriah]) -- dipakai utk
  /// mengonversi tanggal Masehi (ijtimakUtc) balik ke Hijriah scr mandiri.
  /// Tebakan awal dari rasio rata2 hari/tahun Hijriah (~354,367), lalu
  /// disisir naik/turun sampai ketemu bulan yg tepat.
  static ({int tahunH, int bulanH}) hijriahDariJdn(int jdnTarget) {
    var tahunTebakan = ((jdnTarget - _epochJdn) / 354.367).floor() + 1;
    if (tahunTebakan < 1) tahunTebakan = 1;
    while (_jdnAwalTahun(tahunTebakan) > jdnTarget) {
      tahunTebakan--;
    }
    while (_jdnAwalTahun(tahunTebakan + 1) <= jdnTarget) {
      tahunTebakan++;
    }
    var bulanTebakan = 1;
    while (bulanTebakan < 12 && _jdnAwalBulan(tahunTebakan, bulanTebakan + 1) <= jdnTarget) {
      bulanTebakan++;
    }
    return (tahunH: tahunTebakan, bulanH: bulanTebakan);
  }
}
