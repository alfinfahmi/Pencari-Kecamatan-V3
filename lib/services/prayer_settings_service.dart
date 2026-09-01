import 'package:hive_flutter/hive_flutter.dart';

/// Pengaturan waktu shalat parametrik (ihtiyath & sudut depresi), disimpan
/// lokal via Hive. Nilai default sesuai spesifikasi resmi:
/// - Ihtiyath: Ashar/Maghrib/Isya'/Imsak/Subuh/Dhuha default +2 menit
///   (opsional 2-5 menit); Terbit/Thulu' default -2 menit.
/// - Sudut depresi Isya': default -17.8° (opsional lain, mis. -17.0°, -18.0°).
/// - Sudut depresi Subuh: default -19.8° (opsional lain, mis. -19.0°, -20.0°).
class PrayerSettingsService {
  static const _boxName = 'prayer_settings';

  static const defaultIhtiyath = {
    'imsak': 2.0, 'subuh': 2.0, 'dhuha': 2.0, 'dhuhur': 2.0,
    'ashar': 2.0, 'maghrib': 2.0, 'isya': 2.0, 'terbit': -2.0,
  };
  static const defaultSudutIsya = -17.8;
  static const defaultSudutSubuh = -19.8;

  // Pilihan sudut depresi yang bisa dipilih pengguna (opsional, sesuai spek).
  static const opsiSudutIsya = [-17.0, -17.8, -18.0, -18.5];
  static const opsiSudutSubuh = [-19.0, -19.8, -20.0, -20.5];
  static const opsiIhtiyathMenit = [2, 3, 4, 5];

  Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) return Hive.openBox(_boxName);
    return Hive.box(_boxName);
  }

  Future<Map<String, double>> getIhtiyath() async {
    final box = await _box();
    final result = <String, double>{};
    for (final key in defaultIhtiyath.keys) {
      result[key] = (box.get('ihtiyath_$key', defaultValue: defaultIhtiyath[key]) as num).toDouble();
    }
    return result;
  }

  Future<void> setIhtiyath(String waktu, double menit) async {
    final box = await _box();
    await box.put('ihtiyath_$waktu', menit);
  }

  Future<double> getSudutIsya() async {
    final box = await _box();
    return (box.get('sudut_isya', defaultValue: defaultSudutIsya) as num).toDouble();
  }

  Future<void> setSudutIsya(double sudut) async {
    final box = await _box();
    await box.put('sudut_isya', sudut);
  }

  Future<double> getSudutSubuh() async {
    final box = await _box();
    return (box.get('sudut_subuh', defaultValue: defaultSudutSubuh) as num).toDouble();
  }

  Future<void> setSudutSubuh(double sudut) async {
    final box = await _box();
    await box.put('sudut_subuh', sudut);
  }

  Future<void> resetKeDefault() async {
    final box = await _box();
    await box.clear();
  }
}
