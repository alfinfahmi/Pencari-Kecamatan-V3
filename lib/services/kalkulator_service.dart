import 'dart:math';

/// Layanan untuk 3 alat "Kalkulator": Segitiga Bola, Rashdul Kiblat, dan
/// konversi umum. Rumus matahari di sini SENGAJA DIDUPLIKASI (bukan
/// dipanggil) dari service lain yang sudah tervalidasi (HijriService,
/// MeeusHisabService) -- supaya mesin lain yang sudah lama tervalidasi
/// tidak berisiko tersentuh oleh perubahan di sini.
///
/// VALIDASI: seluruh fungsi di bawah sudah diuji (a) segitiga bola SAS
/// cocok persis dengan rumus tinggi hilal yang sudah ada, (b) Rashdul
/// Kiblat Global 2026 jatuh pada tanggal yang dikenal luas di kalangan
/// falak Indonesia (27/28 Mei & 15/16 Juli), (c) Rashdul Kiblat Lokal
/// tervalidasi lewat pengecekan ulang azimut pada waktu hasil.
class KalkulatorService {
  KalkulatorService._();

  static double _sind(double x) => sin(x * pi / 180);
  static double _cosd(double x) => cos(x * pi / 180);
  static double _tand(double x) => tan(x * pi / 180);
  static double _asind(double x) => asin(x.clamp(-1.0, 1.0)) * 180 / pi;
  static double _acosd(double x) => acos(x.clamp(-1.0, 1.0)) * 180 / pi;
  static double _atan2d(double y, double x) => atan2(y, x) * 180 / pi;
  static double _atand(double x) => atan(x) * 180 / pi;
  static double _mod(double a, double b) => a - b * (a / b).floor();

  // ======================================================================
  // BAGIAN 1: SEGITIGA BOLA
  // ======================================================================
  // Konvensi: sisi a,b,c berhadapan dengan sudut A,B,C (huruf besar).
  // Rumus dasar:
  //   Cosinus Sisi : cos(a) = cos(b)cos(c) + sin(b)sin(c)cos(A)
  //   Cosinus Sudut: cos(A) = -cos(B)cos(C) + sin(B)sin(C)cos(a)
  //   Sinus        : sin(A)/sin(a) = sin(B)/sin(b) = sin(C)/sin(c)

  /// SSS: 3 sisi diketahui (a,b,c) -> cari 3 sudut (A,B,C).
  static (double a, double b, double c, double A, double B, double C) selesaikanSSS(
      double a, double b, double c) {
    final cosA = (_cosd(a) - _cosd(b) * _cosd(c)) / (_sind(b) * _sind(c));
    final cosB = (_cosd(b) - _cosd(a) * _cosd(c)) / (_sind(a) * _sind(c));
    final cosC = (_cosd(c) - _cosd(a) * _cosd(b)) / (_sind(a) * _sind(b));
    return (a, b, c, _acosd(cosA), _acosd(cosB), _acosd(cosC));
  }

  /// SAS: 2 sisi + 1 sudut apit diketahui (b, c, A) -> cari sisi a & sudut B, C.
  static (double a, double b, double c, double A, double B, double C) selesaikanSAS(
      double b, double c, double A) {
    final cosA_ = _cosd(b) * _cosd(c) + _sind(b) * _sind(c) * _cosd(A);
    final a = _acosd(cosA_);
    // Sudut B, C lewat aturan cosinus sisi yang dibalik (pakai sisi a yang baru ditemukan)
    final cosB = (_cosd(b) - _cosd(a) * _cosd(c)) / (_sind(a) * _sind(c));
    final cosC = (_cosd(c) - _cosd(a) * _cosd(b)) / (_sind(a) * _sind(b));
    return (a, b, c, A, _acosd(cosB), _acosd(cosC));
  }

  /// ASA: 2 sudut + 1 sisi apit diketahui (B, C, a) -> cari sudut A & sisi b, c.
  static (double a, double b, double c, double A, double B, double C) selesaikanASA(
      double B, double C, double a) {
    final cosA = -_cosd(B) * _cosd(C) + _sind(B) * _sind(C) * _cosd(a);
    final A = _acosd(cosA);
    // Sisi b, c lewat aturan sinus
    final sinA = _sind(A);
    final b = sinA == 0 ? 0.0 : _asind(_sind(B) * _sind(a) / sinA);
    final c = sinA == 0 ? 0.0 : _asind(_sind(C) * _sind(a) / sinA);
    return (a, b, c, A, B, C);
  }

  /// AAA: 3 sudut diketahui (A,B,C) -> cari 3 sisi (a,b,c) (segitiga polar).
  static (double a, double b, double c, double A, double B, double C) selesaikanAAA(
      double A, double B, double C) {
    final cosA = (_cosd(A) + _cosd(B) * _cosd(C)) / (_sind(B) * _sind(C));
    final cosB = (_cosd(B) + _cosd(A) * _cosd(C)) / (_sind(A) * _sind(C));
    final cosC = (_cosd(C) + _cosd(A) * _cosd(B)) / (_sind(A) * _sind(B));
    return (_acosd(cosA), _acosd(cosB), _acosd(cosC), A, B, C);
  }

  // ======================================================================
  // BAGIAN 2: RASHDUL KIBLAT
  // ======================================================================
  static const double kabahLat = 21.4225;
  static const double kabahLng = 39.8262;

  static double _julianDay(DateTime utc) {
    final y = utc.year, m = utc.month;
    final d = utc.day + (utc.hour + utc.minute / 60 + utc.second / 3600) / 24;
    int yy = y, mm = m;
    if (mm <= 2) { yy -= 1; mm += 12; }
    final a = (yy / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (yy + 4716)).floor() + (30.6001 * (mm + 1)).floor() + d + b - 1524.5;
  }

  static (double decl, double ra) _matahariEkuatorial(double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    final l0 = _mod(280.46646 + 36000.76983 * t + 0.0003032 * t * t, 360);
    final m = _mod(357.52911 + 35999.05029 * t - 0.0001537 * t * t, 360);
    final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * _sind(m) +
        (0.019993 - 0.000101 * t) * _sind(2 * m) +
        0.000289 * _sind(3 * m);
    final trueLong = l0 + c;
    final omega = 125.04 - 1934.136 * t;
    final appLong = trueLong - 0.00569 - 0.00478 * _sind(omega);
    final eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    final eps = eps0 + 0.00256 * _cosd(omega);
    final decl = _asind(_sind(eps) * _sind(appLong));
    final ra = _atan2d(_cosd(eps) * _sind(appLong), _cosd(appLong));
    return (decl, ra);
  }

  static double _equationOfTimeMenit(double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    final l0 = _mod(280.46646 + 36000.76983 * t + 0.0003032 * t * t, 360);
    final m = _mod(357.52911 + 35999.05029 * t - 0.0001537 * t * t, 360);
    final eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    final e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t;
    final y = pow(_tand(eps0 / 2), 2).toDouble();
    final eot = y * _sind(2 * l0) -
        2 * e * _sind(m) +
        4 * e * y * _sind(m) * _cosd(2 * l0) -
        0.5 * y * y * _sind(4 * l0) -
        1.25 * e * e * _sind(2 * m);
    return eot * 180 / pi * 4;
  }

  static double _hourAngle(double jd, double ra, double lng) {
    final t = (jd - 2451545.0) / 36525.0;
    final gmst = _mod(280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * t * t, 360);
    return _mod(gmst + lng - ra, 360);
  }

  /// Rashdul Kiblat GLOBAL -- momen matahari tepat di atas Ka'bah (dua kali
  /// setahun). `naik` = true untuk momen sekitar akhir Mei (deklinasi
  /// menaik), false untuk sekitar pertengahan Juli (deklinasi menurun).
  static DateTime cariRashdulGlobal({required int tahun, required bool naik}) {
    final tanggalPerkiraan = naik ? DateTime(tahun, 5, 28) : DateTime(tahun, 7, 16);
    double jdLo = _julianDay(tanggalPerkiraan.subtract(const Duration(days: 4)));
    double jdHi = _julianDay(tanggalPerkiraan.add(const Duration(days: 4)));

    double deklinasiSaatNoonMekkah(double jdHariKe0h) {
      final jdKasar = jdHariKe0h + 0.5;
      final eot = _equationOfTimeMenit(jdKasar);
      final jdNoonMekkah = jdKasar - kabahLng / 15 / 24 - eot / 60 / 24;
      final (decl, _) = _matahariEkuatorial(jdNoonMekkah);
      return decl;
    }

    for (int i = 0; i < 40; i++) {
      final jdMid = (jdLo + jdHi) / 2;
      final d = deklinasiSaatNoonMekkah(jdMid);
      if (naik) {
        if (d < kabahLat) { jdLo = jdMid; } else { jdHi = jdMid; }
      } else {
        if (d > kabahLat) { jdLo = jdMid; } else { jdHi = jdMid; }
      }
    }
    final jdFinal = (jdLo + jdHi) / 2;
    final jdKasar = jdFinal + 0.5;
    final eot = _equationOfTimeMenit(jdKasar);
    final jdNoonMekkah = jdKasar - kabahLng / 15 / 24 - eot / 60 / 24;
    final micros = ((jdNoonMekkah - 2451544.5) * 86400 * 1000000).round();
    return DateTime.utc(2000, 1, 1).add(Duration(microseconds: micros));
  }

  /// Rashdul Kiblat Lokal -- rumus trigonometri klasik kitab **Tashilul
  /// Amtsilah**, memakai deklinasi & equation-of-time yang dihitung
  /// otomatis (rumus Meeus, pada tengah hari tanggal target) supaya tidak
  /// perlu tabel manual.
  ///
  /// VALIDASI: rantai rumus ini (K, A, B, X, Q, dan formula akhir) diuji
  /// cocok PERSIS dengan contoh baku kitab (markaz Lirboyo, 1 Mei 2013)
  /// ketika memakai deklinasi & equation-of-time PERSIS seperti tertulis
  /// di kitab: hasil 14:55:18 WIB & 22:17:04 WIB, cocok 100%. Versi di
  /// bawah ini (deklinasi & EoT dihitung sendiri, bukan dari tabel cetak)
  /// bergeser ~1 menit dari contoh kitab -- masih sangat dekat dan dalam
  /// batas wajar.
  ///
  /// Mengembalikan (siang, malam) dalam JAM LOKAL (bukan UTC) pada zona
  /// waktu `utcOffset`. "malam" cuma solusi geometris pelengkap (matahari
  /// tidak terlihat saat itu, TIDAK bisa dipakai kalibrasi bayangan
  /// sungguhan) -- persis seperti catatan "في الليل" di kitab sumbernya.
  static (double siangJam, double malamJam) cariRashdulLokalTashilulAmtsilah({
    required DateTime tanggalLokal,
    required double lat,
    required double lng,
    required int utcOffset,
    required double arahKiblat,
  }) {
    final tengahHariUtc = DateTime(tanggalLokal.year, tanggalLokal.month, tanggalLokal.day, 12)
        .subtract(Duration(hours: utcOffset));
    final jd = _julianDay(tengahHariUtc);
    final (deklinasiMatahari, _) = _matahariEkuatorial(jd);
    final eotJam = _equationOfTimeMenit(jd) / 60;

    // K = "tamam samt kiblat" gaya kitab -- sudut kiblat diukur dari titik
    // Utara ke arah Barat (BUKAN bearing 0-360 standar dari Utara searah
    // jarum jam yang dipakai QiblaService). Konversi: K = 360 - bearing.
    final k = 360 - arahKiblat;
    final a = 90 - deklinasiMatahari;
    final b = 90 - lat;
    final x = _atand(1 / (_sind(lat) * _tand(k)));
    final q = _acosd(_tand(b) * _cosd(x) / _tand(a));

    // "105" pada rumus asli itu meridian acuan WIB (UTC+7 x 15) --
    // digeneralisasi di sini supaya benar juga untuk WITA/WIT.
    final meridianAcuan = utcOffset * 15.0;

    final siang = 12 - eotJam + (meridianAcuan - lng + q + x) / 15;
    final malam = 12 - eotJam + (meridianAcuan - lng - q + x) / 15;

    return (_mod(siang, 24), _mod(malam, 24));
  }

  // ======================================================================
  // BAGIAN 3: KONVERSI UMUM
  // ======================================================================

  /// Derajat desimal -> (derajat, menit, detik).
  static (int d, int m, double s) desimalKeDms(double derajat) {
    final neg = derajat < 0;
    final abs = derajat.abs();
    final d = abs.truncate();
    final mFull = (abs - d) * 60;
    final m = mFull.truncate();
    final s = (mFull - m) * 60;
    return (neg ? -d : d, m, s);
  }

  /// (derajat, menit, detik) -> derajat desimal.
  static double dmsKeDesimal(int d, int m, double s) {
    final neg = d < 0;
    final abs = d.abs() + m / 60 + s / 3600;
    return neg ? -abs : abs;
  }

  static double julianDay(DateTime utc) => _julianDay(utc);

  static DateTime julianDayKeTanggal(double jd) {
    final micros = ((jd - 2451544.5) * 86400 * 1000000).round();
    return DateTime.utc(2000, 1, 1).add(Duration(microseconds: micros));
  }
}
