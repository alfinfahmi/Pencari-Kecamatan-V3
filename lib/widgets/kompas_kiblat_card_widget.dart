import 'package:flutter/material.dart';
import '../models/kecamatan_model.dart';
import '../services/qibla_service.dart';
import '../services/kalkulator_service.dart';
import '../services/lokasi_cache_service.dart';
import '../theme/app_theme.dart';
import '../screens/compass_fullscreen_screen.dart';

/// Kartu "Kompas Kiblat" -- dipindah dari dalam Detail Lokasi ke Home
/// (di bawah kalender) supaya lebih mudah diakses langsung, tanpa perlu
/// masuk ke Data Geografis dulu.
class KompasKiblatCardWidget extends StatefulWidget {
  const KompasKiblatCardWidget({super.key});

  @override
  State<KompasKiblatCardWidget> createState() => _KompasKiblatCardWidgetState();
}

class _KompasKiblatCardWidgetState extends State<KompasKiblatCardWidget> {
  KecamatanModel? _lokasi;

  @override
  void initState() {
    super.initState();
    _lokasi = LokasiCacheService.instance.lokasiCache;
    _muatLokasi();
  }

  Future<void> _muatLokasi() async {
    final lokasi = await LokasiCacheService.instance.ambilLokasi();
    if (mounted && lokasi != null) setState(() => _lokasi = lokasi);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lokasi = _lokasi;

    double? bearing;
    if (lokasi != null) {
      bearing = QiblaService.bearingDerajat(
        lat1: lokasi.lat, lng1: lokasi.lng,
        lat2: KalkulatorService.kabahLat, lng2: KalkulatorService.kabahLng,
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: bearing == null
          ? null
          : () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CompassFullscreenScreen(
                  bearingDerajat: bearing!,
                  namaLokasi: lokasi!.kecamatan,
                ),
              ));
            },
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: (isDark ? AppColors.primaryDark : AppColors.emerald).withOpacity(0.14), shape: BoxShape.circle),
              child: Icon(Icons.explore_rounded, color: isDark ? AppColors.primaryDark : AppColors.emerald, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kompas Kiblat', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? AppColors.textDark : AppColors.textLight)),
                  const SizedBox(height: 2),
                  Text(
                    bearing != null ? '${bearing.toStringAsFixed(2)}\u00b0 dari Utara -- ${lokasi!.kecamatan}' : 'Mengambil lokasi...',
                    style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, size: 20),
          ],
        ),
      ),
    );
  }
}
