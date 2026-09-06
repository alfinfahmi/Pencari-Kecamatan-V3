import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/kecamatan_model.dart';
import '../services/favorite_service.dart';
import '../theme/app_theme.dart';
import '../screens/detail_screen.dart';
import '../screens/add_point_screen.dart';

class KecamatanCard extends StatefulWidget {
  final KecamatanModel data;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final bool awalTerbuka;

  const KecamatanCard({
    super.key,
    required this.data,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.awalTerbuka = false,
  });

  @override
  State<KecamatanCard> createState() => _KecamatanCardState();
}

class _KecamatanCardState extends State<KecamatanCard> {
  late bool _terbuka;
  final _favService = FavoriteService();

  @override
  void initState() {
    super.initState();
    _terbuka = widget.awalTerbuka;
  }

  void _copyData(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.data.toClipboardText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data disalin ke clipboard'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _bukaDetail(BuildContext context, DetailSection section) async {
    await _favService.addToHistory(widget.data.id);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(data: widget.data, initialSection: section)),
    );
  }

  void _bukaTambahTitik(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddPointScreen(induk: widget.data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.data;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _terbuka = !_terbuka),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withOpacity(isDark ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      data.isReferensi ? Icons.mosque_rounded : Icons.location_on_rounded,
                      size: 18,
                      color: AppColors.emerald,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data.kecamatan,
                                style: AppTypography.bodyLg(
                                  color: isDark ? AppColors.textDark : AppColors.textLight,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (data.isReferensi) _badgeTerverifikasi(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [data.kabupaten, data.provinsi].where((e) => e != null).join(', '),
                          style: AppTypography.bodyMd(color: Colors.grey.shade500).copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _terbuka ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _terbuka ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kotakKoordinat(
                        isDark: isDark,
                        judul: 'Derajat Desimal',
                        icon: Icons.my_location_rounded,
                        kiriLabel: 'Lintang', kiriNilai: '${data.lat}°',
                        kananLabel: 'Bujur', kananNilai: '${data.lng}°',
                      ),
                      if (data.latDms != null && data.lngDms != null) ...[
                        const SizedBox(height: 8),
                        _kotakKoordinat(
                          isDark: isDark,
                          judul: 'Format DMS',
                          icon: Icons.public_rounded,
                          kiriLabel: 'Lintang', kiriNilai: data.latDms!,
                          kananLabel: 'Bujur', kananNilai: data.lngDms!,
                        ),
                      ],
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _menuButton(
                              context, isDark,
                              icon: Icons.public_rounded,
                              label: 'Rincian\nGeografis',
                              onTap: () => _bukaDetail(context, DetailSection.geografis),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _menuButton(
                              context, isDark,
                              icon: Icons.explore_rounded,
                              label: 'Arah\nKiblat',
                              onTap: () => _bukaDetail(context, DetailSection.kiblat),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _menuButton(
                              context, isDark,
                              icon: Icons.access_time_rounded,
                              label: 'Jadwal\nWaktu Sholat',
                              isPrimary: true,
                              onTap: () => _bukaDetail(context, DetailSection.waktuShalat),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: data.isReferensi
                                ? const SizedBox.shrink()
                                : _menuButton(
                                    context, isDark,
                                    icon: Icons.add_location_alt_rounded,
                                    label: 'Tambah Titik\ndi Sini',
                                    onTap: () => _bukaTambahTitik(context),
                                  ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _iconButtonKotak(
                              icon: Icons.copy_rounded,
                              label: 'Salin Data',
                              onTap: () => _copyData(context),
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _iconButtonKotak(
                              icon: widget.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              label: widget.isFavorite ? 'Favorit' : 'Simpan Favorit',
                              iconColor: widget.isFavorite ? Colors.redAccent : null,
                              onTap: widget.onToggleFavorite,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final bgColor = isPrimary
        ? AppColors.emerald
        : (isDark ? Colors.white.withOpacity(0.06) : AppColors.emerald.withOpacity(0.06));
    final fgColor = isPrimary ? Colors.white : AppColors.emerald;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: isPrimary ? null : Border.all(color: AppColors.emerald.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fgColor),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd(color: fgColor).copyWith(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeTerverifikasi() {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.85),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text('Terverifikasi', style: AppTypography.labelCaps(color: AppColors.emeraldDark).copyWith(fontSize: 9.5)),
    );
  }

  Widget _kotakKoordinat({
    required bool isDark,
    required String judul,
    required IconData icon,
    required String kiriLabel,
    required String kiriNilai,
    required String kananLabel,
    required String kananNilai,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.025),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.emerald),
              const SizedBox(width: 6),
              Text(judul, style: AppTypography.labelCaps(color: Colors.grey.shade600).copyWith(fontSize: 10.5)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _labelNilai(isDark, kiriLabel, kiriNilai)),
              Expanded(child: _labelNilai(isDark, kananLabel, kananNilai)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _labelNilai(bool isDark, String label, String nilai) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodyMd(color: Colors.grey.shade500).copyWith(fontSize: 11)),
        Text(nilai, style: AppTypography.dataDisplay(fontSize: 13.5, color: isDark ? AppColors.textDark : AppColors.textLight)),
      ],
    );
  }

  Widget _iconButtonKotak({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: iconColor ?? (isDark ? AppColors.textDark : AppColors.textLight)),
            const SizedBox(height: 3),
            Text(label, style: AppTypography.bodyMd(color: iconColor ?? Colors.grey.shade600).copyWith(fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}
