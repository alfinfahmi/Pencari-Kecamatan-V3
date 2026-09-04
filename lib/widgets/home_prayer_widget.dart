import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../models/kecamatan_model.dart';
import '../services/app_data_service.dart';
import '../services/hisab_service.dart';
import '../services/hijri_service.dart';
import '../services/home_location_service.dart';
import '../services/reverse_geocode_helper.dart';
import '../services/adzan_notification_service.dart';
import '../services/prayer_settings_service.dart';
import '../theme/app_theme.dart';
import '../screens/detail_screen.dart';
import 'location_picker_sheet.dart';

enum _StatusWidget { memuat, butuhIzin, gpsMati, error, siap }

/// Widget ringkas di Home: menampilkan waktu shalat BERIKUTNYA dengan
/// hitung mundur langsung (live countdown), berdasarkan lokasi GPS
/// perangkat secara default. Tap untuk membuka jadwal satu hari penuh.
/// Pengguna bisa mengganti lokasi acuan lewat tombol "Ganti Lokasi".
class HomePrayerWidget extends StatefulWidget {
  const HomePrayerWidget({super.key});

  @override
  State<HomePrayerWidget> createState() => _HomePrayerWidgetState();
}

class _HomePrayerWidgetState extends State<HomePrayerWidget> {
  final _homeLocationService = HomeLocationService();
  final _prayerSettings = PrayerSettingsService();

  _StatusWidget _status = _StatusWidget.memuat;
  KecamatanModel? _lokasi;
  List<WaktuShalatEntry>? _waktuShalat;
  WaktuShalatEntry? _imsakBesok;
  bool _pakaiGps = true;
  Timer? _timerHitungMundur;

  @override
  void initState() {
    super.initState();
    _muat();
    // Perbarui tampilan tiap detik supaya hitung mundur berjalan live,
    // tanpa perlu hitung ulang waktu shalat dari nol tiap kali (cuma
    // rebuild angka detiknya).
    _timerHitungMundur = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _status == _StatusWidget.siap) setState(() {});
    });
  }

  @override
  void dispose() {
    _timerHitungMundur?.cancel();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _status = _StatusWidget.memuat);

    final overrideId = await _homeLocationService.getOverrideId();
    if (overrideId != null) {
      final lokasi = AppDataService.instance.findById(overrideId);
      if (lokasi != null) {
        _pakaiGps = false;
        await _hitungUntuk(lokasi);
        return;
      }
    }

    _pakaiGps = true;
    await _muatDariGps();
  }

  Future<void> _muatDariGps() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        final terpakai = await _pakaiFallbackOfflineJikaAda();
        if (!terpakai && mounted) setState(() => _status = _StatusWidget.butuhIzin);
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        final terpakai = await _pakaiFallbackOfflineJikaAda();
        if (!terpakai && mounted) setState(() => _status = _StatusWidget.gpsMati);
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      final utcOffsetJam = DateTime.now().timeZoneOffset.inHours;
      final namaZona = switch (utcOffsetJam) {
        7 => 'WIB',
        8 => 'WITA',
        9 => 'WIT',
        _ => 'UTC${utcOffsetJam >= 0 ? '+' : ''}$utcOffsetJam',
      };
      final elevasiBulat = pos.altitude > 0 ? pos.altitude.round() : 0;

      // Coba reverse geocoding sungguhan dulu (Android/iOS + internet),
      // otomatis jatuh ke "kecamatan terdekat" offline kalau gagal/di web
      // -- lihat reverse_geocode_helper.dart.
      final lokasiGps = await lengkapiInfoLokasiGps(
        lat: pos.latitude,
        lng: pos.longitude,
        elevasiM: elevasiBulat,
        zonaWaktu: namaZona,
        utcOffset: utcOffsetJam,
      );

      // Simpan sebagai fallback offline-first -- kalau lain kali GPS gagal
      // (mis. di dalam gedung/sinyal lemah), widget tetap bisa tampil
      // memakai titik terakhir yang valid, bukan langsung buntu.
      await _homeLocationService.simpanGpsTerakhir(
        lat: pos.latitude,
        lng: pos.longitude,
        elevasiM: elevasiBulat,
        utcOffset: utcOffsetJam,
        zonaWaktu: namaZona,
      );

      await _hitungUntuk(lokasiGps);
    } catch (e) {
      final terpakai = await _pakaiFallbackOfflineJikaAda();
      if (!terpakai && mounted) setState(() => _status = _StatusWidget.error);
    }
  }

  /// Coba pakai titik GPS terakhir yang tersimpan (kalau ada) saat GPS
  /// langsung gagal karena alasan apa pun. Mengembalikan true jika berhasil
  /// dipakai (sehingga pemanggil tidak perlu menampilkan pesan error lagi).
  Future<bool> _pakaiFallbackOfflineJikaAda() async {
    final terakhir = await _homeLocationService.ambilGpsTerakhir();
    if (terakhir == null) return false;

    final lokasiFallback = KecamatanModel(
      id: 'gps_lokasi_terakhir',
      kecamatan: 'Lokasi Terakhir (offline)',
      kabupaten: null,
      provinsi: '(GPS tidak tersedia saat ini)',
      lat: terakhir.lat,
      lng: terakhir.lng,
      latDms: null,
      lngDms: null,
      elevasiM: terakhir.elevasiM,
      zonaWaktu: terakhir.zonaWaktu,
      utcOffset: terakhir.utcOffset,
    );
    await _hitungUntuk(lokasiFallback);
    return true;
  }

  Future<void> _hitungUntuk(KecamatanModel lokasi) async {
    if (lokasi.utcOffset == null) {
      if (mounted) setState(() => _status = _StatusWidget.error);
      return;
    }
    final ihtiyath = await _prayerSettings.getIhtiyath();
    final sudutIsya = await _prayerSettings.getSudutIsya();
    final sudutSubuh = await _prayerSettings.getSudutSubuh();

    final hasil = HisabService.hitung(
      tanggal: DateTime.now(),
      lat: lokasi.lat,
      lng: lokasi.lng,
      elevasiM: (lokasi.elevasiM ?? 0).toDouble(),
      utcOffset: lokasi.utcOffset!,
      sudutIsya: sudutIsya,
      sudutSubuh: sudutSubuh,
      ihtiyathMenit: ihtiyath,
    );

    // Siapkan Imsak besok di muka (untuk kasus semua waktu hari ini sudah
    // lewat / sudah lewat Isya) -- supaya tidak perlu hitung ulang async
    // saat widget sedang render/countdown per detik.
    final besok = HisabService.hitung(
      tanggal: DateTime.now().add(const Duration(days: 1)),
      lat: lokasi.lat,
      lng: lokasi.lng,
      elevasiM: (lokasi.elevasiM ?? 0).toDouble(),
      utcOffset: lokasi.utcOffset!,
      sudutIsya: sudutIsya,
      sudutSubuh: sudutSubuh,
      ihtiyathMenit: ihtiyath,
    );

    if (mounted) {
      setState(() {
        _lokasi = lokasi;
        _waktuShalat = hasil;
        _imsakBesok = besok.first;
        _status = _StatusWidget.siap;
      });
    }

    // Perbarui jadwal notifikasi adzan (no-op kalau fitur belum diaktifkan
    // pengguna -- lihat AdzanNotificationService.jadwalkanUntukHariIni).
    await AdzanNotificationService.instance.jadwalkanUntukHariIni(hasil);
  }

  /// Cari waktu shalat BERIKUTNYA (belum lewat) dari daftar hari ini; kalau
  /// semua sudah lewat (sudah lewat Isya), lompat ke Imsak besok --
  /// makanya `_hitungUntuk` juga menyiapkan `_imsakBesok` di muka supaya
  /// tidak perlu hitung ulang async saat widget sedang render/countdown.
  WaktuShalatEntry _cariBerikutnya(List<WaktuShalatEntry> entries) {
    final now = DateTime.now();
    for (final e in entries) {
      if (now.isBefore(e.waktuDaerah)) return e;
    }
    return _imsakBesok ?? entries.last;
  }

  String _formatDurasi(Duration d) {
    if (d.isNegative) return '00:00:00';
    final j = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$j:$m:$s';
  }

  static const _namaHari = {1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis', 5: 'Jumat', 6: 'Sabtu', 7: 'Ahad'};
  static const _namaBulanMasehi = {
    1: 'Januari', 2: 'Februari', 3: 'Maret', 4: 'April', 5: 'Mei', 6: 'Juni',
    7: 'Juli', 8: 'Agustus', 9: 'September', 10: 'Oktober', 11: 'November', 12: 'Desember',
  };

  String _formatTanggalGabungan(DateTime tanggal) {
    final labelMasehi = '${tanggal.day} ${_namaBulanMasehi[tanggal.month]} ${tanggal.year}';
    final lokasi = _lokasi;
    if (lokasi?.utcOffset == null) return labelMasehi;
    final hijri = HijriService.instance.konversi(tanggal, lat: lokasi!.lat, lng: lokasi.lng, utcOffset: lokasi.utcOffset!);
    return '$labelMasehi / ${hijri.hari} ${hijri.namaBulanH} ${hijri.tahunH}';
  }

  /// Sentinel object untuk membedakan "pengguna pilih GPS" dari "pengguna
  /// pilih suatu KecamatanModel" dari sheet yang sama.
  Future<void> _gantiLokasi() async {
    final terpilih = await LocationPickerSheet.show(context, judul: 'Pilih Lokasi untuk Widget Home');
    if (terpilih == kPilihGpsSentinel) {
      await _kembaliKeGps();
    } else if (terpilih is KecamatanModel) {
      await _homeLocationService.setOverrideId(terpilih.id);
      _pakaiGps = false;
      await _hitungUntuk(terpilih);
    }
  }

  Future<void> _kembaliKeGps() async {
    await _homeLocationService.setOverrideId(null);
    await _muatDariGps();
  }

  void _bukaJadwalLengkap() {
    if (_lokasi == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(data: _lokasi!, initialSection: DetailSection.waktuShalat)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.emerald,
        borderRadius: BorderRadius.circular(14),
      ),
      child: _buildIsi(isDark),
    );
  }

  Widget _buildIsi(bool isDark) {
    switch (_status) {
      case _StatusWidget.memuat:
        return const SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
        );

      case _StatusWidget.butuhIzin:
        return _pesanAksi(
          icon: Icons.location_off_rounded,
          pesan: 'Izinkan akses lokasi untuk melihat waktu shalat sesuai posisi Anda.',
          labelTombol: 'Coba Lagi',
          onTombol: _muatDariGps,
        );

      case _StatusWidget.gpsMati:
        return _pesanAksi(
          icon: Icons.gps_off_rounded,
          pesan: 'Aktifkan layanan lokasi (GPS) di perangkat Anda.',
          labelTombol: 'Coba Lagi',
          onTombol: _muatDariGps,
        );

      case _StatusWidget.error:
        return _pesanAksi(
          icon: Icons.error_outline_rounded,
          pesan: 'Gagal memuat waktu shalat.',
          labelTombol: 'Coba Lagi',
          onTombol: _muat,
        );

      case _StatusWidget.siap:
        if (_waktuShalat == null || _lokasi == null) return const SizedBox.shrink();
        final berikutnya = _cariBerikutnya(_waktuShalat!);
        final sisaWaktu = berikutnya.waktuDaerah.difference(DateTime.now());
        String fmt(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

        return InkWell(
          onTap: _bukaJadwalLengkap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(_pakaiGps ? Icons.my_location_rounded : Icons.location_on_rounded,
                      size: 13, color: Colors.white70),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [_lokasi!.kecamatan, _lokasi!.kabupaten].where((e) => e != null).join(', '),
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd(color: Colors.white70).copyWith(fontSize: 12),
                    ),
                  ),
                  InkWell(
                    onTap: _gantiLokasi,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text('(Ganti)', style: TextStyle(color: AppColors.goldLight, fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${berikutnya.nama} ${fmt(berikutnya.waktuDaerah)} ',
                      style: AppTypography.headlineLg(color: Colors.white).copyWith(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: _lokasi!.zonaWaktu ?? '',
                      style: AppTypography.bodyMd(color: Colors.white70).copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '- ${_formatDurasi(sisaWaktu)}',
                style: AppTypography.dataDisplay(color: Colors.white60, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTanggalGabungan(DateTime.now()),
                style: AppTypography.bodyMd(color: Colors.white70).copyWith(fontSize: 12.5),
              ),
            ],
          ),
        );
    }
  }

  Widget _pesanAksi({
    required IconData icon,
    required String pesan,
    required String labelTombol,
    required VoidCallback onTombol,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 28),
        const SizedBox(height: 8),
        Text(pesan, textAlign: TextAlign.center, style: AppTypography.bodyMd(color: Colors.white)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: onTombol,
              style: TextButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.15), foregroundColor: Colors.white),
              child: Text(labelTombol),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _gantiLokasi,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Pilih Lokasi Manual'),
            ),
          ],
        ),
      ],
    );
  }
}

