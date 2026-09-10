import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_checker_service.dart';
import '../theme/app_theme.dart';

/// Banner "Update tersedia" -- muncul di atas Home kalau versi terbaru
/// di GitHub Release lebih baru dari yang terpasang. Ketuk unduh ->
/// buka URL APK di browser -> Android urus unduhan & dialog konfirmasi
/// instal SENDIRI (standar, tidak bisa/tidak seharusnya dilewati).
class UpdateBannerWidget extends StatefulWidget {
  const UpdateBannerWidget({super.key});

  @override
  State<UpdateBannerWidget> createState() => _UpdateBannerWidgetState();
}

class _UpdateBannerWidgetState extends State<UpdateBannerWidget> {
  InfoUpdate? _info;
  bool _ditutup = false;

  @override
  void initState() {
    super.initState();
    _cek();
  }

  Future<void> _cek() async {
    final info = await UpdateCheckerService.instance.cekUpdate();
    if (mounted && info != null) setState(() => _info = info);
  }

  Future<void> _unduh() async {
    final info = _info;
    if (info == null) return;
    final uri = Uri.parse(info.urlUnduhApk);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null || _ditutup) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update_rounded, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Update tersedia: ${info.versiTerbaru}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? AppColors.textDark : AppColors.textLight)),
                Text('Ketuk untuk unduh -- instalasi tetap butuh konfirmasi Anda', style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
              ],
            ),
          ),
          TextButton(
            onPressed: _unduh,
            child: const Text('Unduh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _ditutup = true),
            tooltip: 'Tutup',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
