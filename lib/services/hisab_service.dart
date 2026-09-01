import 'dart:math';

/// Hasil hitungan satu waktu shalat: waktu daerah (WIB/WITA/WIT) & Jam Istiwa'.
class WaktuShalatEntry {
  final String nama;
  final DateTime waktuDaerah;
  final DateTime jamIstiwa;
  WaktuShalatEntry({required this.nama, required this.waktuDaerah, required this.jamIstiwa});
}

/// Engine hisab waktu shalat & Jam Istiwa', berdasarkan posisi matahari
/// (deklinasi & equation of time, algoritma Meeus/NOAA presisi rendah —
/// Astronomical Algorithms, Jean Meeus, bab 25 & 28) dan formula hour angle
/// standar untuk sudut depresi tertentu.
///
/// CATATAN PENTING: engine ini sudah divalidasi numerik (dibandingkan
/// terhadap tabel contoh dari spesifikasi project) dan hasilnya masuk akal
/// (selisih beberapa menit, wajar karena tanggal berbeda). NAMUN ini BUKAN
/// pengganti validasi resmi terhadap kitab rujukan Lajnah Falakiyah Lirboyo.
/// Sebelum dipakai operasional, cocokkan hasilnya dengan engine hisab yang
/// sudah tervalidasi Kemenag RI (disebutkan pernah dibangun sebelumnya).
///
/// Konvensi yang MASIH PERLU DIKONFIRMASI ke rujukan resmi Lirboyo:
/// - Imsak: dihitung sebagai 10 menit sebelum Subuh (konvensi umum
///   Indonesia), BUKAN dari sudut depresi tersendiri. Jika Lirboyo punya
///   ketentuan berbeda (mis. sudut imsak khusus), sesuaikan `_imsakOffsetMin`.
/// - Dhuha: matahari pada ketinggian +4.5° di atas ufuk (konvensi umum).
/// - Ashar: metode bayang-bayang standar (Syafi'i/jumhur), bukan madzhab Hanafi.
class HisabService {
  static const double _imsakOffsetMin = 10.0;
  static const double _dhuhaAltitudeDeg = 4.5;

  static double _toRad(double deg) => deg * pi / 180.0;
  static double _toDeg(double rad) => rad * 180.0 / pi;

  static double _julianDay(DateTime utcNoon) {
    int y = utcNoon.year;
    int m = utcNoon.month;
    final d = utcNoon.day +
        (utcNoon.hour + utcNoon.minute / 60.0 + utcNoon.second / 3600.0) / 24.0;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final A = (y / 100).floor();
    final B = 2 - A + (A / 4).floor();
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        d +
        B -
        1524.5;
  }

  /// Mengembalikan (deklinasi derajat, equation of time menit) untuk hari
  /// tersebut (dihitung pada tengah hari UTC agar representatif untuk
  /// seluruh hari, praktik umum aplikasi waktu shalat).
  static (double, double) _sunPosition(double jd) {
    final T = (jd - 2451545.0) / 36525.0;
    final L0 = (280.46646 + 36000.76983 * T + 0.0003032 * T * T) % 360;
    final M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T) % 360;
    final Mr = _toRad(M);

    final C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * sin(Mr) +
        (0.019993 - 0.000101 * T) * sin(2 * Mr) +
        0.000289 * sin(3 * Mr);

    final trueLong = L0 + C;
    final omega = 125.04 - 1934.136 * T;
    final appLong = trueLong - 0.00569 - 0.00478 * sin(_toRad(omega));

    final eps0 = 23 +
        (26 +
                (21.448 -
                        T * (46.815 + T * (0.00059 - T * 0.001813))) /
                    60) /
            60;
    final eps = eps0 + 0.00256 * cos(_toRad(omega));

    final decl = _toDeg(asin(sin(_toRad(eps)) * sin(_toRad(appLong))));

    final e = 0.016708634 - 0.000042037 * T - 0.0000001267 * T * T;
    final y = pow(tan(_toRad(eps / 2)), 2).toDouble();
    final L0r = _toRad(L0);
    final eot = y * sin(2 * L0r) -
        2 * e * sin(Mr) +
        4 * e * y * sin(Mr) * cos(2 * L0r) -
        0.5 * y * y * sin(4 * L0r) -
        1.25 * e * e * sin(2 * Mr);
    final eotMinutes = _toDeg(eot) * 4;

    return (decl, eotMinutes);
  }

  static double _hourAngle(double latDeg, double declDeg, double altitudeDeg) {
    final lat = _toRad(latDeg);
    final decl = _toRad(declDeg);
    final alt = _toRad(altitudeDeg);
    double cosH = (sin(alt) - sin(lat) * sin(decl)) / (cos(lat) * cos(decl));
    cosH = cosH.clamp(-1.0, 1.0);
    return _toDeg(acos(cosH));
  }

  /// Koreksi kerendahan ufuk (derajat) akibat ketinggian tempat (mdpl).
  static double horizonDip(double elevasiM) {
    if (elevasiM <= 0) return 0;
    return 0.0347 * sqrt(elevasiM);
  }

  /// Menghitung seluruh waktu shalat untuk satu hari.
  ///
  /// [tanggal] tanggal lokal (jam diabaikan, dihitung untuk tengah hari itu).
  /// [utcOffset] offset zona waktu daerah dalam jam (WIB=7, WITA=8, WIT=9).
  static List<WaktuShalatEntry> hitung({
    required DateTime tanggal,
    required double lat,
    required double lng,
    required double elevasiM,
    required int utcOffset,
    required double sudutIsya,
    required double sudutSubuh,
    required Map<String, double> ihtiyathMenit, // key: imsak,subuh,terbit,dhuha,dhuhur,ashar,maghrib,isya
  }) {
    final noonUtc = DateTime.utc(tanggal.year, tanggal.month, tanggal.day, 12, 0, 0);
    final jd = _julianDay(noonUtc);
    final (decl, eot) = _sunPosition(jd);

    // Offset konstan per hari antara Jam Istiwa' & Waktu Zona (jam).
    final offsetJam = eot / 60 + lng / 15 - utcOffset;

    double istiwaToZonaJam(double istiwaJam) => istiwaJam - offsetJam;

    final dip = horizonDip(elevasiM);

    // Dhuhur / zawal
    const dhuhurIstiwa = 12.0;

    // Ashar (metode bayang-bayang standar/jumhur)
    final latR = _toRad(lat);
    final declR = _toRad(decl);
    final zawalShadow = (tan(latR - declR)).abs();
    final altAshar = _toDeg(atan(1 / (zawalShadow + 1)));
    final hAshar = _hourAngle(lat, decl, altAshar);
    final asharIstiwa = 12 + hAshar / 15;

    // Maghrib: altitude -0.833 (refraksi + semidiameter) dikurangi dip elevasi
    final altMaghrib = -0.833 - dip;
    final hMaghrib = _hourAngle(lat, decl, altMaghrib);
    final maghribIstiwa = 12 + hMaghrib / 15;

    // Terbit (sunrise): simetris dengan maghrib, sebelum zawal
    final terbitIstiwa = 12 - hMaghrib / 15;

    // Isya
    final hIsya = _hourAngle(lat, decl, sudutIsya);
    final isyaIstiwa = 12 + hIsya / 15;

    // Subuh
    final hSubuh = _hourAngle(lat, decl, sudutSubuh);
    final subuhIstiwa = 12 - hSubuh / 15;

    // Dhuha
    final hDhuha = _hourAngle(lat, decl, _dhuhaAltitudeDeg);
    final dhuhaIstiwa = 12 - hDhuha / 15;

    // Imsak: konvensi 10 menit sebelum Subuh
    final imsakIstiwa = subuhIstiwa - _imsakOffsetMin / 60;

    final events = <String, double>{
      'Imsak': imsakIstiwa,
      'Subuh': subuhIstiwa,
      'Terbit': terbitIstiwa,
      'Dhuha': dhuhaIstiwa,
      'Dhuhur': dhuhurIstiwa,
      'Ashar': asharIstiwa,
      'Maghrib': maghribIstiwa,
      "Isya'": isyaIstiwa,
    };

    final ihtiyathKeyMap = {
      'Imsak': 'imsak', 'Subuh': 'subuh', 'Terbit': 'terbit', 'Dhuha': 'dhuha',
      'Dhuhur': 'dhuhur', 'Ashar': 'ashar', 'Maghrib': 'maghrib', "Isya'": 'isya',
    };

    final hasil = <WaktuShalatEntry>[];
    for (final entry in events.entries) {
      final ihtiyath = ihtiyathMenit[ihtiyathKeyMap[entry.key]] ?? 0.0;
      final istiwaFinalJam = entry.value + ihtiyath / 60;
      final zonaFinalJam = istiwaToZonaJam(entry.value) + ihtiyath / 60;

      hasil.add(WaktuShalatEntry(
        nama: entry.key,
        waktuDaerah: _jamKeDatetime(tanggal, zonaFinalJam),
        jamIstiwa: _jamKeDatetime(tanggal, istiwaFinalJam),
      ));
    }

    return hasil;
  }

  static DateTime _jamKeDatetime(DateTime tanggal, double jamDesimal) {
    var totalDetik = (jamDesimal * 3600).round();
    var hari = 0;
    while (totalDetik < 0) {
      totalDetik += 86400;
      hari -= 1;
    }
    while (totalDetik >= 86400) {
      totalDetik -= 86400;
      hari += 1;
    }
    final h = totalDetik ~/ 3600;
    final m = (totalDetik % 3600) ~/ 60;
    final s = totalDetik % 60;
    return DateTime(tanggal.year, tanggal.month, tanggal.day + hari, h, m, s);
  }
}
