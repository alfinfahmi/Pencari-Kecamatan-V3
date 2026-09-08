import 'dart:math';

/// Layanan pendukung Kamera Rukyat: hitung kemiringan (pitch) perangkat
/// dari data accelerometer, dan proyeksikan posisi hilal (azimut+tinggi)
/// ke koordinat layar untuk ditampilkan sebagai overlay AR di atas live
/// view kamera.
///
/// **PERINGATAN JUJUR (baca sebelum pakai/uji fitur ini):** rumus pitch
/// di bawah ini adalah pemahaman terbaik penulis soal konvensi sumbu
/// accelerometer Android/iOS standar (Z keluar dari layar, Y ke atas
/// layar) -- TAPI belum pernah diuji di perangkat fisik sungguhan
/// (sandbox pengembangan tidak punya sensor). Konvensi sumbu bisa sedikit
/// berbeda antar perangkat/versi OS. Karena itu UI Kamera Rukyat WAJIB
/// menyediakan kontrol kalibrasi manual (offset pitch) supaya pengguna
/// bisa mengoreksi sendiri kalau arah overlay-nya terbalik/meleset --
/// JANGAN hapus kontrol itu meski rumus di bawah "kelihatannya" sudah
/// benar secara teori.
class KameraRukyatService {
  KameraRukyatService._();

  static double _sind(double x) => sin(x * pi / 180);
  static double _cosd(double x) => cos(x * pi / 180);
  static double _tand(double x) => tan(x * pi / 180);
  static double _asind(double x) => asin(x.clamp(-1.0, 1.0)) * 180 / pi;
  static double _atan2d(double y, double x) => atan2(y, x) * 180 / pi;
  static double _mod(double a, double b) => a - b * (a / b).floor();

  static double _julianDay(DateTime utc) {
    final y = utc.year, m = utc.month;
    final d = utc.day + (utc.hour + utc.minute / 60 + utc.second / 3600) / 24;
    int yy = y, mm = m;
    if (mm <= 2) { yy -= 1; mm += 12; }
    final a = (yy / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (yy + 4716)).floor() + (30.6001 * (mm + 1)).floor() + d + b - 1524.5;
  }

  /// Posisi Bulan SAAT INI (real-time), azimut & tinggi dari lokasi
  /// tertentu -- BUKAN posisi saat maghrib/ijtimak seperti mesin hisab
  /// utama. Dipakai khusus untuk overlay live Kamera Rukyat.
  ///
  /// Presisi rendah (~10 suku, sama seperti "Jean Meeus" biasa) SENGAJA
  /// dipilih di sini -- untuk overlay visual live, presisi sub-menit
  /// busur jauh kalah penting dibanding ketidakpastian sensor orientasi
  /// perangkat & refraksi atmosfer dekat ufuk, yang jauh lebih besar.
  static (double azimut, double tinggi) posisiBulanSaatIni({
    required DateTime utc,
    required double lat,
    required double lng,
  }) {
    final jd = _julianDay(utc);
    final t = (jd - 2451545.0) / 36525.0;

    final lp = _mod(218.3164477 + 481267.88123421 * t - 0.0015786 * t * t, 360);
    final d = _mod(297.8501921 + 445267.1114034 * t - 0.0018819 * t * t, 360);
    final m = _mod(357.5291092 + 35999.0502909 * t - 0.0001536 * t * t, 360);
    final mp = _mod(134.9633964 + 477198.8675055 * t + 0.0087414 * t * t, 360);
    final f = _mod(93.2720950 + 483202.0175233 * t - 0.0036539 * t * t, 360);

    final bujurBulan = lp + 6.288774 * _sind(mp) - 1.274027 * _sind(2 * d - mp) + 0.658314 * _sind(2 * d) +
        0.213618 * _sind(2 * mp) - 0.185116 * _sind(m) - 0.114332 * _sind(2 * f);
    final lintangBulan = 5.128122 * _sind(f) + 0.280602 * _sind(mp + f) + 0.277693 * _sind(mp - f) +
        0.173237 * _sind(2 * d - f);

    const eps = 23.4392911;
    final ra = _atan2d(_sind(bujurBulan) * _cosd(eps) - _tand(lintangBulan) * _sind(eps), _cosd(bujurBulan));
    final decl = _asind(_sind(lintangBulan) * _cosd(eps) + _cosd(lintangBulan) * _sind(eps) * _sind(bujurBulan));

    final gmst = _mod(280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * t * t, 360);
    final ha = _mod(gmst + lng - ra, 360);

    final tinggi = _asind(_sind(lat) * _sind(decl) + _cosd(lat) * _cosd(decl) * _cosd(ha));
    final azimut = _mod(_atan2d(_sind(ha), _cosd(ha) * _sind(lat) - _tand(decl) * _cosd(lat)) + 180, 360);
    return (azimut, tinggi);
  }

  /// Posisi Matahari SAAT INI (real-time) -- dipakai untuk garis ufuk &
  /// info pendukung (waktu tersisa sebelum ghurub, dll.) di layar Kamera
  /// Rukyat.
  static (double azimut, double tinggi) posisiMatahariSaatIni({
    required DateTime utc,
    required double lat,
    required double lng,
  }) {
    final jd = _julianDay(utc);
    final t = (jd - 2451545.0) / 36525.0;
    final l0 = _mod(280.46646 + 36000.76983 * t + 0.0003032 * t * t, 360);
    final mm = _mod(357.52911 + 35999.05029 * t - 0.0001537 * t * t, 360);
    final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * _sind(mm) +
        (0.019993 - 0.000101 * t) * _sind(2 * mm) +
        0.000289 * _sind(3 * mm);
    final trueLong = l0 + c;
    final omega = 125.04 - 1934.136 * t;
    final appLong = trueLong - 0.00569 - 0.00478 * _sind(omega);
    final eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    final eps = eps0 + 0.00256 * _cosd(omega);
    final decl = _asind(_sind(eps) * _sind(appLong));
    final ra = _atan2d(_cosd(eps) * _sind(appLong), _cosd(appLong));

    final gmst = _mod(280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * t * t, 360);
    final ha = _mod(gmst + lng - ra, 360);
    final tinggi = _asind(_sind(lat) * _sind(decl) + _cosd(lat) * _cosd(decl) * _cosd(ha));
    final azimut = _mod(_atan2d(_sind(ha), _cosd(ha) * _sind(lat) - _tand(decl) * _cosd(lat)) + 180, 360);
    return (azimut, tinggi);
  }

  /// Pitch (kemiringan) perangkat dari horizontal, dalam derajat.
  /// 0 derajat = perangkat tegak lurus, kamera (belakang) mengarah ke
  /// ufuk/horizon. Makin besar = kamera makin mengarah ke atas (langit).
  ///
  /// Konvensi sumbu accelerometer standar (posisi "natural portrait"):
  ///   X = ke kanan layar, Y = ke atas layar, Z = keluar dari layar
  ///   (ke arah pengguna, BERLAWANAN dengan arah kamera belakang).
  /// Saat perangkat tegak & mengarah ke ufuk: gravitasi terbaca di +Y.
  /// Saat ditegakkan mengarah ke atas (zenith): gravitasi pindah ke +Z.
  static double pitchDariAccelerometer(double accX, double accY, double accZ) {
    return atan2(accZ, accY) * 180 / pi;
  }

  /// Proyeksikan selisih sudut (target - arah_kamera) ke posisi piksel
  /// layar, pakai proyeksi perspektif (tan-based, bukan linear) supaya
  /// akurat di seluruh lebar FOV kamera, bukan cuma di titik tengah.
  ///
  /// Mengembalikan null kalau target di LUAR jangkauan FOV kamera (tidak
  /// akan pernah muncul di layar berapa pun besar widget-nya).
  static (double x, double y)? proyeksiKeLayar({
    required double azimutTarget,
    required double tinggiTarget,
    required double headingKamera,
    required double pitchKamera,
    required double lebarLayar,
    required double tinggiLayar,
    double fovHorizontalDerajat = 60,
    double fovVertikalDerajat = 45,
  }) {
    double selisihAzimut = azimutTarget - headingKamera;
    while (selisihAzimut > 180) { selisihAzimut -= 360; }
    while (selisihAzimut < -180) { selisihAzimut += 360; }
    final selisihTinggi = tinggiTarget - pitchKamera;

    final batasH = fovHorizontalDerajat / 2;
    final batasV = fovVertikalDerajat / 2;
    if (selisihAzimut.abs() >= batasH || selisihTinggi.abs() >= batasV) return null;

    final fracX = tan(selisihAzimut * pi / 180) / tan(batasH * pi / 180);
    final fracY = tan(selisihTinggi * pi / 180) / tan(batasV * pi / 180);

    final x = lebarLayar / 2 + fracX * (lebarLayar / 2);
    final y = tinggiLayar / 2 - fracY * (tinggiLayar / 2);
    return (x, y);
  }
}
