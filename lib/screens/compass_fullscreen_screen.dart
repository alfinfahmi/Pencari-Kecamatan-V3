import 'package:flutter/material.dart';
import '../services/qibla_service.dart';
import '../theme/app_theme.dart';
import '../widgets/qibla_compass.dart';

class CompassFullscreenScreen extends StatelessWidget {
  final double bearingDerajat;
  final String namaLokasi;

  const CompassFullscreenScreen({
    super.key,
    required this.bearingDerajat,
    required this.namaLokasi,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.emeraldDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Kompas Kiblat'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(
              namaLokasi,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            QiblaCompass(bearingDerajat: bearingDerajat, size: 300),
            const SizedBox(height: 24),
            Text(
              '${bearingDerajat.toStringAsFixed(2)}°',
              style: const TextStyle(color: AppColors.gold, fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Text(
              QiblaService.arahMataAngin(bearingDerajat),
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Putar perangkat Anda hingga jarum emas menunjuk ke atas — itulah arah kiblat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12.5),
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                "LF Ma'had 'Aly Lirboyo — MHM Kediri",
                style: TextStyle(color: AppColors.goldLight, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
