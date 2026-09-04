import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;
import '../models/kecamatan_model.dart';
import 'app_data_service.dart';

/// Melengkapi titik GPS mentah (lat, lng) dengan nama tempat yang paling
/// akurat yang bisa didapat, dengan urutan prioritas 3 lapis:
///
/// 1. **Reverse geocoding native** (layanan geocoding bawaan Android/iOS,
///    lewat package `geocoding`) -- paling akurat kalau berhasil, tapi
///    TIDAK berjalan di Flutter Web (keterbatasan resmi package ini),
///    jadi otomatis dilewati di platform web.
/// 2. **Nominatim (OpenStreetMap)**, lewat HTTP biasa -- BISA jalan di
///    SEMUA platform termasuk Web (karena cuma request HTTP, bukan plugin
///    native). Dicoba kalau langkah 1 dilewati/gagal. Gratis, tanpa API
///    key, tapi kualitas data tergantung kelengkapan pemetaan OpenStreetMap
///    di lokasi tersebut (umumnya baik untuk kota besar, bisa kurang
///    lengkap di daerah terpencil).
/// 3. **Fallback offline**: kalau kedua langkah di atas gagal (tidak ada
///    internet, timeout, data OSM kosong di lokasi itu) -- jatuh ke
///    "kecamatan terdekat" dari database 7.274 kecamatan sendiri. Ini
///    yang menjamin fitur ini TETAP berfungsi 100% offline sebagai
///    fallback terakhir, bukan gagal total.
///
/// Koordinat (lat, lng) yang dipakai untuk PERHITUNGAN (waktu shalat,
/// kiblat, dst.) SELALU koordinat GPS asli apa adanya di ketiga jalur --
/// yang berbeda cuma LABEL nama tempatnya, bukan akurasi hisabnya.
Future<KecamatanModel> lengkapiInfoLokasiGps({
  required double lat,
  required double lng,
  required int elevasiM,
  required String zonaWaktu,
  required int utcOffset,
}) async {
  if (!kIsWeb) {
    final hasil = await _cobaGeocodingNative(
      lat: lat, lng: lng, elevasiM: elevasiM, zonaWaktu: zonaWaktu, utcOffset: utcOffset,
    );
    if (hasil != null) return hasil;
  }

  final hasilNominatim = await _cobaNominatim(
    lat: lat, lng: lng, elevasiM: elevasiM, zonaWaktu: zonaWaktu, utcOffset: utcOffset,
  );
  if (hasilNominatim != null) return hasilNominatim;

  final terdekat = AppDataService.instance.kecamatanTerdekat(lat, lng);
  return KecamatanModel(
    id: 'gps_lokasi_saat_ini',
    kecamatan: terdekat?.kecamatan ?? 'Lokasi Anda Saat Ini',
    kabupaten: terdekat?.kabupaten,
    provinsi: terdekat?.provinsi ?? '(berdasarkan GPS)',
    lat: lat,
    lng: lng,
    latDms: null,
    lngDms: null,
    elevasiM: elevasiM,
    zonaWaktu: zonaWaktu,
    utcOffset: utcOffset,
  );
}

Future<KecamatanModel?> _cobaGeocodingNative({
  required double lat,
  required double lng,
  required int elevasiM,
  required String zonaWaktu,
  required int utcOffset,
}) async {
  try {
    final placemarks = await geocoding.placemarkFromCoordinates(lat, lng)
        .timeout(const Duration(seconds: 6));
    if (placemarks.isEmpty) return null;
    final p = placemarks.first;

    final namaKecamatan = (p.subLocality != null && p.subLocality!.isNotEmpty)
        ? p.subLocality!
        : (p.locality != null && p.locality!.isNotEmpty)
            ? p.locality!
            : null;
    if (namaKecamatan == null) return null;

    return KecamatanModel(
      id: 'gps_lokasi_saat_ini',
      kecamatan: namaKecamatan,
      kabupaten: (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty)
          ? p.subAdministrativeArea
          : null,
      provinsi: (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
          ? p.administrativeArea!
          : 'Indonesia',
      lat: lat,
      lng: lng,
      latDms: null,
      lngDms: null,
      elevasiM: elevasiM,
      zonaWaktu: zonaWaktu,
      utcOffset: utcOffset,
    );
  } catch (_) {
    return null;
  }
}

Future<KecamatanModel?> _cobaNominatim({
  required double lat,
  required double lng,
  required int elevasiM,
  required String zonaWaktu,
  required int utcOffset,
}) async {
  try {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?format=jsonv2&lat=$lat&lon=$lng&addressdetails=1&accept-language=id',
    );
    final response = await http.get(
      url,
      headers: {'User-Agent': 'AplikasiFalak-LFLirboyo/1.0'},
    ).timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as Map<String, dynamic>;
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) return null;

    String? ambil(List<String> keys) {
      for (final k in keys) {
        final v = address[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    final kecamatan = ambil(['city_district', 'suburb', 'village', 'town', 'municipality']);
    if (kecamatan == null) return null;

    final kabupaten = ambil(['county', 'state_district', 'city']);
    final provinsi = ambil(['state']);

    return KecamatanModel(
      id: 'gps_lokasi_saat_ini',
      kecamatan: kecamatan,
      kabupaten: kabupaten,
      provinsi: provinsi ?? 'Indonesia',
      lat: lat,
      lng: lng,
      latDms: null,
      lngDms: null,
      elevasiM: elevasiM,
      zonaWaktu: zonaWaktu,
      utcOffset: utcOffset,
    );
  } catch (_) {
    return null;
  }
}
