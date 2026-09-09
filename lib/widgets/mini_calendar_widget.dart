import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/hijri_calendar_screen.dart';

const _namaBulanMiniKalender = {
  1: 'Januari', 2: 'Februari', 3: 'Maret', 4: 'April', 5: 'Mei', 6: 'Juni',
  7: 'Juli', 8: 'Agustus', 9: 'September', 10: 'Oktober', 11: 'November', 12: 'Desember',
};
const _namaHariMiniKalender = ['M', 'S', 'S', 'R', 'K', 'J', 'S'];

/// Kalender bulan berjalan, ringkas -- tampilan utama Home (menggantikan
/// kotak pencarian yang sudah dipindah ke menu Data Geografis). Ketuk
/// untuk membuka layar Kalender penuh (dengan info Hijriah & hilal).
class MiniCalendarWidget extends StatelessWidget {
  const MiniCalendarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sekarang = DateTime.now();
    final hari1BulanIni = DateTime(sekarang.year, sekarang.month, 1);
    final jumlahHari = DateTime(sekarang.year, sekarang.month + 1, 0).day;
    // weekday Dart: Senin=1..Ahad=7 -> kolom kita mulai dari Ahad(indeks 0)
    final offsetAwal = hari1BulanIni.weekday % 7;
    final totalSel = offsetAwal + jumlahHari;
    final jumlahBaris = (totalSel / 7).ceil();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HijriCalendarScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_namaBulanMiniKalender[sekarang.month]} ${sekarang.year}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? AppColors.textDark : AppColors.textLight),
                ),
                Icon(Icons.chevron_right_rounded, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(7, (i) => Expanded(
                child: Center(
                  child: Text(
                    _namaHariMiniKalender[i],
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 4),
            for (int baris = 0; baris < jumlahBaris; baris++)
              Row(
                children: List.generate(7, (kolom) {
                  final selKe = baris * 7 + kolom;
                  final tanggal = selKe - offsetAwal + 1;
                  final valid = tanggal >= 1 && tanggal <= jumlahHari;
                  final iniHariIni = valid && tanggal == sekarang.day;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Center(
                        child: Container(
                          width: 26, height: 26,
                          alignment: Alignment.center,
                          decoration: iniHariIni
                              ? const BoxDecoration(color: AppColors.emerald, shape: BoxShape.circle)
                              : null,
                          child: Text(
                            valid ? '$tanggal' : '',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: iniHariIni ? FontWeight.bold : FontWeight.normal,
                              color: iniHariIni
                                  ? Colors.white
                                  : (isDark ? AppColors.textDark : AppColors.textLight),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}
