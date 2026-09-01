import 'package:flutter_test/flutter_test.dart';
import 'package:pencari_kecamatan/services/qibla_service.dart';

void main() {
  group('QiblaService.jarakKm', () {
    test('jarak antara dua titik identik adalah 0', () {
      final jarak = QiblaService.jarakKm(lat1: -6.2, lng1: 106.8, lat2: -6.2, lng2: 106.8);
      expect(jarak, closeTo(0, 0.001));
    });

    test('jarak Jakarta ke Ka\'bah (Makkah) mendekati ~7.900 km', () {
      // Referensi: Monas Jakarta (-6.1754, 106.8272) ke Ka'bah (21.4225, 39.8262)
      final jarak = QiblaService.jarakKm(
        lat1: -6.1754, lng1: 106.8272,
        lat2: 21.4225, lng2: 39.8262,
      );
      // Nilai referensi umum ~7.900-7.950 km (great-circle)
      expect(jarak, greaterThan(7800));
      expect(jarak, lessThan(8100));
    });

    test('jarak Kediri ke Lirboyo (dalam kota) sangat kecil', () {
      // Pondok Pesantren Lirboyo berada di Kota Kediri
      final jarak = QiblaService.jarakKm(
        lat1: -7.8168, lng1: 112.0113, // pusat Kota Kediri (perkiraan)
        lat2: -7.8300, lng2: 112.0000, // Lirboyo (perkiraan)
      );
      expect(jarak, lessThan(5));
    });
  });

  group('QiblaService.bearingDerajat', () {
    test('bearing selalu dalam rentang 0-360 derajat', () {
      final bearing = QiblaService.bearingDerajat(
        lat1: -6.1754, lng1: 106.8272,
        lat2: 21.4225, lng2: 39.8262,
      );
      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
    });

    test('dari Jakarta, arah kiblat ke Makkah condong ke Barat Laut', () {
      // Jakarta berada di timur & selatan Makkah -> bearing menuju kiblat
      // seharusnya berada di kuadran Barat Laut (sekitar 295 derajat).
      final bearing = QiblaService.bearingDerajat(
        lat1: -6.1754, lng1: 106.8272,
        lat2: 21.4225, lng2: 39.8262,
      );
      expect(bearing, greaterThan(280));
      expect(bearing, lessThan(300));
    });

    test('bearing lurus ke utara (0 derajat) saat target tepat di utara', () {
      final bearing = QiblaService.bearingDerajat(
        lat1: 0, lng1: 0,
        lat2: 10, lng2: 0,
      );
      expect(bearing, closeTo(0, 0.5));
    });

    test('bearing lurus ke timur (90 derajat) saat target tepat di timur (ekuator)', () {
      final bearing = QiblaService.bearingDerajat(
        lat1: 0, lng1: 0,
        lat2: 0, lng2: 10,
      );
      expect(bearing, closeTo(90, 0.5));
    });
  });

  group('QiblaService.arahMataAngin', () {
    test('0 derajat -> Utara', () {
      expect(QiblaService.arahMataAngin(0), 'Utara');
    });
    test('90 derajat -> Timur', () {
      expect(QiblaService.arahMataAngin(90), 'Timur');
    });
    test('180 derajat -> Selatan', () {
      expect(QiblaService.arahMataAngin(180), 'Selatan');
    });
    test('270 derajat -> Barat', () {
      expect(QiblaService.arahMataAngin(270), 'Barat');
    });
    test('295 derajat -> Barat Laut (arah kiblat dari Indonesia pada umumnya)', () {
      expect(QiblaService.arahMataAngin(295), 'Barat Laut');
    });
  });
}
