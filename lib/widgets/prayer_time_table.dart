import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../services/hisab_service.dart';
import '../theme/app_theme.dart';

class PrayerTimeTable extends StatelessWidget {
  final List<WaktuShalatEntry> entries;
  final String labelZona; // "WIB" / "WITA" / "WIT"
  final DateTime? sekarang; // override untuk testing; default DateTime.now()

  const PrayerTimeTable({super.key, required this.entries, required this.labelZona, this.sekarang});

  /// Menentukan indeks entri yang sedang "aktif" (waktu sekarang berada di
  /// antara waktu entri ini dan entri berikutnya), untuk highlight visual —
  /// meniru penanda baris "Dzuhur" pada rancangan referensi.
  int? _indeksAktif(DateTime now) {
    int? aktif;
    for (int i = 0; i < entries.length; i++) {
      if (!now.isBefore(entries[i].waktuDaerah)) {
        aktif = i;
      }
    }
    return aktif;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = DateFormat('HH:mm');
    final now = sekarang ?? DateTime.now();
    final aktifIndex = _indeksAktif(now);

    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: Text('Waktu', style: AppTypography.labelCaps(color: Colors.grey.shade500).copyWith(fontSize: 11))),
            Expanded(
              flex: 2,
              child: Text('Standar ($labelZona)',
                  textAlign: TextAlign.center,
                  style: AppTypography.labelCaps(color: Colors.grey.shade500).copyWith(fontSize: 11)),
            ),
            Expanded(
              flex: 2,
              child: Text("Istiwa'",
                  textAlign: TextAlign.center,
                  style: AppTypography.labelCaps(color: Colors.grey.shade500).copyWith(fontSize: 11)),
            ),
          ],
        ),
        const Divider(height: 14),
        ...entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final isAktif = i == aktifIndex;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
            margin: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: isAktif ? AppColors.gold.withOpacity(isDark ? 0.14 : 0.12) : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      if (isAktif) ...[
                        Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle)),
                      ],
                      Text(
                        e.nama,
                        style: AppTypography.bodyMd(
                          color: isAktif ? AppColors.gold : (isDark ? AppColors.textDark : AppColors.textLight),
                        ).copyWith(fontWeight: isAktif ? FontWeight.w700 : FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(fmt.format(e.waktuDaerah),
                      textAlign: TextAlign.center,
                      style: AppTypography.dataDisplay(
                        fontSize: 13,
                        color: isAktif ? AppColors.gold : (isDark ? AppColors.textDark : AppColors.textLight),
                      )),
                ),
                Expanded(
                  flex: 2,
                  child: Text(fmt.format(e.jamIstiwa),
                      textAlign: TextAlign.center,
                      style: AppTypography.dataDisplay(fontSize: 13, color: Colors.grey.shade500)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
