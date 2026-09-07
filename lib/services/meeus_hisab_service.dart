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
