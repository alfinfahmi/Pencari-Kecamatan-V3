import 'package:flutter/material.dart';
import '../services/hijri_service.dart';
import '../services/hisab_preference_service.dart';
import '../theme/app_theme.dart';

/// Sheet pengaturan kriteria imkan rukyat -- mempengaruhi penentuan awal
/// bulan Hijriah di SELURUH aplikasi (badge tanggal, kalender, Tabel
/// Ijtimak), karena disimpan di HijriService.kriteriaAktif secara global.
class KriteriaHilalSettingsSheet extends StatefulWidget {
  const KriteriaHilalSettingsSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const KriteriaHilalSettingsSheet(),
    );
  }

  @override
  State<KriteriaHilalSettingsSheet> createState() => _KriteriaHilalSettingsSheetState();
}

class _KriteriaHilalSettingsSheetState extends State<KriteriaHilalSettingsSheet> {
  final _service = HisabPreferenceService();
  KriteriaImkanRukyat _terpilih = KriteriaImkanRukyat.mabims2021;
  bool _loading = true;
  bool _berubah = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final k = await _service.getKriteria();
    setState(() {
      _terpilih = k;
      _loading = false;
    });
  }

  Future<void> _pilih(KriteriaImkanRukyat k) async {
    await _service.setKriteria(k);
    setState(() {
      _terpilih = k;
      _berubah = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Kriteria Imkan Rukyat', style: AppTypography.headlineMd()),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(_berubah),
                        ),
                      ],
                    ),
                    Text(
                      'Menentukan ambang batas lolos/tidaknya hilal, berlaku untuk seluruh '
                      'perhitungan awal bulan Hijriah di aplikasi ini (badge tanggal, kalender, Tabel Ijtimak).',
                      style: AppTypography.bodyMd(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    ...KriteriaImkanRukyat.values.map((k) => RadioListTile<KriteriaImkanRukyat>(
                          contentPadding: EdgeInsets.zero,
                          title: Text(k.label, style: const TextStyle(fontSize: 14)),
                          value: k,
                          groupValue: _terpilih,
                          activeColor: AppColors.emerald,
                          onChanged: (v) => _pilih(v!),
                        )),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        'MABIMS 2021 adalah kriteria resmi pemerintah RI saat ini. Kriteria lain '
                        'di atas adalah kriteria yang pernah/masih dipakai sebagian kalangan lain -- '
                        'pilihan ada di tangan Anda, silakan sesuaikan dengan rujukan yang dipegang.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.4),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
