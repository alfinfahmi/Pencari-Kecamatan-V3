import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:home_widget/home_widget.dart';
import '../models/kecamatan_model.dart';
import 'lokasi_cache_service.dart';
import 'hijri_service.dart';
import 'hisab_service.dart';
import 'prayer_settings_service.dart';

/// Mengirim data ke 3 widget Android launcher (Jam, Waktu Shalat,
/// Kalender) -- lihat WIDGET_ANDROID.md untuk penjelasan lengkap.
///
/// PENTING soal keterbatasan: widget Android BUKAN tampilan live seperti
/// di dalam aplikasi. Data di sini hanya diperbarui saat aplikasi
/// dibuka/aktif (dipanggil dari initState Home) -- di antara waktu itu,
/// widget menampilkan data TERAKHIR yang tersimpan (statis), sampai
/// aplikasi dibuka lagi ATAU siklus refresh otomatis Android (minimal
/// ~30 menit, diatur di widget-info XML) memicu tampilan ulang data yang
/// sama. Jam WIB pada widget "Jam" dikecualikan dari batasan ini --
/// dirender pakai `TextClock` bawaan Android (native, selalu real-time
/// tanpa perlu Flutter aktif) supaya minimal WIB tetap akurat.
class HomeWidgetSyncService {
  HomeWidgetSyncService._();
  static final instance = HomeWidgetSyncService._();

  static const _namaProviderJam = 'WidgetJamProvider';
  static const _namaProviderShalat = 'WidgetShalatProvider';
  static const _namaProviderKalender = 'WidgetKalenderProvider';

  static double _sind(double x) => sin(x * pi / 180);
  static double _cosd(double x) => cos(x * pi / 180);
  static double _tand(double x) => tan(x * pi / 180);

  static double _julianDay(DateTime utc) {
    final y = utc.year, m = utc.month;
    final d = utc.day + (utc.hour + utc.minute / 60 + utc.second / 3600) / 24;
    int yy = y, mm = m;
    if (mm <= 2) { yy -= 1; mm += 12; }
    final a = (yy / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (yy + 4716)).floor() + (30.6001 * (mm + 1)).floor() + d + b - 1524.5;
  }

  /// Equation of time (menit) -- rumus sama yang sudah tervalidasi di
  /// seluruh aplikasi (lihat waktu_clock_widget.dart untuk penjelasan).
  static double _equationOfTimeMenit(double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    final l0 = (280.46646 + 36000.76983 * t + 0.0003032 * t * t) % 360;
    final m = (357.52911 + 35999.05029 * t - 0.0001537 * t * t) % 360;
    final eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    final e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t;
    final y = pow(_tand(eps0 / 2), 2).toDouble();
    final eot = y * _sind(2 * l0) -
        2 * e * _sind(m) +
        4 * e * y * _sind(m) * _cosd(2 * l0) -
        0.5 * y * y * _sind(4 * l0) -
        1.25 * e * e * _sind(2 * m);
    return eot * 180 / pi * 4;
  }

  /// Sinkronkan SEMUA data widget sekaligus -- panggil ini dari Home
  /// setiap kali aplikasi dibuka/lokasi berubah (bukan tiap detik).
  Future<void> sinkronkanSemua() async {
    if (kIsWeb) return; // Widget launcher Android/iOS -- tidak relevan di web.
    final lokasi = LokasiCacheService.instance.lokasiCache ?? await LokasiCacheService.instance.ambilLokasi();
    if (lokasi == null || lokasi.utcOffset == null) return;

    await _sinkronJam(lokasi);
    await _sinkronShalat(lokasi);
    await _sinkronKalender(lokasi);
  }

  Future<void> _sinkronJam(KecamatanModel lokasi) async {
    // Kirim OFFSET (menit) dari WIB/WITA/WIT ke Istiwa', BUKAN jam
    // Istiwa' itu sendiri -- offset ini berubah SANGAT lambat (orde
    // menit per hari, akibat equation of time), jadi tetap akurat
    // dipakai native Kotlin untuk hitung "WIB sekarang + offset" kapan
    // pun widget itu di-refresh Android, tanpa perlu Flutter aktif.
    final now = DateTime.now();
    final jd = _julianDay(now.toUtc());
    final eot = _equationOfTimeMenit(jd);
    final offsetMenit = eot + (lokasi.lng / 15 - lokasi.utcOffset!) * 60;

    await HomeWidget.saveWidgetData<String>('jam_istiwa_offset_menit', offsetMenit.toString());
    await HomeWidget.saveWidgetData<String>('jam_lokasi_label', lokasi.kecamatan);
    await HomeWidget.updateWidget(androidName: _namaProviderJam);
  }

  final _prayerSettings = PrayerSettingsService();

  Future<void> _sinkronShalat(KecamatanModel lokasi) async {
    try {
      final ihtiyath = await _prayerSettings.getIhtiyath();
      final sudutIsya = await _prayerSettings.getSudutIsya();
      final sudutSubuh = await _prayerSettings.getSudutSubuh();

      final hasil = HisabService.hitung(
        tanggal: DateTime.now(),
        lat: lokasi.lat, lng: lokasi.lng,
        elevasiM: (lokasi.elevasiM ?? 0).toDouble(),
        utcOffset: lokasi.utcOffset!,
        sudutIsya: sudutIsya, sudutSubuh: sudutSubuh,
        ihtiyathMenit: ihtiyath,
      );
      final now = DateTime.now();
      final berikutnya = hasil.firstWhere(
        (e) => now.isBefore(e.waktuDaerah),
        orElse: () => hasil.last,
      );
      final jamStr = '${berikutnya.waktuDaerah.hour.toString().padLeft(2, '0')}:${berikutnya.waktuDaerah.minute.toString().padLeft(2, '0')}';

      await HomeWidget.saveWidgetData<String>('shalat_nama', berikutnya.nama);
      await HomeWidget.saveWidgetData<String>('shalat_jam', jamStr);
      await HomeWidget.saveWidgetData<String>('shalat_lokasi_label', lokasi.kecamatan);
      await HomeWidget.saveWidgetData<String>('shalat_zona', lokasi.zonaWaktu ?? 'WIB');
      await HomeWidget.updateWidget(androidName: _namaProviderShalat);
    } catch (_) {
      // Diamkan -- widget tetap tampilkan data lama kalau hitung gagal.
    }
  }

  Future<void> _sinkronKalender(KecamatanModel lokasi) async {
    try {
      final hijri = HijriService.instance.konversi(
        DateTime.now(),
        lat: lokasi.lat, lng: lokasi.lng,
        utcOffset: lokasi.utcOffset!, elevasiM: (lokasi.elevasiM ?? 0).toDouble(),
      );
      final pasaran = HijriService.hitungPasaran(DateTime.now());
      final now = DateTime.now();

      await HomeWidget.saveWidgetData<String>('kal_tanggal_masehi', '${now.day}/${now.month}/${now.year}');
      await HomeWidget.saveWidgetData<String>('kal_tanggal_hijri', '${hijri.hari} ${hijri.namaBulanH} ${hijri.tahunH} H');
      await HomeWidget.saveWidgetData<String>('kal_pasaran', pasaran);
      await HomeWidget.updateWidget(androidName: _namaProviderKalender);
    } catch (_) {
      // Diamkan -- widget tetap tampilkan data lama kalau hitung gagal.
    }
  }
}
