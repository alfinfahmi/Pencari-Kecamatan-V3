import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import 'hisab_detail.dart';
import 'meeus_hisab_service.dart';

/// Status ketersediaan data Ephemeris utk satu bulan Hijriyah.
enum StatusDataEphemeris { siap, memuat, tidakTersedia }

/// Dilempar kalau data jam-jaman yg dibutuhkan tidak ada di aset.
class DataEphemerisTidakTersedia implements Exception {
  final String pesan;
  DataEphemerisTidakTersedia(this.pesan);
  @override
  String toString() => pesan;
}

/// Metode hisab awal bulan "Ephemeris" -- PROSEDUR Ephemeris Hisab Rukyat
/// (Kemenag RI) dijalankan apa adanya di atas tabel data per jam.
///
/// SUMBER DATA (jujur soal ini): tabel di `assets/data/ephemeris/<tahun>.csv`
/// BUKAN salinan buku Ephemeris Kemenag, melainkan disusun dgn KOLOM & SATUAN
/// yg sama dari data JPL DE421 (NASA/JPL) lewat
/// `tools/ephemeris/generate_ephemeris.py`. Hanya 2 hari UT per ijtimak
/// (hari ijtimak & esoknya), tahun 2020-2050. Kalau suatu saat ada tabel
/// buku Ephemeris asli, cukup ganti/isi file tahun tsb dgn kolom yg sama.
///
/// VALIDASI (implementasi rujukan Python `tools/ephemeris/
/// hisab_ephemeris_ref.py`, rumus identik dgn file ini) thd data resmi
/// Kemenag Ramadan 1447 H (17 Feb 2026): ijtimak 19:01:09 WIB (Kemenag
/// 19.01), ghurub Jakarta Pusat 18:15:20 (Kemenag 18:15:17), elongasi Banda
/// Aceh 0°56'23" (Kemenag 0°56'23"), Jayapura 1°53'38" (Kemenag 1°53'36").
/// Tinggi hilal TIDAK bisa divalidasi dari berita krn konvensi tinggi yg
/// dipakai Kemenag tidak disebutkan.
///
/// LANGKAH (Ephemeris, cf. Muhyiddin Khazin "Ilmu Falak dalam Teori dan
/// Praktik"):
///  1. Ijtimak: jam X = FIB terkecil; ijtimak = X + (ELM-ALB)/(SB-SM).
///  2. Ghurub: h0 = -(SD matahari + 34'30" + 1,76'√elevasi);
///     cos t0 = -tanφ tanδ + sin h0 / cosφ / cosδ;
///     ghurub = 12 - e + t0/15 + (λzona - λ)/15, diiterasi (δ, e, SD
///     diinterpolasi pd jam ghurub hasil iterasi sebelumnya).
///  3. Saat ghurub (interpolasi A - (A-B)·C/I): tb = ARo - ARb + t0;
///     sin h = sinφ sinδb + cosφ cosδb cos tb  (tinggi HAKIKI);
///     h' = h - HP·cos h; mar'i = h' + SD bulan + refraksi + dip.
///     Refraksi = rumus Bennett yg SAMA dgn `koreksiHakikiKeMarI` (bedanya
///     HP & SD bulan di sini memakai nilai tabel, bukan konstanta rata2).
///  4. Elongasi geosentrik, azimut (konvensi "dari Barat, + Utara"),
///     lama hilal = mar'i/15, nurul hilal -- sama dgn 4 metode lain.
class HisabEphemerisService {
  HisabEphemerisService._();

  static const int tahunAwal = 2020;
  static const int tahunAkhir = 2050;
  static const String _folder = 'assets/data/ephemeris';

  // Urutan kolom file CSV (setelah tanggal & jam).
  static const _kolom = ['elm', 'elb', 'ars', 'dks', 'r', 'sds', 'eps', 'eot',
      'alb', 'alt', 'arm', 'dkm', 'hp', 'sdm', 'abl', 'fib'];
  static final _idx = {for (var i = 0; i < _kolom.length; i++) _kolom[i]: i};
  // Kolom bersatuan derajat 0..360 -- interpolasinya perlu "buka lipatan".
  static const _kolomLingkaran = {'elm', 'ars', 'alb', 'arm', 'abl'};

  /// 'yyyy-mm-dd|jam' (UT) -> 16 nilai.
  static final Map<String, List<double>> _baris = {};
  static final Set<int> _tahunTermuat = {};
  static final Set<int> _tahunTidakAda = {};
  static final Map<int, Future<void>> _sedangMuat = {};

  // ---------------------------------------------------------------- data

  /// Dipakai unit test / sumber lain: muat isi CSV satu tahun langsung.
  static void muatDariTeks(int tahun, String isiCsv) {
    for (final baris in isiCsv.split('\n')) {
      final b = baris.trim();
      if (b.isEmpty || b.startsWith('#') || b.startsWith('tanggal')) continue;
      final p = b.split(',');
      _baris['${p[0]}|${int.parse(p[1])}'] = [for (final v in p.skip(2)) double.parse(v)];
    }
    _tahunTermuat.add(tahun);
  }

  static Future<void> _muatTahun(int tahun) {
    if (_tahunTermuat.contains(tahun) || _tahunTidakAda.contains(tahun)) return Future.value();
    if (tahun < tahunAwal || tahun > tahunAkhir) {
      _tahunTidakAda.add(tahun);
      return Future.value();
    }
    return _sedangMuat.putIfAbsent(tahun, () async {
      try {
        muatDariTeks(tahun, await rootBundle.loadString('$_folder/$tahun.csv'));
      } catch (_) {
        _tahunTidakAda.add(tahun);
      } finally {
        _sedangMuat.remove(tahun);
      }
    });
  }

  /// Tahun-tahun file yg mungkin memuat ijtimak bulan ini (file dikelompokkan
  /// per tahun Masehi tanggal ijtimak; ±1 tahun utk ijtimak awal/akhir tahun).
  static List<int> _tahunUntuk(int tahunH, int bulanH) {
    final p = MeeusHisabService.cariIjtimakUtc(tahunH: tahunH, bulanH: bulanH);
    return {p.subtract(const Duration(days: 2)).year, p.year, p.add(const Duration(days: 2)).year}.toList();
  }

  static Future<void> muatUntukBulan({required int tahunH, required int bulanH}) =>
      Future.wait(_tahunUntuk(tahunH, bulanH).map(_muatTahun));

  static StatusDataEphemeris statusData({required int tahunH, required int bulanH}) {
    final daftar = _tahunUntuk(tahunH, bulanH);
    if (daftar.any((t) => !_tahunTermuat.contains(t) && !_tahunTidakAda.contains(t))) {
      return StatusDataEphemeris.memuat;
    }
    try {
      cariIjtimakUtc(tahunH: tahunH, bulanH: bulanH);
      return StatusDataEphemeris.siap;
    } on DataEphemerisTidakTersedia {
      return StatusDataEphemeris.tidakTersedia;
    }
  }

  static String _kunci(DateTime utc) =>
      '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')}|${utc.hour}';

  static List<double> _jam(DateTime utcJamBulat) {
    final b = _baris[_kunci(utcJamBulat)];
    if (b == null) {
      throw DataEphemerisTidakTersedia(
          'Data Ephemeris utk ${_kunci(utcJamBulat).replaceAll('|', ' jam ')} UT tidak tersedia '
          '(tersedia ijtimak $tahunAwal-$tahunAkhir).');
    }
    return b;
  }

  /// Interpolasi Ephemeris: A - (A - B) × C / I (linier antar dua jam).
  static double _interp(DateTime utc, String kolom) {
    final a = DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
    final c = utc.difference(a).inMicroseconds / 3.6e9;
    final i = _idx[kolom]!;
    final nilaiA = _jam(a)[i];
    var nilaiB = _jam(a.add(const Duration(hours: 1)))[i];
    final lingkaran = _kolomLingkaran.contains(kolom);
    if (lingkaran && (nilaiB - nilaiA).abs() > 180) nilaiB += nilaiB < nilaiA ? 360 : -360;
    final v = nilaiA - (nilaiA - nilaiB) * c;
    return lingkaran ? _mod360(v) : v;
  }

  // ------------------------------------------------------------- matematika
  static double _sind(double x) => sin(x * pi / 180);
  static double _cosd(double x) => cos(x * pi / 180);
  static double _tand(double x) => tan(x * pi / 180);
  static double _asind(double x) => asin(x.clamp(-1.0, 1.0)) * 180 / pi;
  static double _acosd(double x) => acos(x.clamp(-1.0, 1.0)) * 180 / pi;
  static double _atan2d(double y, double x) => atan2(y, x) * 180 / pi;
  static double _mod360(double x) => x % 360.0;
  static double _bungkus180(double x) => _mod360(x + 180) - 180;

  static const double _refraksiUfuk = 34.5 / 60; // 34'30"

  // ---------------------------------------------------------------- ijtimak

  /// Langkah 1: jam FIB terkecil (X) di sekitar perkiraan ijtimak, lalu
  /// ijtimak = X + (ELM - ALB) / (SB - SM). Hasil dlm UTC.
  static DateTime cariIjtimakUtc({required int tahunH, required int bulanH}) {
    final p = MeeusHisabService.cariIjtimakUtc(tahunH: tahunH, bulanH: bulanH);
    final mulai = DateTime.utc(p.year, p.month, p.day, p.hour).subtract(const Duration(hours: 30));
    DateTime? x;
    var fibMin = double.infinity;
    for (var j = 0; j <= 60; j++) {
      final t = mulai.add(Duration(hours: j));
      final b = _baris[_kunci(t)];
      if (b != null && b[_idx['fib']!] < fibMin) {
        fibMin = b[_idx['fib']!];
        x = t;
      }
    }
    if (x == null) {
      throw DataEphemerisTidakTersedia(
          'Data Ephemeris utk ijtimak $bulanH/$tahunH H tidak tersedia (tersedia $tahunAwal-$tahunAkhir M).');
    }
    final r0 = _jam(x);
    final r1 = _jam(x.add(const Duration(hours: 1)));
    final elm = r0[_idx['elm']!];
    final alb = r0[_idx['alb']!];
    final sb = _mod360(r1[_idx['alb']!] - alb); // kecepatan bulan /jam
    final sm = _mod360(r1[_idx['elm']!] - elm); // kecepatan matahari /jam
    final jam = _bungkus180(elm - alb) / (sb - sm);
    return x.add(Duration(microseconds: (jam * 3.6e9).round()));
  }

  // ------------------------------------------------------------------ hitung

  static HasilHisabDetail hitung({
    required DateTime ijtimakUtc,
    required double lat,
    required double lng,
    required double elevasiM,
    required int utcOffset,
  }) {
    // Hari ijtimak LOKAL (jam dinding) -- ghurub hari itu yg dihisab.
    final lokal = ijtimakUtc.add(Duration(hours: utcOffset));
    final hari = DateTime.utc(lokal.year, lokal.month, lokal.day);
    DateTime keUtc(double jamLokal) =>
        hari.add(Duration(microseconds: ((jamLokal - utcOffset) * 3.6e9).round()));

    final dip = 1.76 / 60 * sqrt(max(elevasiM, 0)); // kerendahan ufuk

    // Langkah 2: ghurub matahari, diiterasi.
    var ghurub = 18.0;
    var t0 = 90.0;
    var h0 = -0.833;
    for (var i = 0; i < 6; i++) {
      final g = keUtc(ghurub);
      final dks = _interp(g, 'dks');
      final e = _interp(g, 'eot');
      final sds = _interp(g, 'sds');
      h0 = -(sds + _refraksiUfuk + dip);
      t0 = _acosd(-_tand(lat) * _tand(dks) + _sind(h0) / _cosd(lat) / _cosd(dks));
      final baru = 12 - e + t0 / 15 + (utcOffset * 15 - lng) / 15;
      final selesai = (baru - ghurub).abs() < 1e-7;
      ghurub = baru;
      if (selesai) break;
    }

    // Langkah 3: data saat ghurub.
    final g = keUtc(ghurub);
    final ars = _interp(g, 'ars');
    final dks = _interp(g, 'dks');
    final arm = _interp(g, 'arm');
    final dkm = _interp(g, 'dkm');
    final hp = _interp(g, 'hp');
    final sdm = _interp(g, 'sdm');
    final elm = _interp(g, 'elm');
    final alb = _interp(g, 'alb');

    final tb = _bungkus180(ars - arm + t0); // sudut waktu bulan
    final hakiki = _asind(_sind(lat) * _sind(dkm) + _cosd(lat) * _cosd(dkm) * _cosd(tb));
    final toposentrik = hakiki - hp * _cosd(hakiki); // dikurangi parallax
    final atas = toposentrik + sdm; // piringan atas
    final refraksi = 0.0167 / _tand(atas + 7.31 / (atas + 4.4)); // Bennett
    final mari = atas + refraksi + dip;

    double keKonvensiBU(double t, double dek) {
      final azDariSelatan = _atan2d(_sind(t), _cosd(t) * _sind(lat) - _tand(dek) * _cosd(lat));
      final r = _mod360(azDariSelatan - 90);
      return r > 180 ? r - 360 : r;
    }

    final azimutMatahari = keKonvensiBU(t0, dks);
    final azimutBulan = keKonvensiBU(tb, dkm);
    final elongasi = _acosd(_sind(dks) * _sind(dkm) + _cosd(dks) * _cosd(dkm) * _cosd(ars - arm));
    final lamaHilalJam = mari / 15;
    final jarakAzimut = azimutBulan - azimutMatahari;

    return HasilHisabDetail(
      namaMetode: 'Ephemeris',
      tinggiHilalHakiki: hakiki,
      tinggiHilalMari: mari,
      elongasi: elongasi,
      azimutMatahari: azimutMatahari,
      azimutBulan: azimutBulan,
      lamaHilalJam: lamaHilalJam,
      nurulHilal: sqrt(jarakAzimut * jarakAzimut + hakiki * hakiki) / 15 * 2.5,
      ghurubMatahariJam: ghurub,
      ghurubHilalJam: ghurub + lamaHilalJam,
      tinggiMatahariSaatTerbenam: h0,
      deklinasiMatahari: dks,
      sudutWaktuMatahari: t0,
      bujurMatahari: elm,
      bujurBulan: alb,
      sudutWaktuBulan: tb,
      deklinasiBulan: dkm,
      jarakAzimutMatahariBulan: jarakAzimut,
    );
  }
}
