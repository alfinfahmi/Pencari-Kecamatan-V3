import 'package:hive_flutter/hive_flutter.dart';
import 'hijri_service.dart';

/// Menyimpan pilihan kriteria imkan rukyat pengguna (MABIMS 2021 / Irtifa
/// 2° + usia hilal / dst.), dan memuatnya ke HijriService.kriteriaAktif
/// saat aplikasi start -- default MABIMS 2021 kalau belum pernah diatur.
class HisabPreferenceService {
  static const _boxName = 'hisab_preference';
  static const _keyKriteria = 'kriteria_imkan_rukyat';

  Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) return Hive.openBox(_boxName);
    return Hive.box(_boxName);
  }

  /// Dipanggil sekali saat aplikasi start (lihat main.dart) -- memuat
  /// preferensi tersimpan ke HijriService.kriteriaAktif.
  static Future<void> muatKeHijriService() async {
    try {
      final box = await Hive.openBox(_boxName);
      final index = box.get(_keyKriteria) as int?;
      if (index != null && index >= 0 && index < KriteriaImkanRukyat.values.length) {
        HijriService.kriteriaAktif = KriteriaImkanRukyat.values[index];
      }
    } catch (_) {
      // Gagal muat -- tetap pakai default (MABIMS 2021), jangan crash.
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
}
