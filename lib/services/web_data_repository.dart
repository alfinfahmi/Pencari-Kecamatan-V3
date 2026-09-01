import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import '../models/kecamatan_model.dart';

/// Versi lazy-load khusus Web dari DataRepository.
///
/// Alih-alih memuat satu file data_koordinat.json (2.5MB) sekaligus, versi
/// ini memuat manifest.json (kecil) + referensi.json (kecil) saat startup,
/// lalu memuat file per-provinsi (rata-rata ~51KB) hanya saat dibutuhkan:
/// - saat user mengetik nama provinsi/kabupaten yang cocok, ATAU
/// - dimuat bertahap di background setelah splash agar pencarian tetap
///   terasa instan seperti versi mobile.
///
/// Dipakai hanya jika `kIsWeb == true`; untuk mobile/desktop tetap pakai
/// DataRepository biasa (assets/data/data_koordinat.json, dimuat penuh).
class WebDataRepository {
  WebDataRepository._internal();
  static final WebDataRepository instance = WebDataRepository._internal();

  static const _basePath = 'assets/data/web';

  List<KecamatanModel> _referensi = [];
  final Map<String, List<KecamatanModel>> _loadedProvinsi = {};
  List<Map<String, dynamic>> _manifestProvinsi = [];
  bool _bootstrapped = false;

  bool get isBootstrapped => _bootstrapped;
  List<KecamatanModel> get referensi => _referensi;

  /// Seluruh daftar kecamatan yang SUDAH termuat ke cache sejauh ini
  /// (bukan seluruh Indonesia — tergantung provinsi mana yang sudah
  /// di-load lewat search() atau preloadAllInBackground()).
  Iterable<List<KecamatanModel>> get loadedKecamatan => _loadedProvinsi.values;

  /// Memuat manifest + referensi saja (cepat, wajib dipanggil di awal).
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    if (!kIsWeb) {
      throw StateError('WebDataRepository hanya untuk target Web. Gunakan DataRepository untuk mobile/desktop.');
    }

    final manifestRaw = await rootBundle.loadString('$_basePath/manifest.json');
    final manifest = json.decode(manifestRaw) as Map<String, dynamic>;
    _manifestProvinsi = (manifest['provinsi'] as List).cast<Map<String, dynamic>>();

    final refRaw = await rootBundle.loadString('$_basePath/referensi.json');
    final refJson = json.decode(refRaw) as Map<String, dynamic>;
    _referensi = (refJson['referensi'] as List)
        .map((e) => KecamatanModel.fromJson(e as Map<String, dynamic>, isReferensi: true))
        .toList();

    _bootstrapped = true;
  }

  /// Memuat satu file provinsi (idempotent — tidak reload jika sudah ada).
  Future<List<KecamatanModel>> _loadProvinsi(String slug, String filePath) async {
    if (_loadedProvinsi.containsKey(slug)) return _loadedProvinsi[slug]!;

    final raw = await rootBundle.loadString('$_basePath/$filePath');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final list = (decoded['kecamatan'] as List)
        .map((e) => KecamatanModel.fromJson(e as Map<String, dynamic>))
        .toList();

    _loadedProvinsi[slug] = list;
    return list;
  }

  /// Memuat seluruh provinsi secara bertahap di background (opsional),
  /// agar setelah beberapa detik pencarian terasa selengkap versi mobile.
  Future<void> preloadAllInBackground() async {
    for (final p in _manifestProvinsi) {
      await _loadProvinsi(p['slug'] as String, p['file'] as String);
    }
  }

  /// Pencarian: menyaring provinsi yang relevan dari manifest dulu (nama
  /// provinsi cocok query, atau semua provinsi jika query tidak cocok nama
  /// provinsi manapun — lalu memuat file yang belum ada di cache.
  Future<List<KecamatanModel>> search(String query, {int limit = 50}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    // Muat provinsi yang namanya match dulu (kemungkinan besar relevan
    // dan file-nya belum tentu sudah di-cache).
    final matchingProvinsi = _manifestProvinsi.where(
      (p) => (p['nama'] as String).toLowerCase().contains(q),
    );
    for (final p in matchingProvinsi) {
      await _loadProvinsi(p['slug'] as String, p['file'] as String);
    }

    // Jika query bukan nama provinsi, kita perlu berasumsi datanya bisa ada
    // di provinsi mana saja -> muat semua yang belum ter-cache.
    // Ini query paling umum (nama kecamatan/kabupaten), jadi tak terhindarkan
    // pada model per-provinsi kecuali membangun index terpisah. Untuk UX
    // tetap responsif, panggilan ini idealnya dipicu setelah preload selesai.
    if (matchingProvinsi.isEmpty) {
      for (final p in _manifestProvinsi) {
        await _loadProvinsi(p['slug'] as String, p['file'] as String);
      }
    }

    final results = <KecamatanModel>[];
    for (final list in _loadedProvinsi.values) {
      for (final k in list) {
        if (k.searchIndex.contains(q)) {
          results.add(k);
          if (results.length >= limit) return results;
        }
      }
    }
    return results;
  }
}
