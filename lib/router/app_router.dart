import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/activation_screen.dart';
import '../screens/home_screen.dart';
import '../screens/detail_screen.dart';
import '../screens/export_jadwal_screen.dart';
import '../screens/compass_fullscreen_screen.dart';
import '../screens/add_point_screen.dart';
import '../screens/usulkan_koreksi_screen.dart';
import '../screens/tabel_ijtimak_screen.dart';
import '../screens/hijri_calendar_screen.dart';
import '../screens/adzan_settings_screen.dart';
import '../screens/moderation_panel_screen.dart';
import '../screens/auth_screen.dart';
import 'kecamatan_uri.dart';

/// Konfigurasi router berbasis URL (go_router) -- setiap layar dapat
/// alamat URL sendiri di browser (mis. /tabel-ijtimak, /kalender), supaya
/// REFRESH BROWSER tetap menampilkan halaman yang sama, bukan kembali ke
/// Home seperti sebelumnya (yang terjadi karena navigasi lama cuma pakai
/// Navigator.push biasa, tidak tercermin di address bar sama sekali).
///
/// Data lokasi (KecamatanModel) untuk layar seperti DetailScreen dikirim
/// lewat QUERY PARAMETER URL (bukan `extra`/state di memori) -- supaya
/// saat browser di-refresh, data itu BISA dibaca ulang langsung dari URL
/// itu sendiri (satu-satunya yang selalu ada, karena `extra` hilang tiap
/// kali web-app dimuat ulang dari nol).
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/aktivasi', builder: (context, state) => const ActivationScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/detail',
      builder: (context, state) {
        final data = kecamatanDariQuery(state.uri.queryParameters);
        final sectionStr = state.uri.queryParameters['section'];
        DetailSection? section;
        for (final s in DetailSection.values) {
          if (s.name == sectionStr) section = s;
        }
        return DetailScreen(data: data, initialSection: section);
      },
    ),
    GoRoute(
      path: '/ekspor',
      builder: (context, state) {
        final data = kecamatanDariQuery(state.uri.queryParameters);
        return ExportJadwalScreen(data: data);
      },
    ),
    GoRoute(
      path: '/kompas',
      builder: (context, state) {
        final bearing = double.tryParse(state.uri.queryParameters['bearing'] ?? '') ?? 0;
        final nama = state.uri.queryParameters['nama'] ?? '-';
        return CompassFullscreenScreen(bearingDerajat: bearing, namaLokasi: nama);
      },
    ),
    GoRoute(
      path: '/tambah-titik',
      builder: (context, state) {
        final induk = kecamatanDariQuery(state.uri.queryParameters);
        return AddPointScreen(induk: induk);
      },
    ),
    GoRoute(
      path: '/usulkan-koreksi',
      builder: (context, state) {
        final data = kecamatanDariQuery(state.uri.queryParameters);
        return UsulkanKoreksiScreen(data: data);
      },
    ),
    GoRoute(path: '/tabel-ijtimak', builder: (context, state) => const TabelIjtimakScreen()),
    GoRoute(path: '/kalender', builder: (context, state) => const HijriCalendarScreen()),
    GoRoute(path: '/notifikasi-adzan', builder: (context, state) => const AdzanSettingsScreen()),
    GoRoute(path: '/moderasi', builder: (context, state) => const ModerationPanelScreen()),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
  ],
);
