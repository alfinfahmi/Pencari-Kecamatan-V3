import 'hisab_detail.dart';
import 'hisab_tashilul_amtsilah_service.dart';

/// Adapter yang menjembatani `HisabTashilulAmtsilahService` (yg antarmukanya
/// berbasis tanggal Hijriah + tanggal-hisab, sesuai desain aslinya di kitab)
/// ke bentuk fungsi yang dipakai `_metodeList` di hisab_awal_bulan_screen.dart
/// & tabel_ijtimak_screen.dart (berbasis `ijtimakUtc`, konsisten dgn
/// As-Syahru/Meeus).
///
/// CATATAN PENTING (2 bug ditemukan & diperbaiki setelah laporan pengguna
/// ttg tinggi hilal ~24-32° yg tidak masuk akal):
/// 1. `tanggalHisab` BUKAN konstanta 30 -- bervariasi per bulan (kitab
///    klasik mengandalkan penghitung manusia memperkirakan tanggal awal
///    yg dekat ijtimak sesungguhnya). Diperbaiki via
///    `cariTanggalHisabOptimal()` (cari otomatis, bukan asumsi tetap).
/// 2. Konversi kalender tabular MANDIRI (jdnDariHijriah/hijriahDariJdn)
///    py drift beberapa hari dari hisab sesungguhnya -- BISA menyeberang
///    batas bulan scr keliru (bulan salah total, bukan cuma tanggal).
///    Diperbaiki via verifikasi: cek 3 bulan kandidat (tabular-1, tabular,
///    tabular+1), pilih yg jam-ijtimak-hasil-Tashilul-nya PALING DEKAT ke
///    [ijtimakUtc] yg diberikan (bukan percaya konversi tabular begitu saja).
class TashilulAmtsilahAdapter {
  TashilulAmtsilahAdapter._();

  static Future<void> muatData() => HisabTashilulAmtsilahService.instance.muatDataAwal();

  static bool get sudahSiap => HisabTashilulAmtsilahService.instance.sudahSiap;

  /// Cocok dgn tipe `HasilHisabDetail Function({required DateTime ijtimakUtc,
  /// required double lat, required double lng, required double elevasiM,
  /// required int utcOffset})` yg dipakai `_metodeList`.
  static HasilHisabDetail hitung({
    required DateTime ijtimakUtc,
    required double lat,
    required double lng,
    required double elevasiM,
    required int utcOffset,
  }) {
    final (tahunH, bulanH) = _cariBulanTerbaik(
      ijtimakUtc: ijtimakUtc, lat: lat, lng: lng, elevasiM: elevasiM, utcOffset: utcOffset,
    );
    final layanan = HisabTashilulAmtsilahService.instance;
    final tanggalHisab = layanan.cariTanggalHisabOptimal(tahunHijriah: tahunH, bulanTarget: bulanH);
    return layanan.hitungLengkapSync(
      tahunHijriah: tahunH, bulanTarget: bulanH, tanggalHisab: tanggalHisab,
      lintang: lat, bujurLokasi: lng, zonaWaktuJam: utcOffset.toDouble(), elevasiMeter: elevasiM,
    );
  }

  /// Cari (tahunH,bulanH) yg PALING SESUAI dgn [ijtimakUtc] -- tebakan awal
  /// dari konversi tabular, lalu diverifikasi (& dikoreksi kalau perlu)
  /// dgn membandingkan jam-ijtimak-hasil-Tashilul thd 3 kandidat bulan
  /// (tabular-1, tabular, tabular+1), pilih yg SELISIHNYA PALING KECIL.
  static (int, int) _cariBulanTerbaik({
    required DateTime ijtimakUtc,
    required double lat,
    required double lng,
    required double elevasiM,
    required int utcOffset,
  }) {
    final tanggalSetelahIjtimak = ijtimakUtc.add(Duration(hours: utcOffset + 6));
    final jdn = HisabTashilulAmtsilahService.masehiKeJdn(tanggalSetelahIjtimak);
    final tebakan = HisabTashilulAmtsilahService.hijriahDariJdn(jdn);

    (int, int) geserBulan(int tahunH, int bulanH, int geser) {
      var b = bulanH + geser;
      var t = tahunH;
      if (b < 1) { b += 12; t -= 1; }
      if (b > 12) { b -= 12; t += 1; }
      return (t, b);
    }

    (int, int)? terbaik;
    Duration? selisihTerbaik;
    for (final geser in [-1, 0, 1]) {
      final (t, b) = geserBulan(tebakan.tahunH, tebakan.bulanH, geser);
      if (t < HisabTashilulAmtsilahService.tahunHijriahMinimum ||
          t > HisabTashilulAmtsilahService.tahunHijriahMaksimum) {
        continue;
      }
      try {
        final ijtimakKandidat = cariIjtimakUtc(
          tahunH: t, bulanH: b, lat: lat, lng: lng, elevasiM: elevasiM, utcOffset: utcOffset,
        );
        final selisih = ijtimakKandidat.difference(ijtimakUtc).abs();
        if (selisihTerbaik == null || selisih < selisihTerbaik) {
          terbaik = (t, b);
          selisihTerbaik = selisih;
        }
      } catch (_) {
        // Kandidat ini gagal (mis. di luar rentang tabel) -- lewati.
      }
    }
    return terbaik ?? (tebakan.tahunH, tebakan.bulanH);
  }

  /// Jam ijtimak (desimal, zona lokal [utcOffset]) MURNI hasil Tashilul
  /// Amtsilah sendiri -- dipakai layar Tabel Ijtimak (kolom perbandingan)
  /// & pencarian bulan terbaik di atas. TERPISAH dari [hitung].
  static double hitungJamIjtimakSaja({
    required int tahunH,
    required int bulanH,
    required double lat,
    required double lng,
    required double elevasiM,
    required int utcOffset,
  }) {
    final layanan = HisabTashilulAmtsilahService.instance;
    final tanggalHisab = layanan.cariTanggalHisabOptimal(tahunHijriah: tahunH, bulanTarget: bulanH);
    return layanan.hitungJamIjtimakSync(
      tahunHijriah: tahunH, bulanTarget: bulanH, tanggalHisab: tanggalHisab,
      lintang: lat, bujurLokasi: lng, zonaWaktuJam: utcOffset.toDouble(), elevasiMeter: elevasiM,
    );
  }

  /// Ijtimak sbg DateTime UTC penuh, SEPENUHNYA MANDIRI hasil Tashilul
  /// Amtsilah sendiri -- tanggal dari konversi kalender tabular sendiri
  /// (`jdnDariHijriah`), jam dari [hitungJamIjtimakSaja]. Dipakai layar
  /// Tabel Ijtimak & pencarian bulan terbaik di atas.
  static DateTime cariIjtimakUtc({
    required int tahunH,
    required int bulanH,
    required double lat,
    required double lng,
    required double elevasiM,
    required int utcOffset,
  }) {
    final jdnAwalBulanIni = HisabTashilulAmtsilahService.jdnDariHijriah(
      tahunH: tahunH, bulanH: bulanH, tanggalH: 1,
    );
    final tanggalMasehi = HisabTashilulAmtsilahService.jdnKeMasehi(jdnAwalBulanIni);

    final jamLokal = hitungJamIjtimakSaja(
      tahunH: tahunH, bulanH: bulanH, lat: lat, lng: lng, elevasiM: elevasiM, utcOffset: utcOffset,
    );
    final jamBulat = jamLokal.floor();
    final menit = ((jamLokal - jamBulat) * 60).round();
    final tanggalIjtimak = tanggalMasehi.subtract(const Duration(days: 1));
    final ijtimakLokal = DateTime(tanggalIjtimak.year, tanggalIjtimak.month, tanggalIjtimak.day, jamBulat, menit);
    return ijtimakLokal.subtract(Duration(hours: utcOffset));
  }
}
