import 'dart:math';
import 'hisab_detail.dart';

/// Mesin hisab METODE JEAN MEEUS, versi LENGKAP (mengekspos semua nilai
/// antara -- deklinasi, sudut waktu, bujur, azimut, dst.) untuk keperluan
/// laporan/perbandingan di HisabAwalBulanScreen.
///
/// PENTING: rumus di sini SENGAJA DIDUPLIKASI dari HijriService (bukan
/// dipanggil langsung), supaya mesin Meeus utama yang sudah lama
/// tervalidasi dan dipakai di SELURUH aplikasi (badge tanggal, kalender,
/// waktu shalat) TIDAK tersentuh/berisiko sama sekali oleh perubahan di
/// sini. Rumusnya identik dengan yang ada di HijriService, cuma
/// diekspos lebih rinci.
///
/// Tinggi terbenam matahari standar di sini memakai -0.833 derajat tetap
/// (tanpa koreksi elevasi) -- inilah beda utama dari As-Syahru yang
/// memperhitungkan elevasi tempat. Tinggi hilal Mar'i dihitung dari
/// tinggi Hakiki memakai rumus koreksi UNIVERSAL yang sama dengan
/// As-Syahru (lihat koreksiHakikiKeMarI di hisab_detail.dart) supaya
/// kedua metode bisa dibandingkan setara.
class MeeusHisabService {
  MeeusHisabService._();

  static double _sind(double x) => sin(x * pi / 180);
  static double _cosd(double x) => cos(x * pi / 180);
  static double _tand(double x) => tan(x * pi / 180);
  static double _asind(double x) => asin(x.clamp(-1.0, 1.0)) * 180 / pi;
  static double _atand(double x) => atan(x) * 180 / pi;
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

  static (double decl, double ra) _sunEquatorial(double jd) {
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

  static double _sunTrueLongitude(double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    final l0 = _mod(280.46646 + 36000.76983 * t + 0.0003032 * t * t, 360);
    final m = _mod(357.52911 + 35999.05029 * t - 0.0001537 * t * t, 360);
    final c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * _sind(m) +
        (0.019993 - 0.000101 * t) * _sind(2 * m) +
        0.000289 * _sind(3 * m);
    return _mod(l0 + c, 360);
  }

  static (double lon, double lat, double decl, double ra) _moonPosisi(double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    final lp = _mod(218.3164477 + 481267.88123421 * t - 0.0015786 * t * t, 360);
    final d = _mod(297.8501921 + 445267.1114034 * t - 0.0018819 * t * t, 360);
    final m = _mod(357.5291092 + 35999.0502909 * t - 0.0001536 * t * t, 360);
    final mp = _mod(134.9633964 + 477198.8675055 * t + 0.0087414 * t * t, 360);
    final f = _mod(93.2720950 + 483202.0175233 * t - 0.0036539 * t * t, 360);

    final lon = lp +
        6.288774 * _sind(mp) +
        1.274027 * _sind(2 * d - mp) +
        0.658314 * _sind(2 * d) +
        0.213618 * _sind(2 * mp) -
        0.185116 * _sind(m) -
        0.114332 * _sind(2 * f);
    final lat = 5.128122 * _sind(f) +
        0.280602 * _sind(mp + f) +
        0.277693 * _sind(mp - f) +
        0.173237 * _sind(2 * d - f);

    const eps = 23.4392911;
    final ra = _atan2d(_sind(lon) * _cosd(eps) - _tand(lat) * _sind(eps), _cosd(lon));
    final decl = _asind(_sind(lat) * _cosd(eps) + _cosd(lat) * _sind(eps) * _sind(lon));
    return (_mod(lon, 360), lat, decl, ra);
  }

  static double _altitude(double decl, double lat, double hourAngleDeg) {
    return _asind(_sind(lat) * _sind(decl) + _cosd(lat) * _cosd(decl) * _cosd(hourAngleDeg));
  }

  static double _hourAngleFromRa(double jd, double ra, double lng) {
    final t = (jd - 2451545.0) / 36525.0;
    final gmst = _mod(280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * t * t, 360);
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
    final jam = (lo + hi) / 2;
    final dtLokal = DateTime(tanggalLokal.year, tanggalLokal.month, tanggalLokal.day)
        .add(Duration(minutes: (jam * 60).round()));
    return dtLokal.subtract(Duration(hours: utcOffset));
  }

  /// Cari waktu ijtimak (konjungsi/new moon) memakai algoritma Jean Meeus
  /// Bab 49 "Phases of the Moon" (Astronomical Algorithms) -- BUKAN
  /// formula linear sederhana K=(Y+29.53...)x12 yang selama ini dipakai
  /// bersama oleh HijriService untuk kedua metode. Tervalidasi cocok
  /// PERSIS terhadap tabel referensi independen (perbandingan Jean Meeus
  /// vs As-Syahru, 1440H-1464H) hingga menit, termasuk koreksi ΔT
  /// (selisih Terrestrial Time ke UT) yang tanpanya hasilnya meleset
  /// beberapa menit.
  ///
  /// `k` = indeks bulan sinodis sejak epoch Meeus (2000.0); k=232 adalah
  /// ijtimak akhir Dzulhijjah 1439H / awal Muharram 1440H (9 Okt 2018),
  /// dipakai sebagai jangkar. Karena tiap bulan Hijriah = tepat satu
  /// siklus sinodis berurutan, k bertambah 1 setiap kali bulanH maju 1.
  static DateTime cariIjtimakUtc({required int tahunH, required int bulanH}) {
    final k = (232 + (tahunH - 1440) * 12 + (bulanH - 1)).toDouble();
    final t = k / 1236.85;

    double sind(double x) => sin(x * pi / 180);

    final jde = 2451550.09766 +
        29.530588861 * k +
        0.00015437 * t * t -
        0.000000150 * t * t * t +
        0.00000000073 * t * t * t * t;

    final e = 1 - 0.002516 * t - 0.0000074 * t * t;
    final m = 2.5534 + 29.10535669 * k - 0.0000014 * t * t - 0.00000011 * t * t * t;
    final mp = 201.5643 + 385.81693528 * k + 0.0107582 * t * t + 0.00001238 * t * t * t - 0.000000058 * t * t * t * t;
    final f = 160.7108 + 390.67050284 * k - 0.0016118 * t * t - 0.00000227 * t * t * t + 0.000000011 * t * t * t * t;
    final omega = 124.7746 - 1.56375588 * k + 0.0020672 * t * t + 0.00000215 * t * t * t;

    final dJde = -0.40720 * sind(mp) +
        0.17241 * e * sind(m) +
        0.01608 * sind(2 * mp) +
        0.01039 * sind(2 * f) +
        0.00739 * e * sind(mp - m) -
        0.00514 * e * sind(mp + m) +
        0.00208 * e * e * sind(2 * m) -
        0.00111 * sind(mp - 2 * f) -
        0.00057 * sind(mp + 2 * f) +
        0.00056 * e * sind(2 * mp + m) -
        0.00042 * sind(3 * mp) +
        0.00042 * e * sind(m + 2 * f) +
        0.00038 * e * sind(m - 2 * f) -
        0.00024 * e * sind(2 * mp - m) -
        0.00017 * sind(omega) -
        0.00007 * sind(mp + 2 * m) +
        0.00004 * sind(2 * mp - 2 * f) +
        0.00004 * sind(3 * m) +
        0.00003 * sind(mp + m - 2 * f) +
        0.00003 * sind(2 * mp + 2 * f) -
        0.00003 * sind(mp + m + 2 * f) +
        0.00003 * sind(mp - m + 2 * f) -
        0.00002 * sind(mp - m - 2 * f) -
        0.00002 * sind(3 * mp + m) +
        0.00002 * sind(4 * mp);

    final a1 = 299.77 + 0.107408 * k - 0.009173 * t * t;
    final a2 = 251.88 + 0.016321 * k;
    final a3 = 251.83 + 26.651886 * k;
    final a4 = 349.42 + 36.412478 * k;
    final a5 = 84.66 + 18.206239 * k;
    final a6 = 141.74 + 53.303771 * k;
    final a7 = 207.14 + 2.453732 * k;
    final a8 = 154.84 + 7.306860 * k;
    final a9 = 34.52 + 27.261239 * k;
    final a10 = 207.19 + 0.121824 * k;
    final a11 = 291.34 + 1.844379 * k;
    final a12 = 161.72 + 24.198154 * k;
    final a13 = 239.56 + 25.513099 * k;
    final a14 = 331.55 + 3.592518 * k;

    final tambahan = 0.000325 * sind(a1) +
        0.000165 * sind(a2) +
        0.000164 * sind(a3) +
        0.000126 * sind(a4) +
        0.000110 * sind(a5) +
        0.000062 * sind(a6) +
        0.000060 * sind(a7) +
        0.000056 * sind(a8) +
        0.000047 * sind(a9) +
        0.000042 * sind(a10) +
        0.000040 * sind(a11) +
        0.000037 * sind(a12) +
        0.000035 * sind(a13) +
        0.000023 * sind(a14);

    final jdeFinal = jde + dJde + tambahan;

    // Koreksi DeltaT (Terrestrial Time -> UT) -- polinomial Espenak/Meeus,
    // akurat untuk rentang tahun 2005-2050. Tanpa koreksi ini, hasilnya
    // meleset beberapa menit dari nilai sebenarnya.
    final tahunPerkiraan = 2000 + (k - 232) / 12.3685 + 2018.77 - 2000;
    final y = tahunPerkiraan - 2000;
    final deltaTDetik = 62.92 + 0.32217 * y + 0.005589 * y * y;

    final jdUt = jdeFinal - deltaTDetik / 86400.0;
    return DateTime.utc(2000, 1, 1, 12).add(Duration(microseconds: ((jdUt - 2451545.0) * 86400 * 1000000).round()));
  }

  static HasilHisabDetail hitung({
    required DateTime ijtimakUtc,
    required double lat,
    required double lng,
    required double elevasiM,
    required int utcOffset,
  }) {
    final tanggalLokal = ijtimakUtc.add(Duration(hours: utcOffset));
    final maghribUtc = _cariMaghribUtc(tanggalLokal, lat, lng, utcOffset);
    final maghribLokal = maghribUtc.add(Duration(hours: utcOffset));
    final ghurubMatahariJam = maghribLokal.hour + maghribLokal.minute / 60 + maghribLokal.second / 3600;

    final jd = _julianDay(maghribUtc);
    final (declS, raS) = _sunEquatorial(jd);
    final (lonBulan, _, declM, raM) = _moonPosisi(jd);
    final bujurMatahari = _sunTrueLongitude(jd);

    final haS = _hourAngleFromRa(jd, raS, lng);
    final haM = _hourAngleFromRa(jd, raM, lng);
    final altM = _altitude(declM, lat, haM);

    // Rumus azimut PERSIS sama strukturnya dengan yang dipakai
    // AsSyahruService (bukan atan2 konvensi lain) -- supaya konvensi
    // sudutnya konsisten dan hasil kedua metode bisa dibandingkan adil.
    final azimutMatahari = _atand(_tand(declS) * _cosd(lat) / _sind(haS) - _sind(lat) / _tand(haS));
    final azimutBulan = _atand(_tand(declM) * _cosd(lat) / _sind(haM) - _sind(lat) / _tand(haM));

    final cosElong = (_sind(declS) * _sind(declM) + _cosd(declS) * _cosd(declM) * _cosd(raS - raM)).clamp(-1.0, 1.0);
    final elongasi = acos(cosElong) * 180 / pi;

    final tinggiHilalMari = koreksiHakikiKeMarI(altM, elevasiM);
    final lamaHilalJam = tinggiHilalMari / 15;
    final ghurubHilalJam = ghurubMatahariJam + lamaHilalJam;

    final jarakAzimutMatahariBulan = azimutBulan - azimutMatahari; // sama seperti As-Syahru: selisih langsung, tanpa normalisasi
    final nurulHilal = sqrt(jarakAzimutMatahariBulan * jarakAzimutMatahariBulan + altM * altM) / 15 * 2.5;

    return HasilHisabDetail(
      namaMetode: 'Jean Meeus',
      tinggiHilalHakiki: altM,
      tinggiHilalMari: tinggiHilalMari,
      elongasi: elongasi,
      azimutMatahari: _mod(azimutMatahari, 360),
      azimutBulan: _mod(azimutBulan, 360),
      lamaHilalJam: lamaHilalJam,
      nurulHilal: nurulHilal,
      ghurubMatahariJam: ghurubMatahariJam,
      ghurubHilalJam: ghurubHilalJam,
      tinggiMatahariSaatTerbenam: -0.833,
      deklinasiMatahari: declS,
      sudutWaktuMatahari: haS,
      bujurMatahari: bujurMatahari,
      bujurBulan: lonBulan,
      sudutWaktuBulan: haM,
      deklinasiBulan: declM,
      jarakAzimutMatahariBulan: jarakAzimutMatahariBulan,
    );
  }
}
