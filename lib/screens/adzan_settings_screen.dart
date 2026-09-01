import 'package:flutter/material.dart';
import '../services/adzan_notification_service.dart';
import '../theme/app_theme.dart';

class AdzanSettingsScreen extends StatefulWidget {
  const AdzanSettingsScreen({super.key});

  @override
  State<AdzanSettingsScreen> createState() => _AdzanSettingsScreenState();
}

class _AdzanSettingsScreenState extends State<AdzanSettingsScreen> {
  final _service = AdzanNotificationService.instance;
  bool _aktif = false;
  VolumeAdzan _volume = VolumeAdzan.normal;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final aktif = await _service.isAktif();
    final volume = await _service.getVolume();
    setState(() {
      _aktif = aktif;
      _volume = volume;
      _loading = false;
    });
  }

  Future<void> _toggleAktif(bool value) async {
    if (value) {
      final berhasil = await _service.aktifkan();
      if (!berhasil) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin notifikasi ditolak. Aktifkan lewat pengaturan HP.')),
          );
        }
        return;
      }
    } else {
      await _service.matikan();
    }
    setState(() => _aktif = value);
  }

  Future<void> _ubahVolume(VolumeAdzan v) async {
    await _service.setVolume(v);
    setState(() => _volume = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi Adzan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  title: const Text('Notifikasi Adzan'),
                  subtitle: const Text('Pengingat waktu shalat (Subuh, Dzuhur, Ashar, Maghrib, Isya)'),
                  value: _aktif,
                  activeColor: AppColors.emerald,
                  onChanged: _toggleAktif,
                ),
                const Divider(height: 32),
                Opacity(
                  opacity: _aktif ? 1 : 0.4,
                  child: IgnorePointer(
                    ignoring: !_aktif,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Volume', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          'Aplikasi tidak bisa mengatur volume secara langsung (dibatasi sistem Android/iOS) -- '
                          'pilihan ini menentukan penggeser volume HP mana yang dipakai.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                        ),
                        const SizedBox(height: 12),
                        RadioListTile<VolumeAdzan>(
                          title: const Text('Normal'),
                          subtitle: const Text('Mengikuti volume Notifikasi HP'),
                          value: VolumeAdzan.normal,
                          groupValue: _volume,
                          activeColor: AppColors.emerald,
                          onChanged: (v) => _ubahVolume(v!),
                        ),
                        RadioListTile<VolumeAdzan>(
                          title: const Text('Keras'),
                          subtitle: const Text('Mengikuti volume Alarm HP -- lebih keras, bisa menembus mode senyap'),
                          value: VolumeAdzan.keras,
                          groupValue: _volume,
                          activeColor: AppColors.emerald,
                          onChanged: (v) => _ubahVolume(v!),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 32),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Catatan: jadwal notifikasi diperbarui otomatis setiap kali aplikasi dibuka. '
                    'Kalau aplikasi tidak dibuka sama sekali dalam satu hari, notifikasi hari itu '
                    'tidak akan muncul. Suara memakai nada notifikasi standar perangkat.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
    );
  }
}
