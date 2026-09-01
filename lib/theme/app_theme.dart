import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet warna & tipografi resmi aplikasi, disinkronkan dengan design
/// system Stitch: "Lajnah Falakiyah Precision" (light) & "Nocturnal
/// Precision" (dark). Nilai hex diambil persis dari DESIGN.md masing-masing
/// — jangan diubah tanpa persetujuan.
class AppColors {
  // --- Brand inti (sama di kedua tema) ---
  static const Color emerald = Color(0xFF0D5C3A); // Hijau Zamrud
  static const Color gold = Color(0xFFD4AF37); // Warm Gold

  // --- Light theme: "Lajnah Falakiyah Precision" ---
  static const Color backgroundLight = Color(0xFFFBF9F6); // surface/background
  static const Color surfaceLight = Color(0xFFFFFFFF); // surface-container-lowest
  static const Color surfaceContainerLight = Color(0xFFF5F3F0); // surface-container-low
  static const Color textLight = Color(0xFF1B1C1A); // on-surface
  static const Color textSecondaryLight = Color(0xFF404942); // on-surface-variant
  static const Color primaryLight = Color(0xFF004328); // primary (tombol/aksi utama)
  static const Color outlineLight = Color(0xFF707971);
  static const Color outlineVariantLight = Color(0xFFBFC9C0);
  static const Color tertiaryLight = Color(0xFF632527); // jarum kompas, aksen kritis
  static const Color secondaryContainerLight = Color(0xFFFED65B); // badge emas terang

  // --- Dark theme: "Nocturnal Precision" ---
  static const Color backgroundDark = Color(0xFF131313); // Deep Charcoal
  static const Color surfaceDark = Color(0xFF1C1B1B); // surface-container-low
  static const Color surfaceContainerDark = Color(0xFF201F1F);
  static const Color textDark = Color(0xFFE5E2E1);
  static const Color textSecondaryDark = Color(0xFFBFC9C0);
  static const Color primaryDark = Color(0xFF8ED6AA); // primary (dominan hijau muda di dark mode)
  static const Color outlineDark = Color(0xFF89938B);
  static const Color tertiaryDark = Color(0xFFFFB3B2); // jarum kompas dark mode (salmon/pink)

  // --- Alias lama, dipertahankan untuk kompatibilitas kode yang sudah ada ---
  static const Color emeraldDark = Color(0xFF004328);
  static const Color emeraldLight = Color(0xFF1A8A5C);
  static const Color goldLight = Color(0xFFE9C349);
}

/// Tipografi sesuai design system: Hanken Grotesk untuk teks umum,
/// JetBrains Mono khusus untuk data numerik (koordinat, waktu) supaya
/// tidak "goyang" (layout shift) saat nilai berubah dan lebih mudah dibaca
/// sebagai deretan angka presisi.
class AppTypography {
  static TextStyle headlineLg({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 24, fontWeight: FontWeight.w700, height: 32 / 24, color: color,
      );
  static TextStyle headlineMd({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 20, fontWeight: FontWeight.w600, height: 28 / 20, color: color,
      );
  static TextStyle bodyLg({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 16, fontWeight: FontWeight.w400, height: 24 / 16, color: color,
      );
  static TextStyle bodyMd({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 14, fontWeight: FontWeight.w400, height: 20 / 14, color: color,
      );
  static TextStyle labelCaps({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 12, fontWeight: FontWeight.w700, height: 16 / 12, letterSpacing: 0.6, color: color,
      );
  static TextStyle captionEdu({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 12, fontWeight: FontWeight.w400, height: 16 / 12, fontStyle: FontStyle.italic, color: color,
      );

  /// Khusus data numerik (koordinat, jam) — monospace, sesuai design system.
  static TextStyle dataDisplay({Color? color, double fontSize = 15}) => GoogleFonts.jetBrainsMono(
        fontSize: fontSize, fontWeight: FontWeight.w500, letterSpacing: -0.3, color: color,
      );
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.hankenGroteskTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textLight,
      displayColor: AppColors.textLight,
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primaryLight,
        secondary: AppColors.gold,
        tertiary: AppColors.tertiaryLight,
        surface: AppColors.surfaceLight,
        outline: AppColors.outlineLight,
        outlineVariant: AppColors.outlineVariantLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.emerald,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.hankenGrotesk(
          fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.emerald,
        ),
        iconTheme: const IconThemeData(color: AppColors.emerald),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.primaryLight,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // 1rem sesuai design system
          side: BorderSide(color: AppColors.outlineVariantLight.withOpacity(0.5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999), // pill, sesuai design system search bar
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      textTheme: textTheme,
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.hankenGroteskTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primaryDark,
        secondary: AppColors.gold,
        tertiary: AppColors.tertiaryDark,
        surface: AppColors.surfaceDark,
        outline: AppColors.outlineDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.primaryDark,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.hankenGrotesk(
          fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.primaryDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.backgroundDark,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9999),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      textTheme: textTheme,
      useMaterial3: true,
    );
  }
}
