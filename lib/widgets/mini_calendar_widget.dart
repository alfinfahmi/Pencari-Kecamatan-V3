import 'package:flutter/material.dart';
import '../models/kecamatan_model.dart';
import '../services/hijri_service.dart';
import '../services/lokasi_cache_service.dart';
import '../theme/app_theme.dart';
import '../screens/hijri_calendar_screen.dart';

const _namaBulanMiniKalender = {
  1: 'Januari', 2: 'Februari', 3: 'Maret', 4: 'April', 5: 'Mei', 6: 'Juni',
  7: 'Juli', 8: 'Agustus', 9: 'September', 10: 'Oktober', 11: 'November', 12: 'Desember',
};
// Ahad di kolom pertama (indeks 0), sesuai contoh acuan pengguna.
const _namaHariMiniKalender = ['Ahad', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
const _angkaArabMini = ['\u0660', '\u0661', '\u0662', '\u0663', '\u0664', '\u0665', '\u0666', '\u0667', '\u0668', '\u0669'];
String _keAngkaArabMini(int n) => n.toString().split('').map((d) => _angkaArabMini[int.parse(d)]).join();

/// Kalender bulan berjalan, ringkas -- tampilan utama Home. Menampilkan
/// tanggal Masehi + Hijriyah (angka Arab) + pasaran per hari, dengan
/// warna Ahad=merah & Jumat=hijau -- meniru konvensi kalender Islam
/// umum (persis pola yang sudah dipakai layar Kalender penuh). Ketuk
/// untuk membuka layar Kalender penuh (dengan info hilal & hari penting).
class MiniCalendarWidget extends StatefulWidget {
  const MiniCalendarWidget({super.key});

  @override
  State<MiniCalendarWidget> createState() => _MiniCalendarWidgetState();
}

class _MiniCalendarWidgetState extends State<MiniCalendarWidget> {
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
    final sekarang = DateTime.now();
    final hari1BulanIni = DateTime(sekarang.year, sekarang.month, 1);
    final jumlahHari = DateTime(sekarang.year, sekarang.month + 1, 0).day;
    // weekday Dart: Senin=1..Ahad=7 -> kolom kita mulai dari Ahad(indeks 0)
    final offsetAwal = hari1BulanIni.weekday % 7;
    final totalSel = offsetAwal + jumlahHari;
    final jumlahBaris = (totalSel / 7).ceil();
    final lokasi = _lokasi;

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
              children: List.generate(7, (i) {
                final iniAhad = i == 0;
                final iniJumat = i == 5;
                return Expanded(
                  child: Center(
                    child: Text(
                      _namaHariMiniKalender[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: iniAhad
                            ? Colors.red.shade300
                            : iniJumat
                                ? (isDark ? AppColors.primaryDark : AppColors.emerald)
                                : (isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            for (int baris = 0; baris < jumlahBaris; baris++)
              Row(
                children: List.generate(7, (kolom) {
                  final selKe = baris * 7 + kolom;
                  final tanggal = selKe - offsetAwal + 1;
                  final valid = tanggal >= 1 && tanggal <= jumlahHari;
                  final tanggalMasehi = valid ? DateTime(sekarang.year, sekarang.month, tanggal) : null;
                  final iniHariIni = valid && tanggal == sekarang.day;
                  final iniAhad = valid && tanggalMasehi!.weekday == 7;
                  final iniJumat = valid && tanggalMasehi!.weekday == 5;

                  TanggalHijriah? hijri;
                  if (valid && lokasi != null && lokasi.utcOffset != null) {
                    hijri = HijriService.instance.konversi(
                      tanggalMasehi!,
                      lat: lokasi.lat, lng: lokasi.lng,
                      utcOffset: lokasi.utcOffset!,
                      elevasiM: (lokasi.elevasiM ?? 0).toDouble(),
                    );
                  }

                  Color warnaAngka;
                  if (!valid) {
                    warnaAngka = Colors.transparent;
                  } else if (iniHariIni) {
                    warnaAngka = Colors.white;
                  } else if (iniAhad) {
                    warnaAngka = Colors.red.shade300;
                  } else if (iniJumat) {
                    warnaAngka = isDark ? AppColors.primaryDark : AppColors.emerald;
                  } else {
                    warnaAngka = isDark ? AppColors.textDark : AppColors.textLight;
                  }
                  final warnaKecil = isDark ? Colors.grey.shade500 : Colors.grey.shade500;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Container(
                        decoration: iniHariIni
                            ? BoxDecoration(color: AppColors.emerald, borderRadius: BorderRadius.circular(8))
                            : null,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: valid
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hijri != null)
                                    Text(_keAngkaArabMini(hijri.hari), style: TextStyle(fontSize: 8.5, color: iniHariIni ? Colors.white70 : warnaKecil)),
                                  Text(
                                    '$tanggal',
                                    style: TextStyle(fontSize: 12.5, fontWeight: iniHariIni ? FontWeight.bold : FontWeight.normal, color: warnaAngka),
                                  ),
                                  Text(HijriService.hitungPasaran(tanggalMasehi!), style: TextStyle(fontSize: 7.5, color: iniHariIni ? Colors.white70 : warnaKecil)),
                                ],
                              )
                            : const SizedBox(height: 1),
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
