import 'package:flutter/material.dart';
import '../models/koreksi_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/watermark_footer.dart';

class ModerationPanelScreen extends StatefulWidget {
  const ModerationPanelScreen({super.key});

  @override
  State<ModerationPanelScreen> createState() => _ModerationPanelScreenState();
}

class _ModerationPanelScreenState extends State<ModerationPanelScreen> {
  List<KoreksiModel>? _usulan;
  String? _error;
  final Map<String, TextEditingController> _catatanControllers = {};

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    for (final c in _catatanControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerUntuk(String id) {
    return _catatanControllers.putIfAbsent(id, () => TextEditingController());
  }

  Future<void> _muat() async {
    try {
      final data = await SupabaseService.instance.ambilUsulanPending();
      if (mounted) setState(() { _usulan = data; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat usulan: $e');
    }
  }

  Future<void> _prosesUsulan(KoreksiModel k, bool disetujui) async {
    final catatan = _controllerUntuk(k.id!).text.trim();
    try {
      if (disetujui) {
        await SupabaseService.instance.setujuiKoreksi(k.id!, catatan: catatan.isEmpty ? null : catatan);
      } else {
        await SupabaseService.instance.tolakKoreksi(k.id!, catatan: catatan.isEmpty ? null : catatan);
      }
      _muat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  String _waktuRelatif(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit yang lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam yang lalu';
    return '${diff.inDays} hari yang lalu';
  }

  String _labelRole(String? role) {
    switch (role) {
      case 'admin': return 'Admin';
      case 'kontributor': return 'Kontributor';
      default: return 'Pengguna';
    }
  }

  String _inisial(String? nama) {
    if (nama == null || nama.trim().isEmpty) return '?';
    final parts = nama.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Moderasi'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _muat)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            const WatermarkFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final jumlah = _usulan?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Panel Moderasi', style: AppTypography.headlineMd()),
                const SizedBox(height: 2),
                Text('Tinjau dan kelola usulan perbaikan koordinat.',
                    style: AppTypography.bodyMd(color: Colors.grey.shade600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.pending_actions_rounded, size: 14, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Text('$jumlah', style: AppTypography.bodyLg().copyWith(fontWeight: FontWeight.bold)),
                ]),
                Text('TERTUNDA', style: AppTypography.labelCaps(color: Colors.grey.shade500).copyWith(fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)));
    }
    if (_usulan == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usulan!.isEmpty) {
      return Center(
        child: Text('Tidak ada usulan koreksi yang menunggu peninjauan', style: TextStyle(color: Colors.grey.shade500)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _usulan!.length,
      itemBuilder: (context, i) {
        final k = _usulan![i];
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.emerald.withOpacity(0.15),
                      child: Text(_inisial(k.namaPengusul), style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.namaPengusul ?? 'Anonim', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          Text(
                            '${_labelRole(k.rolePengusul)} • ${_waktuRelatif(k.createdAt)}',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(k.kecamatanNama, style: AppTypography.bodyLg().copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 3),
                    Text('${k.kabupatenNama ?? '-'}, ${k.provinsiNama}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                if (k.catatanPengusul != null) ...[
                  const SizedBox(height: 8),
                  Text('"${k.catatanPengusul}"',
                      style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                ],
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _kotakData(
                      isDark: isDark,
                      judul: 'DATA SAAT INI',
                      icon: Icons.history_rounded,
                      lat: k.latLama, lng: k.lngLama, elevasi: k.elevasiLama,
                      disorot: false,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _kotakData(
                      isDark: isDark,
                      judul: 'DATA USULAN',
                      icon: Icons.check_circle_outline_rounded,
                      lat: k.latBaru, lng: k.lngBaru, elevasi: k.elevasiBaru,
                      disorot: true,
                      latLama: k.latLama, lngLama: k.lngLama, elevasiLama: k.elevasiLama,
                    )),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controllerUntuk(k.id!),
                  decoration: const InputDecoration(
                    hintText: 'Tambahkan catatan evaluasi (opsional)...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _prosesUsulan(k, false),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('TOLAK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _prosesUsulan(k, true),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('SETUJUI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldDark, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kotakData({
    required bool isDark,
    required String judul,
    required IconData icon,
    required double? lat,
    required double? lng,
    required int? elevasi,
    required bool disorot,
    double? latLama,
    double? lngLama,
    int? elevasiLama,
  }) {
    final warnaLatar = disorot
        ? AppColors.emerald.withOpacity(isDark ? 0.18 : 0.1)
        : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03));

    Widget baris(String label, String? nilai, bool berubah) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            Row(
              children: [
                Text(
                  nilai ?? '-',
                  style: AppTypography.dataDisplay(fontSize: 12, color: isDark ? AppColors.textDark : AppColors.textLight)
                      .copyWith(fontWeight: berubah ? FontWeight.bold : FontWeight.normal),
                ),
                if (berubah) const Padding(
                  padding: EdgeInsets.only(left: 3),
                  child: Icon(Icons.arrow_upward_rounded, size: 11, color: AppColors.emerald),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: warnaLatar, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(judul, style: AppTypography.labelCaps(color: Colors.grey.shade600).copyWith(fontSize: 9)),
          ]),
          const SizedBox(height: 4),
          baris('Lintang', lat?.toString(), disorot && lat != latLama),
          baris('Bujur', lng?.toString(), disorot && lng != lngLama),
          baris('Elevasi', elevasi != null ? '$elevasi m' : null, disorot && elevasi != elevasiLama),
        ],
      ),
    );
  }
}
