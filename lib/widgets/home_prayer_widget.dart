import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../models/kecamatan_model.dart';
import '../services/app_data_service.dart';
import '../services/hisab_service.dart';
import '../services/home_location_service.dart';
import '../services/adzan_notification_service.dart';
import '../services/prayer_settings_service.dart';
import '../theme/app_theme.dart';
import '../screens/detail_screen.dart';

enum _StatusWidget { memuat, butuhIzin, gpsMati, error, siap }

/// Widget ringkas di Home: menampilkan waktu shalat yang SEDANG berjalan &
/// BERIKUTNYA saja, berdasarkan lokasi GPS perangkat secara default. Tap
/// untuk membuka jadwal satu hari penuh. Pengguna bisa mengganti lokasi
/// acuan lewat tombol "Ganti Lokasi".
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
  bool _pakaiGps = true;

  @override
  void initState() {
    super.initState();
    _muat();
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

      final lokasiGps = KecamatanModel(
        id: 'gps_lokasi_saat_ini',
        kecamatan: 'Lokasi Anda Saat Ini',
        kabupaten: null,
        provinsi: '(berdasarkan GPS)',
        lat: pos.latitude,
        lng: pos.longitude,
        latDms: null,
        lngDms: null,
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

    if (mounted) {
      setState(() {
        _lokasi = lokasi;
        _waktuShalat = hasil;
        _status = _StatusWidget.siap;
      });
    }

    // Perbarui jadwal notifikasi adzan (no-op kalau fitur belum diaktifkan
    // pengguna -- lihat AdzanNotificationService.jadwalkanUntukHariIni).
    await AdzanNotificationService.instance.jadwalkanUntukHariIni(hasil);
  }

  ({WaktuShalatEntry sekarang, WaktuShalatEntry? berikutnya}) _cariSekarangDanBerikutnya(
    List<WaktuShalatEntry> entries,
  ) {
    final now = DateTime.now();
    int aktifIndex = 0;
    for (int i = 0; i < entries.length; i++) {
      if (!now.isBefore(entries[i].waktuDaerah)) aktifIndex = i;
    }
    final berikutnya = aktifIndex + 1 < entries.length ? entries[aktifIndex + 1] : null;
    return (sekarang: entries[aktifIndex], berikutnya: berikutnya);
  }

  Future<void> _gantiLokasi() async {
    final terpilih = await showModalBottomSheet<KecamatanModel>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PilihLokasiSheet(),
    );
    if (terpilih != null) {
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
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.emerald,
        borderRadius: BorderRadius.circular(18),
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
        final hasil = _cariSekarangDanBerikutnya(_waktuShalat!);
        String fmt(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

        return InkWell(
          onTap: _bukaJadwalLengkap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_pakaiGps ? Icons.my_location_rounded : Icons.location_on_rounded,
                      size: 13, color: Colors.white70),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _lokasi!.kecamatan,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd(color: Colors.white70).copyWith(fontSize: 11.5),
                    ),
                  ),
                  InkWell(
                    onTap: _gantiLokasi,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text('Ganti Lokasi', style: TextStyle(color: Colors.white, fontSize: 11, decoration: TextDecoration.underline)),
                    ),
                  ),
                  if (!_pakaiGps) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: _kembaliKeGps,
                      child: const Icon(Icons.gps_fixed_rounded, size: 15, color: Colors.white70),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SEDANG BERLANGSUNG', style: AppTypography.labelCaps(color: AppColors.goldLight).copyWith(fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(hasil.sekarang.nama,
                            style: AppTypography.headlineMd(color: Colors.white).copyWith(fontSize: 20)),
                        Text(fmt(hasil.sekarang.waktuDaerah),
                            style: AppTypography.dataDisplay(color: Colors.white, fontSize: 15)),
                      ],
                    ),
                  ),
                  if (hasil.berikutnya != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('BERIKUTNYA', style: AppTypography.labelCaps(color: Colors.white54).copyWith(fontSize: 9.5)),
                        const SizedBox(height: 2),
                        Text(hasil.berikutnya!.nama,
                            style: AppTypography.bodyLg(color: Colors.white).copyWith(fontWeight: FontWeight.w600)),
                        Text(fmt(hasil.berikutnya!.waktuDaerah),
                            style: AppTypography.dataDisplay(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Lihat jadwal satu hari penuh', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10.5)),
                  const SizedBox(width: 3),
                  Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white.withOpacity(0.6)),
                ],
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

/// Bottom sheet sederhana untuk memilih lokasi override secara manual.
class _PilihLokasiSheet extends StatefulWidget {
  @override
  State<_PilihLokasiSheet> createState() => _PilihLokasiSheetState();
}

class _PilihLokasiSheetState extends State<_PilihLokasiSheet> {
  final _controller = TextEditingController();
  List<KecamatanModel> _hasil = [];

  Future<void> _cari(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _hasil = []);
      return;
    }
    final hasil = await AppDataService.instance.search(query, limit: 20);
    setState(() => _hasil = hasil);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih Lokasi untuk Widget Home', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _cari,
                  decoration: const InputDecoration(hintText: 'Cari kecamatan...', prefixIcon: Icon(Icons.search_rounded)),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _hasil.length,
                    itemBuilder: (context, i) {
                      final item = _hasil[i];
                      return ListTile(
                        title: Text(item.kecamatan),
                        subtitle: Text('${item.kabupaten ?? '-'}, ${item.provinsi}'),
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
