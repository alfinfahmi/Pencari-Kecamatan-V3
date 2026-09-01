import 'package:hive_flutter/hive_flutter.dart';

/// Menyimpan pilihan lokasi override untuk widget waktu shalat di Home
/// (default: GPS perangkat langsung), DAN lokasi GPS terakhir yang berhasil
/// sebagai fallback offline-first -- supaya widget tidak "buntu" kalau GPS
/// gagal (mis. di dalam gedung/sinyal lemah) padahal sebelumnya pernah
/// berhasil dapat titik yang wajar.
class HomeLocationService {
  static const _boxName = 'home_location';
  static const _keyOverrideId = 'override_kecamatan_id';
  static const _keyLastLat = 'last_gps_lat';
  static const _keyLastLng = 'last_gps_lng';
  static const _keyLastElevasi = 'last_gps_elevasi';
  static const _keyLastUtcOffset = 'last_gps_utc_offset';
  static const _keyLastZona = 'last_gps_zona';

  Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) return Hive.openBox(_boxName);
    return Hive.box(_boxName);
  }

  /// Null berarti "pakai GPS perangkat" (default).
  Future<String?> getOverrideId() async {
    final box = await _box();
    return box.get(_keyOverrideId) as String?;
  }

  Future<void> setOverrideId(String? id) async {
    final box = await _box();
    if (id == null) {
      await box.delete(_keyOverrideId);
    } else {
      await box.put(_keyOverrideId, id);
    }
  }

  /// Simpan titik GPS yang berhasil didapat, untuk fallback offline-first.
  Future<void> simpanGpsTerakhir({
    required double lat,
    required double lng,
    required int elevasiM,
    required int utcOffset,
    required String zonaWaktu,
  }) async {
    final box = await _box();
    await box.put(_keyLastLat, lat);
    await box.put(_keyLastLng, lng);
    await box.put(_keyLastElevasi, elevasiM);
    await box.put(_keyLastUtcOffset, utcOffset);
    await box.put(_keyLastZona, zonaWaktu);
  }

  /// Null kalau belum pernah ada GPS yang berhasil disimpan sebelumnya.
  Future<({double lat, double lng, int elevasiM, int utcOffset, String zonaWaktu})?> ambilGpsTerakhir() async {
    final box = await _box();
    final lat = box.get(_keyLastLat) as double?;
    final lng = box.get(_keyLastLng) as double?;
    if (lat == null || lng == null) return null;
    return (
      lat: lat,
      lng: lng,
      elevasiM: (box.get(_keyLastElevasi) as int?) ?? 0,
      utcOffset: (box.get(_keyLastUtcOffset) as int?) ?? 7,
      zonaWaktu: (box.get(_keyLastZona) as String?) ?? 'WIB',
    );
  }
}
