import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart' as geocoding;
import '../models/kecamatan_model.dart';
import 'app_data_service.dart';

/// Melengkapi titik GPS mentah (lat, lng) dengan nama tempat yang paling
/// akurat yang bisa didapat, dengan urutan prioritas:
///
/// 1. **Reverse geocoding sungguhan** (lewat layanan geocoding bawaan
///    Android/iOS) -- kalau berhasil, nama kecamatan/kabupaten/provinsi
///    yang didapat SUNGGUHAN sesuai batas administratif, bukan sekadar
///    titik terdekat. Butuh internet & TIDAK berjalan di Flutter Web
///    (keterbatasan resmi package `geocoding`), jadi otomatis dilewati
///    di platform web.
/// 2. **Fallback offline**: kalau langkah 1 gagal (tidak ada internet,
///    timeout, di web, atau layanan geocoding error) -- otomatis jatuh ke
///    "kecamatan terdekat" dari database 7.274 kecamatan sendiri (lihat
///    AppDataService.kecamatanTerdekat). Ini yang menjamin fitur ini TETAP
///    berfungsi 100% offline sebagai fallback, bukan gagal total.
///
/// Koordinat (lat, lng) yang dipakai untuk PERHITUNGAN (waktu shalat,
/// kiblat, dst.) SELALU koordinat GPS asli apa adanya di kedua jalur --
/// yang berbeda cuma LABEL nama tempatnya, bukan akurasi hisabnya.
Future<KecamatanModel> lengkapiInfoLokasiGps({
  required double lat,
  required double lng,
  required int elevasiM,
  required String zonaWaktu,
  required int utcOffset,
}) async {
  if (!kIsWeb) {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 6));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // `locality`/`subLocality` di Indonesia tidak selalu persis sama
        // dengan batas kecamatan resmi (keterbatasan data OS, bukan bug
        // kita) -- tapi ini tetap jauh lebih akurat daripada "titik
        // terdekat" untuk kebanyakan kasus.
        final namaKecamatan = (p.subLocality != null && p.subLocality!.isNotEmpty)
            ? p.subLocality!
            : (p.locality != null && p.locality!.isNotEmpty)
                ? p.locality!
                : null;

        if (namaKecamatan != null) {
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
        }
      }
    } catch (_) {
      // Tidak ada internet / timeout / layanan geocoding error -- lanjut
      // ke fallback offline di bawah, JANGAN lempar error ke pemanggil.
    }
  }

  final terdekat = AppDataService.instance.kecamatanTerdekat(lat, lng);
  return KecamatanModel(
    id: 'gps_lokasi_saat_ini',
    kecamatan: terdekat != null ? 'Sekitar ${terdekat.kecamatan}' : 'Lokasi Anda Saat Ini',
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
