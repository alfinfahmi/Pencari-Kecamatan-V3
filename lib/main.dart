import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/custom_point_model.dart';
import 'screens/splash_screen.dart';
import 'services/adzan_notification_service.dart';
import 'services/hijri_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';

/// Controller tema global sederhana, agar tombol dark mode di layar mana pun
/// (mis. HomeScreen) bisa mengubah tema tanpa state management tambahan.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // PENTING (kepatuhan syarat 100% offline): google_fonts secara default
  // akan mencoba MENGUNDUH font dari internet saat runtime jika file font
  // belum ada sebagai aset lokal. Ini dimatikan paksa di sini -- tanpa font
  // lokal ter-bundle, tampilan otomatis jatuh ke font sistem (aman, hanya
  // kehilangan tipografi Hanken Grotesk/JetBrains Mono yang dimaksud), TIDAK
  // PERNAH mencoba akses jaringan. Lihat README bagian "Tipografi" untuk cara
  // membundel font sungguhan supaya tipografi sesuai design system penuh.
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

  runApp(const PencariKecamatanApp());
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
