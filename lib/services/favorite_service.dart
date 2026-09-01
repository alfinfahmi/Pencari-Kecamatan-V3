import 'package:hive_flutter/hive_flutter.dart';

/// Menyimpan daftar favorit & riwayat pencarian terakhir, sebagai daftar
/// `id` yang merujuk ke KecamatanModel (referensi maupun kecamatan biasa).
/// Dua fitur ini dipisah sesuai kesepakatan final: favorit ditandai manual
/// oleh pengguna, riwayat terisi otomatis dari pencarian.
class FavoriteService {
  static const _favBox = 'favorites';
  static const _historyBox = 'search_history';
  static const _maxHistory = 20;

  Future<Box<String>> _favorites() async {
    if (!Hive.isBoxOpen(_favBox)) return Hive.openBox<String>(_favBox);
    return Hive.box<String>(_favBox);
  }

  Future<Box<String>> _history() async {
    if (!Hive.isBoxOpen(_historyBox)) return Hive.openBox<String>(_historyBox);
    return Hive.box<String>(_historyBox);
  }

  Future<List<String>> getFavoriteIds() async {
    final box = await _favorites();
    return box.values.toList();
  }

  Future<bool> isFavorite(String id) async {
    final box = await _favorites();
    return box.values.contains(id);
  }

  Future<void> toggleFavorite(String id) async {
    final box = await _favorites();
    final key = box.keys.firstWhere(
      (k) => box.get(k) == id,
      orElse: () => null,
    );
    if (key != null) {
      await box.delete(key);
    } else {
      await box.add(id);
    }
  }

  Future<List<String>> getHistoryIds() async {
    final box = await _history();
    return box.values.toList().reversed.toList();
  }

  Future<void> addToHistory(String id) async {
    final box = await _history();
    // Hindari duplikat berurutan
    final existing = box.values.toList();
    existing.remove(id);
    await box.clear();
    existing.add(id);
    if (existing.length > _maxHistory) {
      existing.removeRange(0, existing.length - _maxHistory);
    }
    for (final e in existing) {
      await box.add(e);
    }
  }

  Future<void> clearHistory() async {
    final box = await _history();
    await box.clear();
  }
}
