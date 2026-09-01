import 'dart:math';

/// Perhitungan arah kiblat (bearing) dan jarak great-circle.
/// Formula standar ilmu falak modern (spherical trigonometry / Meeus),
/// dipakai untuk fitur "Arah Kiblat" dan "Jarak ke Ka'bah / Lirboyo".
class QiblaService {
  static const double _earthRadiusKm = 6371.0;

  static double _toRad(double deg) => deg * pi / 180.0;
  static double _toDeg(double rad) => rad * 180.0 / pi;

  /// Arah kiblat (bearing awal) dari titik (lat1, lng1) menuju Ka'bah
  /// (lat2, lng2), dalam derajat searah jarum jam dari Utara (0°-360°).
  static double bearingDerajat({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final phi1 = _toRad(lat1);
    final phi2 = _toRad(lat2);
    final deltaLambda = _toRad(lng2 - lng1);

    final y = sin(deltaLambda) * cos(phi2);
    final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);
    final theta = atan2(y, x);

    return (_toDeg(theta) + 360) % 360;
  }

  /// Jarak great-circle (Haversine) dalam kilometer.
  static double jarakKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final phi1 = _toRad(lat1);
    final phi2 = _toRad(lat2);
    final deltaPhi = _toRad(lat2 - lat1);
    final deltaLambda = _toRad(lng2 - lng1);

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadiusKm * c;
  }

  /// Label arah mata angin sederhana dari derajat bearing, untuk tampilan.
  static String arahMataAngin(double derajat) {
    const arah = [
      'Utara', 'Timur Laut', 'Timur', 'Tenggara',
      'Selatan', 'Barat Daya', 'Barat', 'Barat Laut', 'Utara',
    ];
    final index = ((derajat + 22.5) / 45).floor();
    return arah[index.clamp(0, 8)];
  }

  /// Singkatan arah mata angin (U, TL, T, TG, S, BD, B, BL) untuk tampilan ringkas.
  static String arahMataAnginSingkat(double derajat) {
    const arah = ['U', 'TL', 'T', 'TG', 'S', 'BD', 'B', 'BL', 'U'];
    final index = ((derajat + 22.5) / 45).floor();
    return arah[index.clamp(0, 8)];
  }

  /// Format derajat desimal ke DMS, mis. 294.403 -> "294° 24' 12\"".
  static String bearingKeDms(double derajat) {
    final d = derajat.floor();
    final menitDesimal = (derajat - d) * 60;
    final m = menitDesimal.floor();
    final s = ((menitDesimal - m) * 60).round();
    return "$d° $m' $s\"";
  }
}
