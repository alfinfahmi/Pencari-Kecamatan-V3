import 'package:geolocator/geolocator.dart';
import '../models/kecamatan_model.dart';
import 'reverse_geocode_helper.dart';
import 'home_location_service.dart';

/// Cache lokasi GPS bersama di seluruh aplikasi -- sebelum ada ini, HAMPIR
/// SETIAP layar (Kalkulator, Hisab Awal Bulan, Kalender, dll.) memanggil
/// GPS-nya SENDIRI-SENDIRI setiap kali dibuka, menyebabkan jeda berputar
/// berulang tiap kali pindah antar menu meski lokasi pengguna jelas belum
/// berubah dalam hitungan detik/menit.
///
/// Dengan cache ini: begitu SATU layar berhasil mengambil lokasi, layar
/// lain yang dibuka dalam beberapa menit berikutnya langsung pakai hasil
/// yang sama TANPA memanggil GPS lagi -- jauh lebih responsif.
///
/// PENTING: juga memakai [HomeLocationService] (fallback offline-first
/// yang sudah ada & tervalidasi, dipakai HomePrayerWidget) sebagai
/// jaring pengaman kalau GPS gagal (izin ditolak, GPS mati, di dalam
/// gedung, dll.) -- tanpa ini, widget yang memakai cache ini (jam
/// Istiwa', kalender mini) akan kosong sama sekali saat GPS gagal,
/// padahal HomePrayerWidget di layar yang sama berhasil tampil
/// memakai titik terakhir yang tersimpan.
class LokasiCacheService {
  LokasiCacheService._();
  static final instance = LokasiCacheService._();

  final _homeLocationService = HomeLocationService();

  KecamatanModel? _lokasiTersimpan;
  DateTime? _waktuSimpan;

  static const _masaBerlaku = Duration(minutes: 5);

  bool get _cacheMasihValid =>
      _lokasiTersimpan != null &&
      _waktuSimpan != null &&
      DateTime.now().difference(_waktuSimpan!) < _masaBerlaku;

  /// Lokasi dari cache kalau masih valid, atau null kalau belum ada/basi
  /// -- pakai ini untuk tampilan AWAL (langsung, tanpa nunggu) sebelum
  /// [ambilLokasi] selesai, supaya layar tidak kosong/muter dulu.
  KecamatanModel? get lokasiCache => _cacheMasihValid ? _lokasiTersimpan : null;

  /// Simpan lokasi ke cache -- dipanggil otomatis oleh [ambilLokasi], atau
  /// panggil manual kalau pengguna memilih lokasi sendiri (bukan dari GPS)
  /// supaya layar lain ikut memakai pilihan yang sama.
  void simpan(KecamatanModel lokasi) {
    _lokasiTersimpan = lokasi;
    _waktuSimpan = DateTime.now();
  }

  KecamatanModel _keModel(({double lat, double lng, int elevasiM, int utcOffset, String zonaWaktu}) t) {
    return KecamatanModel(
      id: 'gps_lokasi_terakhir',
      kecamatan: 'Lokasi Terakhir (offline)',
      kabupaten: null,
      provinsi: '(GPS tidak tersedia saat ini)',
      lat: t.lat, lng: t.lng,
      latDms: null, lngDms: null,
      elevasiM: t.elevasiM, zonaWaktu: t.zonaWaktu, utcOffset: t.utcOffset,
    );
  }

  /// Coba pakai titik GPS terakhir yang tersimpan persisten (kalau ada) --
  /// dipakai saat GPS langsung gagal karena alasan apa pun.
  Future<KecamatanModel?> _fallbackOfflineJikaAda() async {
    final terakhir = await _homeLocationService.ambilGpsTerakhir();
    if (terakhir == null) return null;
    final lokasi = _keModel(terakhir);
    simpan(lokasi); // cache juga hasil fallback, supaya konsisten di seluruh layar
    return lokasi;
  }

  /// Ambil lokasi -- pakai cache kalau masih valid (instan, tanpa panggil
  /// GPS), atau ambil fresh dari GPS kalau cache basi/kosong atau
  /// [paksaRefresh] diminta eksplisit (mis. tombol "Ganti" -> GPS). Kalau
  /// GPS gagal karena alasan apa pun, jatuh ke titik terakhir yang
  /// tersimpan persisten (sama seperti yang dipakai HomePrayerWidget).
  Future<KecamatanModel?> ambilLokasi({bool paksaRefresh = false}) async {
    if (!paksaRefresh && _cacheMasihValid) return _lokasiTersimpan;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return _fallbackOfflineJikaAda();
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _fallbackOfflineJikaAda();
      }

      final pos = await Geolocator.getCurrentPosition();
      final utcOffsetJam = DateTime.now().timeZoneOffset.inHours;
      final namaZona = switch (utcOffsetJam) {
        7 => 'WIB', 8 => 'WITA', 9 => 'WIT',
        _ => 'UTC${utcOffsetJam >= 0 ? '+' : ''}$utcOffsetJam',
      };
      final elevasiBulat = pos.altitude > 0 ? pos.altitude.round() : 0;
      final lokasi = await lengkapiInfoLokasiGps(
        lat: pos.latitude, lng: pos.longitude,
        elevasiM: elevasiBulat,
        zonaWaktu: namaZona, utcOffset: utcOffsetJam,
      );

      // Simpan sebagai fallback offline-first untuk lain kali (sama
      // seperti yang dilakukan HomePrayerWidget).
      await _homeLocationService.simpanGpsTerakhir(
        lat: pos.latitude, lng: pos.longitude,
        elevasiM: elevasiBulat, utcOffset: utcOffsetJam, zonaWaktu: namaZona,
      );

      simpan(lokasi);
      return lokasi;
    } catch (_) {
      return _fallbackOfflineJikaAda();
    }
  }
}
