import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/kecamatan_model.dart';
import 'data_repository.dart';
import 'web_data_repository.dart';

/// Titik akses tunggal untuk data kecamatan, dipakai oleh semua screen.
///
/// - Mobile/Desktop -> DataRepository (satu file JSON, dimuat penuh di awal).
/// - Web -> WebDataRepository (manifest + referensi kecil dulu, lalu memuat
///   file per-provinsi bertahap di background agar tetap terasa instan).
///
/// Screens (splash, home, detail) memanggil AppDataService, TIDAK memanggil
/// DataRepository/WebDataRepository secara langsung, supaya tidak ada
/// percabangan kIsWeb tersebar di banyak file.
class AppDataService {
  AppDataService._internal();
  static final AppDataService instance = AppDataService._internal();

  bool get isWeb => kIsWeb;

  /// Dipanggil sekali dari SplashScreen. Untuk web, ini hanya menunggu
  /// manifest+referensi (cepat); pemuatan seluruh provinsi berjalan di
  /// background dan TIDAK di-await di sini agar splash tidak lama.
  Future<void> load() async {
    if (kIsWeb) {
      await WebDataRepository.instance.bootstrap();
      // Fire-and-forget: muat semua provinsi di belakang layar. Selama masa
      // ini, pencarian pada provinsi yang belum termuat akan otomatis
      // memicu load provinsi tersebut (lihat WebDataRepository.search).
      // ignore: unawaited_futures
      WebDataRepository.instance.preloadAllInBackground();
    } else {
      await DataRepository.instance.load();
    }
  }

  List<KecamatanModel> get referensi =>
      kIsWeb ? WebDataRepository.instance.referensi : DataRepository.instance.referensi;

  KecamatanModel get kabah => referensi.firstWhere(
        (e) => e.kecamatan.contains("Ka'bah"),
        orElse: () => referensi.first,
      );

  KecamatanModel get lirboyo => referensi.firstWhere(
        (e) => e.kecamatan.contains('Lirboyo'),
        orElse: () => referensi.last,
      );

  /// Pencarian instan. Di mobile/desktop hasilnya langsung (data sudah
  /// penuh di memori); di web, provinsi yang belum termuat akan dimuat dulu
  /// on-demand oleh WebDataRepository — karenanya method ini async di kedua
  /// platform supaya pemanggilnya seragam.
  Future<List<KecamatanModel>> search(String query, {int limit = 50}) async {
    if (kIsWeb) {
      return WebDataRepository.instance.search(query, limit: limit);
    }
    return DataRepository.instance.search(query, limit: limit);
  }

  /// Mencari satu entri berdasarkan id (dipakai untuk resolusi favorit /
  /// riwayat). Di web, hanya bisa ditemukan jika provinsi terkait sudah
  /// termuat (biasanya sudah, karena preload berjalan di background sejak
  /// splash) — jika belum, mengembalikan null dan UI menampilkannya sebagai
  /// entri kosong/terlewat, bukan error.
  KecamatanModel? findById(String id) {
    if (!kIsWeb) return DataRepository.instance.findById(id);

    final refMatch = referensi.where((r) => r.id == id);
    if (refMatch.isNotEmpty) return refMatch.first;

    for (final list in WebDataRepository.instance.loadedKecamatan) {
      final match = list.where((k) => k.id == id);
      if (match.isNotEmpty) return match.first;
    }
    return null;
  }
}
