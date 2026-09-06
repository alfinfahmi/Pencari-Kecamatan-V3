import 'package:flutter/material.dart';
import '../services/app_data_service.dart';
import '../services/activation_service.dart';
import '../theme/app_theme.dart';
import 'activation_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await AppDataService.instance.load();
    final activated = await ActivationService().isActivated();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => activated ? const HomeScreen() : const ActivationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.emerald,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            const Icon(Icons.mosque_rounded, color: AppColors.gold, size: 72),
            const SizedBox(height: 16),
            const Text(
              'Koordinat Kec.\nTashil',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.gold),
            const Spacer(flex: 4),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                "LF Ma'had 'Aly Lirboyo — MHM Kediri",
                style: TextStyle(
                  color: AppColors.goldLight,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
