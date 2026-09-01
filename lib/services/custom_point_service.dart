import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/custom_point_model.dart';

/// CRUD titik kustom (desa/dusun/masjid/lainnya) + ekspor/impor manual
/// sebagai file .json, sesuai kesepakatan final (backup lintas perangkat
/// tanpa server, tetap 100% offline).
class CustomPointService {
  static const _boxName = 'custom_points';

  Future<Box<CustomPointModel>> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox<CustomPointModel>(_boxName);
    }
    return Hive.box<CustomPointModel>(_boxName);
  }

  Future<List<CustomPointModel>> getAll() async {
    final box = await _box();
    return box.values.toList();
  }

  Future<List<CustomPointModel>> getByKecamatan(String kecamatanId) async {
    final all = await getAll();
    return all.where((p) => p.kecamatanId == kecamatanId).toList();
  }

  Future<void> add(CustomPointModel point) async {
    final box = await _box();
    await box.put(point.id, point);
  }

  Future<void> delete(String id) async {
    final box = await _box();
    await box.delete(id);
  }

  Future<void> update(CustomPointModel point) async {
    final box = await _box();
    await box.put(point.id, point);
  }

  /// Ekspor seluruh titik kustom ke file JSON, lalu buka share sheet
  /// (WhatsApp/email/simpan manual) — tanpa server, sesuai kesepakatan.
  Future<void> exportToFile() async {
    final all = await getAll();
    final jsonList = all.map((p) => p.toJson()).toList();
    final payload = {
      'exported_at': DateTime.now().toIso8601String(),
      'jumlah_titik': jsonList.length,
      'titik_kustom': jsonList,
    };

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/titik_kustom_export.json');
    await file.writeAsString(json.encode(payload));

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Backup titik kustom — Koordinat Kec. Tashil',
    );
  }

  /// Impor file JSON hasil ekspor. Menambahkan (bukan menimpa) titik yang
  /// sudah ada di perangkat, berdasarkan id.
  Future<int> importFromFile(File file) async {
    final content = await file.readAsString();
    final Map<String, dynamic> payload = json.decode(content) as Map<String, dynamic>;
    final List list = payload['titik_kustom'] as List;

    final box = await _box();
    int added = 0;
    for (final item in list) {
      final point = CustomPointModel.fromJson(item as Map<String, dynamic>);
      if (!box.containsKey(point.id)) {
        await box.put(point.id, point);
        added++;
      }
    }
    return added;
  }
}
