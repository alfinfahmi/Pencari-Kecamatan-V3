import 'package:hive_flutter/hive_flutter.dart';
import 'hijri_service.dart';

/// Menyimpan pilihan kriteria imkan rukyat & metode hisab pengguna
/// (MABIMS 2021 / Irtifa 2°+usia hilal / dst., Jean Meeus / As-Syahru),
/// dan memuatnya ke HijriService saat aplikasi start -- default MABIMS
/// 2021 + Jean Meeus kalau belum pernah diatur.
class HisabPreferenceService {
  static const _boxName = 'hisab_preference';
  static const _keyKriteria = 'kriteria_imkan_rukyat';
  static const _keyMetode = 'metode_hisab';

  Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) return Hive.openBox(_boxName);
    return Hive.box(_boxName);
  }

  /// Dipanggil sekali saat aplikasi start (lihat main.dart) -- memuat
  /// preferensi tersimpan ke HijriService.
  static Future<void> muatKeHijriService() async {
    try {
      final box = await Hive.openBox(_boxName);
      final indexKriteria = box.get(_keyKriteria) as int?;
      if (indexKriteria != null && indexKriteria >= 0 && indexKriteria < KriteriaImkanRukyat.values.length) {
        HijriService.kriteriaAktif = KriteriaImkanRukyat.values[indexKriteria];
      }
      final indexMetode = box.get(_keyMetode) as int?;
      if (indexMetode != null && indexMetode >= 0 && indexMetode < MetodeHisab.values.length) {
        HijriService.metodeAktif = MetodeHisab.values[indexMetode];
      }
    } catch (_) {
      // Gagal muat -- tetap pakai default (MABIMS 2021 + Jean Meeus), jangan crash.
    }
  }

  Future<KriteriaImkanRukyat> getKriteria() async {
    final box = await _box();
    final index = box.get(_keyKriteria) as int?;
    if (index == null || index < 0 || index >= KriteriaImkanRukyat.values.length) {
      return KriteriaImkanRukyat.mabims2021;
    }
    return KriteriaImkanRukyat.values[index];
  }

  Future<void> setKriteria(KriteriaImkanRukyat kriteria) async {
    final box = await _box();
    await box.put(_keyKriteria, kriteria.index);
    // Perbarui cache di memori LANGSUNG (synchronous) supaya efeknya
    // terasa seketika tanpa perlu restart aplikasi.
    HijriService.kriteriaAktif = kriteria;
  }

  Future<MetodeHisab> getMetode() async {
    final box = await _box();
    final index = box.get(_keyMetode) as int?;
    if (index == null || index < 0 || index >= MetodeHisab.values.length) {
      return MetodeHisab.jeanMeeus;
    }
    return MetodeHisab.values[index];
  }

  Future<void> setMetode(MetodeHisab metode) async {
    final box = await _box();
    await box.put(_keyMetode, metode.index);
    HijriService.metodeAktif = metode;
  }
}
