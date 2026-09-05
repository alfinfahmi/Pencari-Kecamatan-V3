import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;
import '../models/kecamatan_model.dart';
import 'app_data_service.dart';

/// Hasil mentah satu percobaan geocoding -- dipisah dari KecamatanModel
/// supaya bisa digabung dengan hasil "kecamatan terdekat" dari database
/// sendiri di langkah akhir.
class _HasilGeocoding {
  final String? kelurahan;
  final String? kabupaten;
  final String? provinsi;
  _HasilGeocoding({this.kelurahan, this.kabupaten, this.provinsi});
}

/// Melengkapi titik GPS mentah (lat, lng) dengan nama tempat yang paling
/// lengkap yang bisa didapat.
///
/// PENTING soal nama KECAMATAN: layanan geocoding pihak ketiga (baik
/// native Android/iOS maupun Nominatim) TIDAK punya field yang persis
/// sama dengan "kecamatan" di Indonesia -- field seperti `subLocality`
/// atau `village`/`suburb` seringkali sebenarnya level DESA/KELURAHAN,
/// bukan kecamatan. Kalau field itu langsung dipakai sebagai "kecamatan",
/// hasilnya bisa jadi nama desa, dan kecamatan sungguhannya malah hilang
/// dari tampilan.
///
/// Makanya sekarang alurnya:
/// 1. Coba geocoding (native lalu Nominatim) HANYA untuk dapat nama
///    desa/kelurahan yang lebih rinci (kalau ada) + kabupaten/provinsi.
/// 2. Nama KECAMATAN selalu diambil dari `kecamatanTerdekat()` -- database
///    7.274 kecamatan milik sendiri, yang MEMANG terindeks per kecamatan
///    sehingga lebih bisa diandalkan untuk level ini dibanding menebak
///    dari field geocoding yang ambigu.
/// 3. Kabupaten/provinsi: pakai hasil geocoding kalau berhasil (biasanya
///    akurat), fallback ke kecamatan terdekat kalau geocoding gagal.
///
/// Koordinat (lat, lng) yang dipakai untuk PERHITUNGAN (waktu shalat,
/// kiblat, dst.) SELALU koordinat GPS asli apa adanya -- yang berbeda
/// cuma detail nama tempatnya, bukan akurasi hisabnya.
Future<KecamatanModel> lengkapiInfoLokasiGps({
  required double lat,
  required double lng,
  required int elevasiM,
  required String zonaWaktu,
  required int utcOffset,
}) async {
  _HasilGeocoding? geo;
  if (!kIsWeb) {
    geo = await _cobaGeocodingNative(lat, lng);
  }
  geo ??= await _cobaNominatim(lat, lng);

  final terdekat = AppDataService.instance.kecamatanTerdekat(lat, lng);

  return KecamatanModel(
    id: 'gps_lokasi_saat_ini',
    kecamatan: terdekat?.kecamatan ?? 'Lokasi Anda Saat Ini',
    kelurahan: geo?.kelurahan,
    kabupaten: geo?.kabupaten ?? terdekat?.kabupaten,
    provinsi: geo?.provinsi ?? terdekat?.provinsi ?? '(berdasarkan GPS)',
    lat: lat,
    lng: lng,
    latDms: null,
    lngDms: null,
    elevasiM: elevasiM,
    zonaWaktu: zonaWaktu,
    utcOffset: utcOffset,
  );
}

Future<_HasilGeocoding?> _cobaGeocodingNative(double lat, double lng) async {
  try {
    final placemarks = await geocoding.placemarkFromCoordinates(lat, lng)
        .timeout(const Duration(seconds: 6));
    if (placemarks.isEmpty) return null;
    final p = placemarks.first;

    final kelurahan = (p.subLocality != null && p.subLocality!.isNotEmpty)
        ? p.subLocality!
        : (p.locality != null && p.locality!.isNotEmpty)
            ? p.locality!
            : null;

    return _HasilGeocoding(
      kelurahan: kelurahan,
      kabupaten: (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty)
          ? p.subAdministrativeArea
          : null,
      provinsi: (p.administrativeArea != null && p.administrativeArea!.isNotEmpty)
          ? p.administrativeArea
          : null,
    );
  } catch (_) {
    return null;
  }
}

Future<_HasilGeocoding?> _cobaNominatim(double lat, double lng) async {
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

    final kelurahan = ambil(['village', 'suburb', 'hamlet']);
    final kabupaten = ambil(['county', 'state_district', 'city', 'city_district']);
    final provinsi = ambil(['state']);

    if (kelurahan == null && kabupaten == null && provinsi == null) return null;

    return _HasilGeocoding(kelurahan: kelurahan, kabupaten: kabupaten, provinsi: provinsi);
  } catch (_) {
    return null;
  }
}
