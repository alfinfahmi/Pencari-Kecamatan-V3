import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../main.dart' show themeModeNotifier;
import '../services/reverse_geocode_helper.dart';
import '../services/supabase_service.dart';
import '../services/ota_update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/home_prayer_widget.dart';
import '../widgets/waktu_clock_widget.dart';
import '../widgets/mini_calendar_widget.dart';
import '../widgets/kompas_kiblat_card_widget.dart';
import '../widgets/watermark_footer.dart';
import 'detail_screen.dart';
import 'geografis_pencarian_screen.dart';
import 'moderation_panel_screen.dart';
import 'adzan_settings_screen.dart';
import 'tabel_ijtimak_screen.dart';
import 'hijri_calendar_screen.dart';
import 'hisab_awal_bulan_screen.dart';
import 'kalkulator_screen.dart';
import 'kamera_rukyat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Dihitung SEKALI saat layar ini dibuka (bukan tiap kali build()
  /// dipanggil ulang) -- kalau dipanggil langsung di dalam build(),
  /// setiap rebuild (ganti tema, kembali dari layar lain, dll.) akan
  /// memicu query baru ke Supabase, terasa seperti "refresh berulang".
  late final Future<String> _roleFuture = SupabaseService.instance.getRole();

  bool _memuatMenuLokasi = false;
  UpdateStatus? _statusOta;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget SENGAJA -- jangan di-await, supaya Home tidak
    // menunggu jaringan Shorebird untuk tampil (lihat peringatan resmi
    // paket ini soal jangan gating startup pada checkForUpdate()).
    OtaUpdateService.cekPembaruan().then((status) {
      if (mounted && status != null) setState(() => _statusOta = status);
    });
  }

  Future<void> _terapkanOta() async {
    final berhasil = await OtaUpdateService.terapkanPembaruan();
    if (!mounted) return;
    if (berhasil) {
      setState(() => _statusOta = UpdateStatus.restartRequired);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menerapkan pembaruan -- coba lagi nanti')),
      );
    }
  }

  /// Kartu kecil pemberitahuan OTA -- null (tidak tampil apa-apa) kalau
  /// aplikasi sudah versi terbaru atau OTA belum ter-setup di build ini.
  Widget? _bannerOta(bool isDark) {
    if (_statusOta == UpdateStatus.outdated) {
      return _kartuBannerOta(
        isDark: isDark,
        pesan: 'Pembaruan aplikasi tersedia',
        teksTombol: 'Terapkan',
        onTombol: _terapkanOta,
      );
    }
    if (_statusOta == UpdateStatus.restartRequired) {
      return _kartuBannerOta(
        isDark: isDark,
        pesan: 'Pembaruan sudah diunduh -- mulai ulang aplikasi untuk mengaktifkan',
        teksTombol: null,
        onTombol: null,
      );
    }
    return null;
  }

  Widget _kartuBannerOta({required bool isDark, required String pesan, String? teksTombol, VoidCallback? onTombol}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_rounded, size: 18, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(child: Text(pesan, style: const TextStyle(fontSize: 12.5))),
          if (teksTombol != null)
            TextButton(onPressed: onTombol, child: Text(teksTombol, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  /// Ambil lokasi GPS (dengan fallback nama tempat berlapis, lihat
  /// reverse_geocode_helper.dart), lalu buka DetailScreen langsung ke
  /// bagian yang diminta. Dipakai tombol "Waktu Shalat" di menu cepat Home.
  Future<void> _bukaDetailDenganGps(DetailSection section) async {
    if (_memuatMenuLokasi) return;
    setState(() => _memuatMenuLokasi = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak -- tidak bisa mengambil GPS')),
          );
        }
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aktifkan layanan lokasi (GPS) di perangkat Anda')),
          );
        }
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
      final lokasi = await lengkapiInfoLokasiGps(
        lat: pos.latitude,
        lng: pos.longitude,
        elevasiM: pos.altitude > 0 ? pos.altitude.round() : 0,
        zonaWaktu: namaZona,
        utcOffset: utcOffsetJam,
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(data: lokasi, initialSection: section)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil lokasi GPS: $e')));
      }
    } finally {
      if (mounted) setState(() => _memuatMenuLokasi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerOta = _bannerOta(isDark);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.explore_rounded, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('Aplikasi Falak', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          FutureBuilder<String>(
            future: _roleFuture,
            builder: (context, snapshot) {
              final role = snapshot.data ?? 'umum';
              if (role != 'kontributor' && role != 'admin') return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.fact_check_rounded),
                tooltip: 'Panel Moderasi',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ModerationPanelScreen()),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifikasi Adzan',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdzanSettingsScreen()),
              );
            },
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) {
              final darkNow = mode == ThemeMode.dark ||
                  (mode == ThemeMode.system &&
                      MediaQuery.platformBrightnessOf(context) == Brightness.dark);
              return IconButton(
                icon: Icon(darkNow ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                tooltip: 'Ganti tema',
                onPressed: () {
                  themeModeNotifier.value = darkNow ? ThemeMode.light : ThemeMode.dark;
                },
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          // Batasi lebar maksimum -- tanpa ini, di layar lebar (desktop)
          // jam/kalender/menu melebar penuh ke seluruh layar, sulit dibaca.
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const WaktuClockWidget(),
                if (bannerOta != null) bannerOta,
                const HomePrayerWidget(),
                const MiniCalendarWidget(),
                const KompasKiblatCardWidget(),
                _buildMenuCepat(isDark),
                const SizedBox(height: 12),
              ],
            ),
          ),
          // Watermark SENGAJA di luar area scroll -- tetap terlihat
          // permanen di bawah layar, tidak ikut ter-scroll bersama konten.
          const WatermarkFooter(),
        ],
          ),
        ),
      ),
    );
  }

  /// Menu cepat Home: Waktu Shalat (GPS), Data Geografis (layar
  /// pencarian), Daftar Ijtimak, Kalender, Hisab Awal Bulan, Kalkulator,
  /// Kamera Rukyat.
  Widget _buildMenuCepat(bool isDark) {
    Widget tile({required IconData icon, required String label, required VoidCallback onTap}) {
      return Expanded(
        child: InkWell(
          onTap: _memuatMenuLokasi ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_memuatMenuLokasi)
                  const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(icon, color: isDark ? AppColors.primaryDark : AppColors.emerald, size: 19),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      // IntrinsicHeight + stretch: menyamakan tinggi SEMUA kotak menu ke
      // tinggi kotak yang paling tinggi -- tanpa ini, kotak "Kalender"
      // (teks 1 baris) jadi lebih pendek daripada kotak lain (teks 2
      // baris), membuat sudut border-nya terlihat tidak seragam.
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tile(
                  icon: Icons.access_time_rounded,
                  label: 'Waktu\nShalat',
                  onTap: () => _bukaDetailDenganGps(DetailSection.waktuShalat),
                ),
                const SizedBox(width: 8),
                tile(
                  icon: Icons.public_rounded,
                  label: 'Data\nGeografis',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GeografisPencarianScreen()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                tile(
                  icon: Icons.calendar_view_month_rounded,
                  label: 'Daftar\nIjtimak',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TabelIjtimakScreen()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                tile(
                  icon: Icons.calendar_month_rounded,
                  label: 'Kalender',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HijriCalendarScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tile(
                  icon: Icons.description_outlined,
                  label: 'Hisab\nAwal Bulan',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HisabAwalBulanScreen()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                tile(
                  icon: Icons.calculate_outlined,
                  label: 'Kalkulator',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const KalkulatorScreen()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                tile(
                  icon: Icons.camera_alt_outlined,
                  label: 'Kamera\nRukyat',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const KameraRukyatScreen()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
