import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/prayer_settings_service.dart';
import '../theme/app_theme.dart';

/// Bottom sheet pengaturan waktu shalat (ihtiyath & sudut depresi).
/// Setiap item ihtiyath tampil sebagai kotak sendiri; sudut depresi dipilih
/// lewat pill ANGKA SAJA (tanpa label nama institusi seperti "Kemenag",
/// sesuai permintaan -- menghindari klaim atribusi yang belum tentu akurat).
class PrayerSettingsSheet extends StatefulWidget {
  const PrayerSettingsSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PrayerSettingsSheet(),
    );
  }

  @override
  State<PrayerSettingsSheet> createState() => _PrayerSettingsSheetState();
}

class _PrayerSettingsSheetState extends State<PrayerSettingsSheet> {
  final _service = PrayerSettingsService();
  Map<String, double> _ihtiyath = {};
  double _sudutIsya = PrayerSettingsService.defaultSudutIsya;
  double _sudutSubuh = PrayerSettingsService.defaultSudutSubuh;
  bool _loading = true;
  bool _changed = false;

  static const _labelWaktu = {
    'imsak': 'Imsak', 'subuh': 'Subuh', 'terbit': "Terbit/Thulu'",
    'dhuha': 'Dhuha', 'dhuhur': 'Dzuhur', 'ashar': 'Ashar',
    'maghrib': 'Maghrib', 'isya': "Isya'",
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ihtiyath = await _service.getIhtiyath();
    final si = await _service.getSudutIsya();
    final ss = await _service.getSudutSubuh();
    setState(() {
      _ihtiyath = ihtiyath;
      _sudutIsya = si;
      _sudutSubuh = ss;
      _loading = false;
    });
  }

  Future<void> _ubahIhtiyath(String key, int delta) async {
    final current = (_ihtiyath[key] ?? 2.0);
    final isTerbit = key == 'terbit';
    final minVal = isTerbit ? -5.0 : 2.0;
    final maxVal = isTerbit ? -2.0 : 5.0;
    final next = (current + delta).clamp(minVal, maxVal);
    await _service.setIhtiyath(key, next.toDouble());
    setState(() { _ihtiyath[key] = next.toDouble(); _changed = true; });
  }

  Future<void> _resetSemua() async {
    await _service.resetKeDefault();
    await _load();
    setState(() => _changed = true);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.85),
            decoration: BoxDecoration(
              color: const Color(0xE6142019),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppColors.gold.withOpacity(0.25)),
            ),
            child: _loading
                ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: AppColors.gold)))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 42, height: 4,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Pengaturan Perhitungan',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                                        const SizedBox(height: 2),
                                        Text('Sesuaikan parameter presisi', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                                    onPressed: () => Navigator.of(context).pop(_changed),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              _sectionLabel(Icons.timer_outlined, 'WAKTU PENGAMAN (IHTIYATH)'),
                              const SizedBox(height: 10),
                              ..._labelWaktu.entries.map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ihtiyathKotak(e.key, e.value),
                                  )),

                              const SizedBox(height: 8),
                              _sectionLabel(Icons.wb_twilight_rounded, 'SUDUT DEPRESI MATAHARI'),
                              const SizedBox(height: 10),
                              _sudutKotak(
                                label: 'Sudut Subuh',
                                value: _sudutSubuh,
                                opsi: PrayerSettingsService.opsiSudutSubuh,
                                onChanged: (v) async {
                                  await _service.setSudutSubuh(v);
                                  setState(() { _sudutSubuh = v; _changed = true; });
                                },
                              ),
                              const SizedBox(height: 10),
                              _sudutKotak(
                                label: "Sudut Isya'",
                                value: _sudutIsya,
                                opsi: PrayerSettingsService.opsiSudutIsya,
                                onChanged: (v) async {
                                  await _service.setSudutIsya(v);
                                  setState(() { _sudutIsya = v; _changed = true; });
                                },
                              ),

                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Ihtiyath adalah tambahan waktu kehati-hatian (menit) agar waktu shalat '
                                  'lebih aman dari kesalahan hisab. Sudut depresi (h) adalah posisi matahari '
                                  "di bawah ufuk saat fajar/syafaq, dipakai menghitung awal Subuh dan Isya'.",
                                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11.5, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _resetSemua,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: BorderSide(color: Colors.white.withOpacity(0.25)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Atur Ulang'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(_changed),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.emerald,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('Terapkan Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 15, color: AppColors.goldLight),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: AppColors.goldLight, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
        ],
      );

  Widget _ihtiyathKotak(String key, String label) {
    final value = _ihtiyath[key] ?? 2.0;
    final isNegative = value < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14))),
          _stepperButton(Icons.remove_rounded, () => _ubahIhtiyath(key, -1)),
          SizedBox(
            width: 56,
            child: Text(
              '${isNegative ? '' : '+'}${value.toInt()}m',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.goldLight, fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
          _stepperButton(Icons.add_rounded, () => _ubahIhtiyath(key, 1)),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: Colors.white),
      ),
    );
  }

  Widget _sudutKotak({
    required String label,
    required double value,
    required List<double> opsi,
    required ValueChanged<double> onChanged,
  }) {
    final semuaOpsi = {value, ...opsi}.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: semuaOpsi.map((o) {
              final selected = o == value;
              return InkWell(
                onTap: () => onChanged(o),
                borderRadius: BorderRadius.circular(9999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.emerald.withOpacity(0.25) : Colors.transparent,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: selected ? AppColors.goldLight : Colors.white24),
                  ),
                  child: Text(
                    '${o.toStringAsFixed(1)}°',
                    style: TextStyle(
                      color: selected ? AppColors.goldLight : Colors.white70,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
