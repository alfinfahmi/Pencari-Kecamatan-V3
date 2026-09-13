import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'models/custom_point_model.dart';
import 'screens/splash_screen.dart';
import 'services/adzan_notification_service.dart';
import 'services/hijri_service.dart';
import 'services/hisab_preference_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

/// Controller tema global sederhana, agar tombol dark mode di layar mana pun
/// (mis. HomeScreen) bisa mengubah tema tanpa state management tambahan.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  // Sentry membungkus SELURUH inisialisasi + runApp() lewat `appRunner` --
  // ini pola resmi paket ini, supaya error apa pun (termasuk yang terjadi
  // SAAT startup, sebelum UI muncul) ikut tertangkap, bukan cuma error
  // setelah aplikasi berjalan.
  //
  // CATATAN soal komitmen "100% offline" aplikasi ini (lihat catatan
  // GoogleFonts di bawah): Sentry BUTUH internet untuk MENGIRIM laporan
  // crash, TAPI ini murni pelaporan LATAR BELAKANG, bukan syarat fungsi
  // apa pun -- kalau offline, Sentry cuma gagal diam-diam mengirim
  // laporannya (atau coba lagi nanti), TIDAK PERNAH membuat aplikasi
  // gagal jalan atau menunggu jaringan. Prinsip "berfungsi penuh tanpa
  // internet" tetap utuh.
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://f2950ee5b077f8976c72857408819715@o4512069441486848.ingest.de.sentry.io/4512069447974992';
      // Native crash Android/Kotlin (mis. dari Kamera Rukyat, Widget Home
      // Screen) ikut tertangkap otomatis oleh SDK ini -- tidak perlu
      // konfigurasi tambahan.
      options.tracesSampleRate = 0.2;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      // PENTING (kepatuhan syarat 100% offline): google_fonts secara default
      // akan mencoba MENGUNDUH font dari internet saat runtime jika file font
      // belum ada sebagai aset lokal. Ini dimatikan paksa di sini supaya TIDAK
      // PERNAH mencoba akses jaringan.
      //
      // KOREKSI PENTING (ditemukan lewat crash nyata di Sentry, FLUTTER-1 &
      // FLUTTER-2): dugaan awal "tanpa font lokal, otomatis jatuh ke font
      // sistem dengan aman" itu SALAH -- yang benar-benar terjadi adalah
      // GoogleFonts.hankenGrotesk()/jetBrainsMono() MELEMPAR EXCEPTION FATAL
      // kalau file font belum ter-bundle. Supaya baris ini tetap 100% offline
      // TANPA membuat aplikasi crash, seluruh pemanggilan GoogleFonts di
      // lib/theme/app_theme.dart sudah dibungkus try-catch (lihat helper
      // `_hanken()`/`_jetBrainsMono()` di file itu) yang jatuh ke font sistem
      // kalau exception ini terjadi -- baris `allowRuntimeFetching = false`
      // di sini TIDAK cukup sendirian, wajib dipasangkan dengan itu.
      GoogleFonts.config.allowRuntimeFetching = false;

      await Hive.initFlutter();
      Hive.registerAdapter(CustomPointModelAdapter());

      // Supabase hanya benar-benar aktif jika SupabaseConfig sudah diisi (lihat
      // lib/config/supabase_config.dart). Jika belum, ini no-op -- fitur
      // koreksi/moderasi otomatis nonaktif tanpa membuat aplikasi crash.
      await SupabaseService.instance.initialize();

      // Hanya menyiapkan plugin, TIDAK menyalakan notifikasi apa pun --
      // default tetap mati sampai pengguna aktifkan sendiri lewat pengaturan.
      await AdzanNotificationService.instance.initialize();

      // Muat tabel ijtimak resmi Lirboyo ke cache memori (dipakai HijriService
      // sebagai sumber utama, fallback ke formula kalau di luar rentang
      // 1440H-1500H). Kalau gagal dimuat, aplikasi tetap jalan normal lewat
      // fallback formula -- tidak crash.
      await HijriService.muatTabelIjtimak();
      await HisabPreferenceService.muatKeHijriService();

      runApp(const PencariKecamatanApp());
    },
  );
}

class PencariKecamatanApp extends StatelessWidget {
  const PencariKecamatanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Aplikasi Falak',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const SplashScreen(),
        );
      },
    );
  }
}
