import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pencari_kecamatan/services/hisab_ephemeris_service.dart';

/// Angka rujukan dari implementasi Python `tools/ephemeris/
/// hisab_ephemeris_ref.py` (rumus identik) di atas aset yg sama.
/// Ramadan 1447 H juga dicocokkan dgn data resmi Kemenag (17 Feb 2026):
/// ijtimak 19.01 WIB, ghurub Jakarta Pusat 18:15:17 WIB.
void main() {
  setUpAll(() {
    for (final tahun in [2026, 2027]) {
      HisabEphemerisService.muatDariTeks(
          tahun, File('assets/data/ephemeris/$tahun.csv').readAsStringSync());
    }
  });

  double jamDesimal(DateTime t) => t.hour + t.minute / 60 + t.second / 3600 + t.millisecond / 3.6e6;

  group('Ramadan 1447 H, Jakarta Pusat', () {
    late DateTime ijtimak;
    setUp(() => ijtimak = HisabEphemerisService.cariIjtimakUtc(tahunH: 1447, bulanH: 9));

    test('ijtimak 17 Feb 2026 12:01:09 UT (= 19:01 WIB, Kemenag 19.01)', () {
      expect(ijtimak.year, 2026);
      expect(ijtimak.month, 2);
      expect(ijtimak.day, 17);
      expect(jamDesimal(ijtimak), closeTo(12.019177, 0.0003));
    });

    test('ghurub, tinggi, elongasi', () {
      final h = HisabEphemerisService.hitung(
          ijtimakUtc: ijtimak, lat: -6.1754, lng: 106.8272, elevasiM: 0, utcOffset: 7);
      expect(h.ghurubMatahariJam, closeTo(18.25566, 0.0002)); // Kemenag 18:15:17 = 18.2547
      expect(h.tinggiHilalHakiki, closeTo(-0.75352, 0.001));
      expect(h.tinggiHilalMari, closeTo(-0.51479, 0.001));
      expect(h.elongasi, closeTo(1.040554, 0.001));
      expect(h.memenuhiMabims2021, isFalse);
    });
  });

  group("Sya'ban 1448 H, Badas Kediri", () {
    test('ijtimak & keadaan hilal', () {
      final ijtimak = HisabEphemerisService.cariIjtimakUtc(tahunH: 1448, bulanH: 8);
      expect(ijtimak.day, 7);
      expect(jamDesimal(ijtimak), closeTo(20.406455, 0.0003));
      final h = HisabEphemerisService.hitung(
          ijtimakUtc: ijtimak, lat: -7.7130861, lng: 112.205775, elevasiM: 111, utcOffset: 7);
      expect(h.ghurubMatahariJam, closeTo(17.924932, 0.0002));
      expect(h.tinggiHilalHakiki, closeTo(5.761079, 0.001));
      expect(h.tinggiHilalMari, closeTo(5.582307, 0.001));
      expect(h.elongasi, closeTo(6.926365, 0.001));
      expect(h.azimutMatahari, closeTo(-22.626131, 0.001));
      expect(h.azimutBulan, closeTo(-23.001939, 0.001));
      expect(h.memenuhiMabims2021, isTrue);
    });
  });

  test('di luar rentang data -> statusData tidakTersedia', () {
    expect(() => HisabEphemerisService.cariIjtimakUtc(tahunH: 1500, bulanH: 1),
        throwsA(isA<DataEphemerisTidakTersedia>()));
  });
}
