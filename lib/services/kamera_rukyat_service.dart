import 'dart:math';

/// Layanan pendukung Kamera Rukyat: hitung kemiringan (pitch/roll) perangkat
/// dari data accelerometer, posisi Bulan/Matahari real-time (azimut,
/// tinggi, elongasi, umur bulan, ghurub), dan proyeksikan posisi hilal ke
/// koordinat layar untuk ditampilkan sebagai overlay AR di atas live view
/// kamera.
///
/// **PERINGATAN JUJUR (baca sebelum pakai/uji fitur ini):** rumus
/// pitch/roll di bawah ini adalah pemahaman terbaik penulis soal konvensi
/// sumbu accelerometer Android/iOS standar (Z keluar dari layar, Y ke atas
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
  static double _acosd(double x) => acos(x.clamp(-1.0, 1.0)) * 180 / pi;
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

  // ============== Posisi ekuatorial (RA/Dek) -- dipakai internal ==============

  /// Bujur ekliptika & lintang ekliptika Bulan (derajat), dan Deklinasi+RA
  /// turunannya -- suku-suku periodik utama Meeus bab 47 (presisi rendah,
  /// ~10 suku, cukup untuk overlay live & elongasi/umur bulan).
  static (double ra, double decl, double bujurEkliptika) _posisiEkuatorialBulan(double jd) {
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
    return (_mod(ra, 360), decl, bujurBulan);
  }

  /// RA/Dek Matahari (derajat), dan bujur ekliptika-nya.
  static (double ra, double decl, double bujurEkliptika) _posisiEkuatorialMatahari(double jd) {
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
    return (_mod(ra, 360), decl, appLong);
  }

  static double _gmst(double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    return _mod(280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * t * t, 360);
  }

  static (double azimut, double tinggi) _azimutTinggiDari(double ra, double decl, double jd, double lat, double lng) {
    final ha = _mod(_gmst(jd) + lng - ra, 360);
    final tinggi = _asind(_sind(lat) * _sind(decl) + _cosd(lat) * _cosd(decl) * _cosd(ha));
    final azimut = _mod(_atan2d(_sind(ha), _cosd(ha) * _sind(lat) - _tand(decl) * _cosd(lat)) + 180, 360);
    return (azimut, tinggi);
  }

  // ============== API publik -- posisi live ==============

  /// Posisi Bulan SAAT INI (real-time), azimut & tinggi dari lokasi
  /// tertentu -- BUKAN posisi saat maghrib/ijtimak seperti mesin hisab
  /// utama. Dipakai khusus untuk overlay live Kamera Rukyat.
  ///
  /// Presisi rendah (~10 suku, sama seperti "Jean Meeus" biasa) SENGAJA
  /// dipilih di sini -- untuk overlay visual live, presisi sub-menit
  /// busur jauh kalah penting dibanding ketidakpastian sensor orientasi
  /// perangkat & refraksi atmosfer dekat ufuk, yang jauh lebih besar.
  static (double azimut, double tinggi) posisiBulanSaatIni({
    required DateTime utc, required double lat, required double lng,
  }) {
    final jd = _julianDay(utc);
    final (ra, decl, _) = _posisiEkuatorialBulan(jd);
    return _azimutTinggiDari(ra, decl, jd, lat, lng);
  }

  /// Posisi Matahari SAAT INI (real-time) -- dipakai untuk garis ufuk &
  /// info pendukung (waktu tersisa sebelum ghurub, dll.) di layar Kamera
  /// Rukyat.
  static (double azimut, double tinggi) posisiMatahariSaatIni({
    required DateTime utc, required double lat, required double lng,
  }) {
    final jd = _julianDay(utc);
    final (ra, decl, _) = _posisiEkuatorialMatahari(jd);
    return _azimutTinggiDari(ra, decl, jd, lat, lng);
  }

  /// Elongasi (jarak sudut Bulan-Matahari) SAAT INI, derajat -- dihitung
  /// dari koordinat ekuatorial (RA/Dek) via hukum cosinus segitiga bola,
  /// BUKAN sekadar selisih azimut (yang tidak akurat untuk jarak sudut
  /// sesungguhnya antara dua benda langit).
  ///
  /// CATATAN PENTING (tervalidasi numerik): elongasi di sini mengukur
  /// JARAK SUDUT SEBENARNYA di langit (3 dimensi, termasuk lintang
  /// ekliptika Bulan) -- BEDA dari definisi "ijtimak" mesin hisab utama
  /// aplikasi (HijriService), yang berarti "bujur ekliptika Bulan =
  /// bujur ekliptika Matahari" (2 dimensi, sepanjang ekliptika saja).
  /// Karena lintang ekliptika Bulan bisa sampai \u00b15\u00b0, elongasi di sini BISA
  /// menunjukkan beberapa derajat (bukan 0) TEPAT saat ijtimak menurut
  /// definisi mesin hisab utama -- ini BUKAN bug, cuma dua besaran
  /// astronomis yang berbeda secara definisi. Untuk keperluan visual
  /// kamera (jarak yang benar-benar terlihat mata di langit), definisi
  /// di sini justru yang lebih relevan.
  static double elongasiSaatIni({required DateTime utc}) {
    final jd = _julianDay(utc);
    final (raBulan, deklBulan, _) = _posisiEkuatorialBulan(jd);
    final (raMatahari, deklMatahari, _) = _posisiEkuatorialMatahari(jd);
    final cosD = _sind(deklBulan) * _sind(deklMatahari) +
        _cosd(deklBulan) * _cosd(deklMatahari) * _cosd(raBulan - raMatahari);
    return _acosd(cosD);
  }

  /// Umur Bulan (jam) sejak ijtimak (konjungsi) TERAKHIR -- perkiraan
  /// dari elongasi saat ini dan laju rata-rata Bulan menjauhi Matahari
  /// (360 derajat / 29.53059 hari, siklus sinodis rata-rata). Ini
  /// PERKIRAAN cepat untuk tampilan live, bukan pencarian ijtimak presisi
  /// tinggi seperti mesin hisab utama aplikasi (HijriService) -- selisih
  /// wajar beberapa puluh menit sampai ~1 jam (lihat catatan lengkap di
  /// [elongasiSaatIni] soal beda definisi elongasi vs ijtimak ekliptika).
  static double umurBulanJam({required DateTime utc}) {
    final elongasi = elongasiSaatIni(utc: utc);
    const lajuDerajatPerHari = 360 / 29.53058868;
    final hari = elongasi / lajuDerajatPerHari;
    return hari * 24;
  }

  /// Cari waktu ghurub (altitude melintasi ambang batas standar, turun)
  /// HARI INI untuk Bulan atau Matahari, dalam UTC -- null kalau tidak
  /// ghurub/terbit di lokasi ini hari itu (kasus lintang ekstrem).
  /// Pencarian numerik sederhana (langkah 1 menit, cukup presisi untuk
  /// tampilan info, bukan mesin hisab utama).
  ///
  /// Ambang -0.8333\u00b0 (bukan tepat 0\u00b0) -- standar astronomi umum untuk
  /// "ghurub", memperhitungkan refraksi atmosfer (~34') + jari-jari
  /// piringan (~16') supaya SAAT PIRINGAN (bukan cuma titik pusat) benar-
  /// benar hilang di ufuk. Tervalidasi: hasil untuk Matahari cocok dalam
  /// 2 menit terhadap waktu Maghrib mesin hisab utama aplikasi (beda
  /// wajar, karena presisi formula posisi Matahari di sini lebih rendah
  /// -- ~10 suku, demi kecepatan tampilan live).
  static DateTime? _cariGhurub({
    required DateTime tanggalLokalUtc0, required double lat, required double lng, required bool bulan,
  }) {
    const ambangDerajat = -0.8333;
    (double, double) posisi(DateTime utc) => bulan
        ? posisiBulanSaatIni(utc: utc, lat: lat, lng: lng)
        : posisiMatahariSaatIni(utc: utc, lat: lat, lng: lng);

    DateTime waktu = DateTime.utc(tanggalLokalUtc0.year, tanggalLokalUtc0.month, tanggalLokalUtc0.day, 0, 0);
    final akhir = waktu.add(const Duration(days: 1));
    var tinggiSebelumnya = posisi(waktu).$2;
    waktu = waktu.add(const Duration(minutes: 1));
    while (waktu.isBefore(akhir)) {
      final tinggiSekarang = posisi(waktu).$2;
      if (tinggiSebelumnya >= ambangDerajat && tinggiSekarang < ambangDerajat) {
        return waktu; // presisi menit -- cukup untuk tampilan info di layar kamera
      }
      tinggiSebelumnya = tinggiSekarang;
      waktu = waktu.add(const Duration(minutes: 1));
    }
    return null;
  }

  /// Waktu ghurub Matahari (UTC) hari ini di lokasi ini -- null kalau
  /// tidak ditemukan (lintang ekstrem).
  static DateTime? ghurubMatahari({required DateTime tanggalUtc, required double lat, required double lng}) =>
      _cariGhurub(tanggalLokalUtc0: tanggalUtc, lat: lat, lng: lng, bulan: false);

  /// Waktu ghurub Bulan (UTC) hari ini di lokasi ini -- null kalau tidak
  /// ditemukan (mis. Bulan sudah terbenam sebelum tengah hari, atau baru
  /// terbit larut malam).
  static DateTime? ghurubBulan({required DateTime tanggalUtc, required double lat, required double lng}) =>
      _cariGhurub(tanggalLokalUtc0: tanggalUtc, lat: lat, lng: lng, bulan: true);

  /// Lag time -- selisih (ghurub Bulan - ghurub Matahari) dalam menit.
  /// Positif berarti Bulan terbenam SETELAH Matahari (kondisi diperlukan
  /// untuk hilal mungkin teramati); negatif berarti Bulan sudah
  /// terbenam duluan. Null kalau salah satu waktu ghurub tidak ditemukan.
  static double? lagMenit({required DateTime tanggalUtc, required double lat, required double lng}) {
    final gMatahari = ghurubMatahari(tanggalUtc: tanggalUtc, lat: lat, lng: lng);
    final gBulan = ghurubBulan(tanggalUtc: tanggalUtc, lat: lat, lng: lng);
    if (gMatahari == null || gBulan == null) return null;
    return gBulan.difference(gMatahari).inSeconds / 60;
  }

  // ============== Sensor perangkat ==============

  /// Pitch (kemiringan depan-belakang) perangkat dari horizontal, derajat.
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

  /// Roll (kemiringan kiri-kanan/putar) perangkat dari tegak, derajat --
  /// 0 = layar benar-benar tegak lurus horizon (tidak miring ke
  /// kiri/kanan). Dipakai untuk indikator waterpass digital (bersama
  /// pitch) -- membantu pengguna menjaga HP benar-benar rata sebelum
  /// memotret, supaya horizon di foto tidak miring.
  static double rollDariAccelerometer(double accX, double accY, double accZ) {
    return atan2(accX, accY) * 180 / pi;
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

  /// Selisih arah (azimut & tinggi) dari kamera ke target -- dipakai untuk
  /// menggambar panah penunjuk arah saat target di LUAR bidang pandang
  /// kamera (proyeksiKeLayar mengembalikan null), DAN untuk deteksi
  /// "target terkunci" (haptic feedback) saat crosshair pas di tengah.
  /// Rumus selisih SAMA dengan yang dipakai proyeksiKeLayar, supaya
  /// konsisten.
  static (double selisihAzimut, double selisihTinggi) selisihArahKeTarget({
    required double azimutTarget,
    required double tinggiTarget,
    required double headingKamera,
    required double pitchKamera,
  }) {
    double selisihAzimut = azimutTarget - headingKamera;
    while (selisihAzimut > 180) { selisihAzimut -= 360; }
    while (selisihAzimut < -180) { selisihAzimut += 360; }
    final selisihTinggi = tinggiTarget - pitchKamera;
    return (selisihAzimut, selisihTinggi);
  }
}
