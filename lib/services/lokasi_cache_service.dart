import 'package:geolocator/geolocator.dart';
import '../models/kecamatan_model.dart';
import 'reverse_geocode_helper.dart';

/// Cache lokasi GPS bersama di seluruh aplikasi -- sebelum ada ini, HAMPIR
/// SETIAP layar (Kalkulator, Hisab Awal Bulan, Kalender, dll.) memanggil
/// GPS-nya SENDIRI-SENDIRI setiap kali dibuka, menyebabkan jeda berputar
/// berulang tiap kali pindah antar menu meski lokasi pengguna jelas belum
/// berubah dalam hitungan detik/menit.
///
/// Dengan cache ini: begitu SATU layar berhasil mengambil lokasi, layar
/// lain yang dibuka dalam beberapa menit berikutnya langsung pakai hasil
/// yang sama TANPA memanggil GPS lagi -- jauh lebih responsif.
class LokasiCacheService {
  LokasiCacheService._();
  static final instance = LokasiCacheService._();

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

  /// Ambil lokasi -- pakai cache kalau masih valid (instan, tanpa panggil
  /// GPS), atau ambil fresh dari GPS kalau cache basi/kosong atau
  /// [paksaRefresh] diminta eksplisit (mis. tombol "Ganti" -> GPS).
  Future<KecamatanModel?> ambilLokasi({bool paksaRefresh = false}) async {
    if (!paksaRefresh && _cacheMasihValid) return _lokasiTersimpan;

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      final pos = await Geolocator.getCurrentPosition();
      final utcOffsetJam = DateTime.now().timeZoneOffset.inHours;
      final namaZona = switch (utcOffsetJam) {
        7 => 'WIB', 8 => 'WITA', 9 => 'WIT',
        _ => 'UTC${utcOffsetJam >= 0 ? '+' : ''}$utcOffsetJam',
      };
      final lokasi = await lengkapiInfoLokasiGps(
        lat: pos.latitude, lng: pos.longitude,
        elevasiM: pos.altitude > 0 ? pos.altitude.round() : 0,
        zonaWaktu: namaZona, utcOffset: utcOffsetJam,
      );
      simpan(lokasi);
      return lokasi;
    } catch (_) {
      return null;
    }
  }
}
