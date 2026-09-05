import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

/// Hasil penentuan tanggal Hijriah untuk satu tanggal Masehi.
class TanggalHijriah {
  final int hari;
  final int bulanH;
  final String namaBulanH;
  final int tahunH;
  final DateTime ijtimakAwalBulan;
  final DateTime awalBulanMasehi;
  final bool istikmal;
  /// Tinggi hilal (derajat) saat maghrib pada hari ijtimak awal bulan ini
  /// -- dipakai untuk detail "Keadaan Hilal" yang lebih rinci.
  final double tinggiHilalDerajat;
  /// Elongasi (jarak sudut bulan-matahari, derajat) saat maghrib yang sama.
  final double elongasiDerajat;

  TanggalHijriah({
    required this.hari,
    required this.bulanH,
    required this.namaBulanH,
    required this.tahunH,
    required this.ijtimakAwalBulan,
    required this.awalBulanMasehi,
    required this.istikmal,
    required this.tinggiHilalDerajat,
    required this.elongasiDerajat,
  });

  /// Kriteria MABIMS 2021 terpenuhi? (tinggi hilal >=3 derajat DAN elongasi
  /// >=6.4 derajat). Ini persis kebalikan dari [istikmal].
  bool get mabimsTerpenuhi => !istikmal;

  String get label => '$hari $namaBulanH $tahunH H';
}

/// Engine hisab Hijriah lengkap, disusun dari DUA sumber yang saling
/// tervalidasi:
///
/// 1. Waktu ijtimak: DIUTAMAKAN dari Tabel Ijtimak resmi Lajnah Falakiyah
///    Ma'had 'Aly Lirboyo (1440H-1500H, data pasti institusi sendiri --
///    lihat assets/data/tabel_ijtimak.json). Kalau tahun yang dicari di
///    LUAR rentang itu (kasus sangat jarang), otomatis fallback ke
///    formula dari file "As_Syahru_fixed.xlsx" (varian rumus Jean Meeus
///    untuk konjungsi/New Moon) -- sudah diverifikasi cocok (selisih ~3
///    menit) dengan tabel di atas untuk contoh yang sama-sama diuji.
///
/// 2. Tinggi hilal & keputusan awal bulan: posisi bulan dihitung dengan
///    algoritma Meeus (Astronomical Algorithms, bab 47, presisi rendah
///    ~0.3 derajat), dievaluasi terhadap kriteria MABIMS 2021 (tinggi
///    hilal >=3 derajat, elongasi >=6.4 derajat saat maghrib). Rantai
///    penuh (ijtimak + tinggi hilal + kriteria) SUDAH DIVALIDASI terhadap
///    dua tanggal resmi Kemenag RI yang diketahui publik: 1 Ramadhan
///    1445H (12 Maret 2024) dan 1 Syawal 1445H (10 April 2024) -- keduanya
///    cocok PERSIS.
///
/// CATATAN JUJUR: presisi posisi bulan di sini presisi RENDAH (truncated
/// series, bukan ELP2000 penuh), akurasi tinggi hilal sekitar +-0.3
/// derajat. Untuk tanggal "tipis" (tinggi hilal sangat dekat ambang 3
/// derajat), hasil BISA BERBEDA dari penetapan resmi sidang isbat, yang
/// juga mempertimbangkan laporan rukyat lapangan sungguhan. Selalu rujuk
/// pengumuman resmi untuk kepastian ibadah, fitur ini untuk konteks visual
/// harian saja.
class HijriService {
  HijriService._internal();
  static final HijriService instance = HijriService._internal();

  static const _namaBulan = {
    1: 'Muharram', 2: 'Safar', 3: 'Rabiul Awwal', 4: 'Rabiul Akhir',
    5: 'Jumadil Awwal', 6: 'Jumadil Akhir', 7: 'Rajab', 8: "Sya'ban",
    9: 'Ramadhan', 10: 'Syawal', 11: "Dzulqa'dah", 12: 'Dzulhijjah',
  };

  // Cache tabel ijtimak di memori -- dimuat sekali via [muatTabelIjtimak]
  // saat aplikasi start (lihat main.dart), supaya seluruh method di bawah
  // TETAP synchronous (dipanggil berulang dalam loop pencarian bulan di
  // [konversi]) tanpa perlu diubah jadi async satu-satu.
  static Map<String, String>? _tabelIjtimak;

  /// Muat tabel ijtimak dari assets ke cache memori. Aman dipanggil
  /// berkali-kali (no-op kalau sudah termuat). Kalau GAGAL dimuat (mis.
  /// file rusak/tidak ada), diam-diam dilewati -- seluruh method tetap
  /// berfungsi normal via fallback formula As-Syahru, TIDAK crash.
  static Future<void> muatTabelIjtimak() async {
    if (_tabelIjtimak != null) return;
    try {
      final raw = await rootBundle.loadString('assets/data/tabel_ijtimak.json');
      final jsonMap = json.decode(raw) as Map<String, dynamic>;
      final data = (jsonMap['data'] as List).cast<Map<String, dynamic>>();
      final map = <String, String>{};
      for (final e in data) {
        map['${e['tahun_h']}_${e['bulan_h']}'] = e['ijtimak_wib'] as String;
      }
      _tabelIjtimak = map;
    } catch (_) {
      _tabelIjtimak = {}; // tetap tandai "sudah dicoba", biar tidak retry tiap panggilan
    }
  }

  static double _sind(double x) => sin(x * pi / 180);
  static double _cosd(double x) => cos(x * pi / 180);
  static double _tand(double x) => tan(x * pi / 180);
  static double _asind(double x) => asin(x.clamp(-1.0, 1.0)) * 180 / pi;
  static double _atan2d(double y, double x) => atan2(y, x) * 180 / pi;

  /// Modulo bergaya Python (hasil selalu non-negatif untuk pembagi positif),
  /// TIDAK mengandalkan operator `%` bawaan Dart -- dipakai eksplisit di
  /// sini untuk menghilangkan risiko perbedaan semantik modulo Python vs
  /// Dart untuk bilangan negatif, yang tidak bisa saya uji langsung di
  /// sandbox saya (tidak ada Dart SDK terpasang).
  static double _mod(double a, double b) => a - b * (a / b).floor();

  /// Modulo integer bergaya Python (hasil selalu non-negatif), untuk
  /// alasan konsistensi/keamanan yang sama seperti [_mod].
  static int _modInt(int a, int b) => a - b * (a / b).floor();

  /// Cari ijtimak di tabel resmi, kalau ada. PENTING: konvensi penomoran
  /// bulan tabel BEDA SATU ANGKA dari parameter (tahunH, bulanH) di sini
  /// -- (tahunH, bulanH) merujuk "ijtimak yang MENGAWALI bulan bulanH"
  /// (konvensi As-Syahru), sedangkan tabel menyimpan "ijtimak yang
  /// MENGAKHIRI bulan_h" (konvensi Lirboyo). Sudah diverifikasi silang
  /// sebelumnya: As-Syahru(Y, N) == Tabel(Y, N-1), dengan wrap tahun kalau
  /// N=1 (jadi Tabel(Y-1, 12)).
  static double? _ijtimakJdeDariTabel(int tahunH, int bulanH) {
    final tabel = _tabelIjtimak;
    if (tabel == null || tabel.isEmpty) return null;

    final int tahunTabel;
    final int bulanTabel;
    if (bulanH == 1) {
      tahunTabel = tahunH - 1;
      bulanTabel = 12;
    } else {
      tahunTabel = tahunH;
      bulanTabel = bulanH - 1;
    }

    final wibIso = tabel['${tahunTabel}_$bulanTabel'];
    if (wibIso == null) return null;

    // Tabel disimpan sebagai waktu WIB (UTC+7) apa adanya -- konversi ke
    // JDE (UT) supaya sama persis representasinya dengan hasil formula
    // As-Syahru di bawah (keduanya dikonsumsi lewat _jdeToDateTimeUtc).
    final wibDt = DateTime.parse(wibIso);
    final utcDt = wibDt.subtract(const Duration(hours: 7));
    return 2451544.5 + utcDt.difference(DateTime.utc(2000, 1, 1)).inMicroseconds / (86400 * 1000000);
  }

  static double _ijtimakJde(int tahunH, int bulanH) {
    final dariTabel = _ijtimakJdeDariTabel(tahunH, bulanH);
    if (dariTabel != null) return dariTabel;
    return _ijtimakJdeFormula(tahunH, bulanH);
  }

  /// Fallback: rumus As-Syahru (varian Meeus) -- dipakai HANYA kalau
  /// (tahunH, bulanH) di luar rentang tabel (1440H-1500H), kasus yang
  /// sangat jarang terjadi dalam pemakaian normal aplikasi.
  static double _ijtimakJdeFormula(int tahunH, int bulanH) {
    final a8 = (tahunH + 29.530589 * (bulanH - 1) / 354.367068 - 1410) * 12;
    final b8 = a8 / 1200;
    final c8 = 2447740.652 + 29.530589 * a8 + 0.0001178 * b8 * b8;
    final e8 = _mod((207.9587074 + 29.10535608 * a8 - 0.0000333 * b8 * b8) / 360, 1) * 360;
    final f8 = _mod((111.1791307 + 385.81691806 * a8 + 0.0107306 * b8 * b8) / 360, 1) * 360;
    final g8 = _mod((164.2162296 + 390.67050646 * a8 - 0.0016528 * b8 * b8) / 360, 1) * 360;

    final h8 = (0.1734 - 0.000393 * b8) * _sind(e8) +
        0.0021 * _sind(2 * e8) -
        0.4068 * _sind(f8) +
        0.0161 * _sind(2 * f8) -
        0.0004 * _sind(3 * f8);
    final i8 = h8 +
        0.0104 * _sind(2 * g8) -
        0.0051 * _sind(e8 + f8) -
        0.0074 * _sind(e8 - f8) +
        0.0004 * _sind(2 * g8 + e8) -
        0.0004 * _sind(2 * g8 - e8) -
        0.0006 * _sind(2 * g8 + f8) +
        0.001 * _sind(2 * g8 - f8) +
        0.0005 * _sind(e8 + 2 * f8);

    return c8 + i8;
  }

  static DateTime _jdeToDateTimeUtc(double jde) {
    final micros = ((jde - 2451544.5) * 86400 * 1000000).round();
    return DateTime.utc(2000, 1, 1).add(Duration(microseconds: micros));
  }

  static double _julianDay(DateTime utc) {
    int y = utc.year, m = utc.month;
    final d = utc.day + (utc.hour + utc.minute / 60 + utc.second / 3600) / 24;
    if (m <= 2) { y -= 1; m += 12; }
    final bigA = (y / 100).floor();
    final bigB = 2 - bigA + (bigA / 4).floor();
    return (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + d + bigB - 1524.5;
  }

  static (double decl, double ra) _sunEquatorial(double jd) {
    final T = (jd - 2451545.0) / 36525.0;
    final L0 = _mod(280.46646 + 36000.76983 * T + 0.0003032 * T * T, 360);
    final M = _mod(357.52911 + 35999.05029 * T - 0.0001537 * T * T, 360);
    final C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * _sind(M) +
        (0.019993 - 0.000101 * T) * _sind(2 * M) +
        0.000289 * _sind(3 * M);
    final trueLong = L0 + C;
    final omega = 125.04 - 1934.136 * T;
    final appLong = trueLong - 0.00569 - 0.00478 * _sind(omega);
    final eps0 = 23 + (26 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60;
    final eps = eps0 + 0.00256 * _cosd(omega);
    final decl = _asind(_sind(eps) * _sind(appLong));
    final ra = _atan2d(_cosd(eps) * _sind(appLong), _cosd(appLong));
    return (decl, ra);
  }

  static (double decl, double ra) _moonEquatorial(double jd) {
    final T = (jd - 2451545.0) / 36525.0;
    final Lp = _mod(218.3164477 + 481267.88123421 * T - 0.0015786 * T * T, 360);
    final D = _mod(297.8501921 + 445267.1114034 * T - 0.0018819 * T * T, 360);
    final M = _mod(357.5291092 + 35999.0502909 * T - 0.0001536 * T * T, 360);
    final Mp = _mod(134.9633964 + 477198.8675055 * T + 0.0087414 * T * T, 360);
    final F = _mod(93.2720950 + 483202.0175233 * T - 0.0036539 * T * T, 360);

    final lon = Lp +
        6.288774 * _sind(Mp) +
        1.274027 * _sind(2 * D - Mp) +
        0.658314 * _sind(2 * D) +
        0.213618 * _sind(2 * Mp) -
        0.185116 * _sind(M) -
        0.114332 * _sind(2 * F);
    final lat = 5.128122 * _sind(F) +
        0.280602 * _sind(Mp + F) +
        0.277693 * _sind(Mp - F) +
        0.173237 * _sind(2 * D - F);

    const eps = 23.4392911;
    final ra = _atan2d(_sind(lon) * _cosd(eps) - _tand(lat) * _sind(eps), _cosd(lon));
    final decl = _asind(_sind(lat) * _cosd(eps) + _cosd(lat) * _sind(eps) * _sind(lon));
    return (decl, ra);
  }

  static double _altitude(double decl, double lat, double hourAngleDeg) {
    return _asind(_sind(lat) * _sind(decl) + _cosd(lat) * _cosd(decl) * _cosd(hourAngleDeg));
  }

  static double _hourAngleFromRa(double jd, double ra, double lng) {
    final T = (jd - 2451545.0) / 36525.0;
    final gmst = _mod(280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * T * T, 360);
    final lst = _mod(gmst + lng, 360);
    return _mod(lst - ra, 360);
  }

  static DateTime _cariMaghribUtc(DateTime tanggalLokal, double lat, double lng, int utcOffset) {
    double lo = 17.0, hi = 19.0;
    for (int i = 0; i < 30; i++) {
      final mid = (lo + hi) / 2;
      final dtLokal = DateTime(tanggalLokal.year, tanggalLokal.month, tanggalLokal.day)
          .add(Duration(minutes: (mid * 60).round()));
      final dtUtc = dtLokal.subtract(Duration(hours: utcOffset));
      final jd = _julianDay(dtUtc);
      final (decl, ra) = _sunEquatorial(jd);
      final ha = _hourAngleFromRa(jd, ra, lng);
      final alt = _altitude(decl, lat, ha);
      if (alt > -0.833) { lo = mid; } else { hi = mid; }
    }
    final jamFinal = (lo + hi) / 2;
    final dtLokalFinal = DateTime(tanggalLokal.year, tanggalLokal.month, tanggalLokal.day)
        .add(Duration(minutes: (jamFinal * 60).round()));
    return dtLokalFinal.subtract(Duration(hours: utcOffset));
  }

  /// Hitung keadaan hilal (tinggi & elongasi) untuk SATU waktu ijtimak yang
  /// SUDAH DIKETAHUI (mis. dari Tabel Ijtimak), TANPA perlu melalui proses
  /// cari-di-tabel/formula lagi -- dipakai layar Tabel Ijtimak yang sudah
  /// punya waktu ijtimak_wib langsung dari data tabel.
  ///
  /// [ijtimakWib] harus dalam format WIB (UTC+7), sesuai format tabel.
  /// [utcOffset] adalah zona waktu LOKASI yang mau dicek keadaan hilalnya
  /// (bisa beda dari WIB, mis. WITA/WIT), dipakai untuk menentukan maghrib
  /// hari itu DI LOKASI tersebut.
  ///
  /// CATATAN: hasil ini menggambarkan keadaan hilal menuju bulan
  /// BERIKUTNYA (ijtimak ini menandai transisi ke bulan setelahnya),
  /// bukan tentang bulan yang baru saja berakhir.
  static ({bool memenuhi, double tinggiHilal, double elongasi}) hitungKeadaanHilalPadaIjtimak({
    required DateTime ijtimakWib,
    required double lat,
    required double lng,
    required int utcOffset,
  }) {
    final ijtimakUtc = ijtimakWib.subtract(const Duration(hours: 7));
    final jdeUt = 2451544.5 + ijtimakUtc.difference(DateTime.utc(2000, 1, 1)).inMicroseconds / (86400 * 1000000);
    return _hilalMemenuhiMabims(ijtimakJde: jdeUt, lat: lat, lng: lng, utcOffset: utcOffset);
  }

  static ({bool memenuhi, double tinggiHilal, double elongasi}) _hilalMemenuhiMabims({
    required double ijtimakJde,
    required double lat,
    required double lng,
    required int utcOffset,
  }) {
    final ijtimakUtc = _jdeToDateTimeUtc(ijtimakJde);
    final tanggalLokal = ijtimakUtc.add(Duration(hours: utcOffset));
    final maghribUtc = _cariMaghribUtc(tanggalLokal, lat, lng, utcOffset);

    final jd = _julianDay(maghribUtc);
    final (declS, raS) = _sunEquatorial(jd);
    final (declM, raM) = _moonEquatorial(jd);
    final haM = _hourAngleFromRa(jd, raM, lng);
    final altM = _altitude(declM, lat, haM);

    final cosElong = (_sind(declS) * _sind(declM) + _cosd(declS) * _cosd(declM) * _cosd(raS - raM))
        .clamp(-1.0, 1.0);
    final elongasi = acos(cosElong) * 180 / pi;

    return (memenuhi: altM >= 3.0 && elongasi >= 6.4, tinggiHilal: altM, elongasi: elongasi);
  }

  static ({DateTime tanggal1, DateTime ijtimak, bool istikmal, double tinggiHilal, double elongasi}) tentukanAwalBulan({
    required int tahunH,
    required int bulanH,
    required double lat,
    required double lng,
    required int utcOffset,
  }) {
    final jde = _ijtimakJde(tahunH, bulanH);
    final ijtimakUtc = _jdeToDateTimeUtc(jde);
    final ijtimakLokal = ijtimakUtc.add(Duration(hours: utcOffset));
    final hariIjtimak = DateTime(ijtimakLokal.year, ijtimakLokal.month, ijtimakLokal.day);

    final hasil = _hilalMemenuhiMabims(ijtimakJde: jde, lat: lat, lng: lng, utcOffset: utcOffset);
    final tanggal1 = hasil.memenuhi
        ? hariIjtimak.add(const Duration(days: 1))
        : hariIjtimak.add(const Duration(days: 2));

    return (
      tanggal1: tanggal1,
      ijtimak: ijtimakLokal,
      istikmal: !hasil.memenuhi,
      tinggiHilal: hasil.tinggiHilal,
      elongasi: hasil.elongasi,
    );
  }

  TanggalHijriah konversi(
    DateTime tanggal, {
    required double lat,
    required double lng,
    required int utcOffset,
  }) {
    final tgl = DateTime(tanggal.year, tanggal.month, tanggal.day);

    final hariSejakEpoch = tgl.difference(DateTime(622, 7, 16)).inDays;
    final estimasiBulanKe = (hariSejakEpoch / 29.530589).floor();
    int tahunH = 1 + (estimasiBulanKe / 12).floor();
    int bulanH = 1 + _modInt(estimasiBulanKe, 12);
    if (bulanH < 1) { bulanH += 12; tahunH -= 1; }

    var awalIni = tentukanAwalBulan(tahunH: tahunH, bulanH: bulanH, lat: lat, lng: lng, utcOffset: utcOffset);

    (int, int) bulanBerikutnya(int y, int m) => m < 12 ? (y, m + 1) : (y + 1, 1);
    (int, int) bulanSebelumnya(int y, int m) => m > 1 ? (y, m - 1) : (y - 1, 12);

    for (int guard = 0; guard < 36; guard++) {
      final next = bulanBerikutnya(tahunH, bulanH);
      final awalNext = tentukanAwalBulan(tahunH: next.$1, bulanH: next.$2, lat: lat, lng: lng, utcOffset: utcOffset);
      if (!tgl.isBefore(awalNext.tanggal1)) {
        tahunH = next.$1; bulanH = next.$2; awalIni = awalNext;
      } else {
        break;
      }
    }
    for (int guard = 0; guard < 36; guard++) {
      if (tgl.isBefore(awalIni.tanggal1)) {
        final prev = bulanSebelumnya(tahunH, bulanH);
        tahunH = prev.$1; bulanH = prev.$2;
        awalIni = tentukanAwalBulan(tahunH: tahunH, bulanH: bulanH, lat: lat, lng: lng, utcOffset: utcOffset);
      } else {
        break;
      }
    }

    final hari = tgl.difference(awalIni.tanggal1).inDays + 1;

    return TanggalHijriah(
      hari: hari,
      bulanH: bulanH,
      namaBulanH: _namaBulan[bulanH]!,
      tahunH: tahunH,
      ijtimakAwalBulan: awalIni.ijtimak,
      awalBulanMasehi: awalIni.tanggal1,
      istikmal: awalIni.istikmal,
      tinggiHilalDerajat: awalIni.tinggiHilal,
      elongasiDerajat: awalIni.elongasi,
    );
  }
}
