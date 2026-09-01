import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/kecamatan_model.dart';
import 'decryption_service.dart';

/// Memuat data_koordinat dari assets dan menyediakan pencarian instan.
///
/// Untuk performa pada 7.274+ entri: data dimuat sekali (singleton) lalu
/// diindeks per-huruf-awal, bukan di-scan linear setiap kali user mengetik.
///
/// Sumber data: mencoba memuat `data_koordinat.enc` (terenkripsi AES-256,
/// hasil `encrypt_data.py`) terlebih dahulu. Jika file itu tidak ada di
/// assets (mis. saat development sebelum sempat dienkripsi), otomatis
/// jatuh ke `data_koordinat.json` polos supaya alur kerja tetap lancar.
class DataRepository {
  DataRepository._internal();
  static final DataRepository instance = DataRepository._internal();

  List<KecamatanModel> _referensi = [];
  List<KecamatanModel> _kecamatan = [];
  final Map<String, List<KecamatanModel>> _indexByFirstLetter = {};
  bool _loaded = false;
  String version = '';
  String updatedAt = '';

  bool get isLoaded => _loaded;
  List<KecamatanModel> get referensi => _referensi;
  List<KecamatanModel> get semuaKecamatan => _kecamatan;

  KecamatanModel get kabah => _referensi.firstWhere(
        (e) => e.kecamatan.contains("Ka'bah"),
        orElse: () => _referensi.first,
      );

  KecamatanModel get lirboyo => _referensi.firstWhere(
        (e) => e.kecamatan.contains('Lirboyo'),
        orElse: () => _referensi.last,
      );

  /// Sumber data: memuat `data_koordinat.enc` (terenkripsi AES-256, hasil
  /// `encrypt_data.py`) dari assets. **Wajib jalankan `python3
  /// encrypt_data.py` sekali sebelum `flutter run`/`flutter build`**, atau
  /// aplikasi tidak akan menemukan file ini. Fallback ke JSON polos hanya
  /// terjadi jika seseorang secara manual meletakkan
  /// `assets/data/data_koordinat.json` (mis. untuk debugging cepat) — file
  /// itu TIDAK disertakan secara default lagi (sengaja dipindah ke
  /// `data_source/` di luar folder assets, supaya tidak ikut ter-bundle ke
  /// build final bersamaan dengan versi terenkripsinya).
  Future<void> load() async {
    if (_loaded) return;

    String raw;
    try {
      raw = await DecryptionService.decryptAsset('assets/data/data_koordinat.enc');
    } catch (_) {
      // Fallback development: file .enc belum tersedia -> pakai JSON polos.
      raw = await rootBundle.loadString('assets/data/data_koordinat.json');
    }

    final Map<String, dynamic> jsonMap = json.decode(raw) as Map<String, dynamic>;

    final meta = jsonMap['meta'] as Map<String, dynamic>?;
    version = meta?['version']?.toString() ?? '';
    updatedAt = meta?['updated_at']?.toString() ?? '';

    _referensi = (jsonMap['referensi'] as List)
        .map((e) => KecamatanModel.fromJson(e as Map<String, dynamic>, isReferensi: true))
        .toList();

    _kecamatan = (jsonMap['kecamatan'] as List)
        .map((e) => KecamatanModel.fromJson(e as Map<String, dynamic>))
        .toList();

    _buildIndex();
    _loaded = true;
  }

  void _buildIndex() {
    _indexByFirstLetter.clear();
    for (final k in _kecamatan) {
      final huruf = k.kecamatan.isNotEmpty ? k.kecamatan[0].toLowerCase() : '#';
      _indexByFirstLetter.putIfAbsent(huruf, () => []).add(k);
    }
  }

  /// Pencarian instan berdasarkan nama kecamatan, kabupaten, provinsi, atau
  /// elevasi. Query pendek (1 huruf) memakai index huruf awal supaya tidak
  /// scan seluruh 7.274 data setiap keystroke; query lebih panjang jatuh ke
  /// pencarian substring pada seluruh dataset (masih cukup cepat di memori).
  List<KecamatanModel> search(String query, {int limit = 50}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    Iterable<KecamatanModel> pool;
    if (q.length == 1 && _indexByFirstLetter.containsKey(q)) {
      pool = _indexByFirstLetter[q]!;
    } else {
      pool = _kecamatan;
    }

    final results = <KecamatanModel>[];
    for (final k in pool) {
      if (k.searchIndex.contains(q)) {
        results.add(k);
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  KecamatanModel? findById(String id) {
    if (_referensi.any((r) => r.id == id)) {
      return _referensi.firstWhere((r) => r.id == id);
    }
    try {
      return _kecamatan.firstWhere((k) => k.id == id);
    } catch (_) {
      return null;
    }
  }
}
