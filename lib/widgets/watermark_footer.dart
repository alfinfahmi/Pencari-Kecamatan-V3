import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Identitas watermark, wajib tampil di semua layar sesuai kesepakatan final.
class WatermarkFooter extends StatelessWidget {
  const WatermarkFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          "LF Ma'had 'Aly Lirboyo — MHM Kediri",
          style: TextStyle(
            fontSize: 11,
            fontStyle: FontStyle.italic,
            color: isDark ? AppColors.goldLight.withOpacity(0.7) : AppColors.emerald.withOpacity(0.6),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
