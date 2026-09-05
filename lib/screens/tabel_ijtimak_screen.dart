import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../theme/app_theme.dart';
import '../widgets/watermark_footer.dart';
import '../widgets/home_button.dart';

/// Menampilkan tabel ijtimak akhir bulan resmi Lajnah Falakiyah Ma'had
/// 'Aly Lirboyo (1440H-1500H, 732 entri) sebagai referensi. MURNI untuk
/// dilihat -- TIDAK dipakai sebagai sumber perhitungan aplikasi (mesin
/// hisab Hijriah aplikasi ini memakai rumus live terpisah), jadi kedua
/// angka bisa saja berbeda beberapa menit karena metode hitung berbeda
/// meski sama-sama sahih.
class TabelIjtimakScreen extends StatefulWidget {
  const TabelIjtimakScreen({super.key});

  @override
  State<TabelIjtimakScreen> createState() => _TabelIjtimakScreenState();
}

class _TabelIjtimakScreenState extends State<TabelIjtimakScreen> {
  Map<int, List<Map<String, dynamic>>>? _perTahun;
  String? _error;
  int? _tahunSekarangPerkiraan;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final raw = await rootBundle.loadString('assets/data/tabel_ijtimak.json');
      final jsonMap = json.decode(raw) as Map<String, dynamic>;
      final data = (jsonMap['data'] as List).cast<Map<String, dynamic>>();

      final perTahun = <int, List<Map<String, dynamic>>>{};
      for (final entry in data) {
        final tahun = entry['tahun_h'] as int;
        perTahun.putIfAbsent(tahun, () => []).add(entry);
      }

      final now = DateTime.now();
      int? tahunSekarang;
      for (final entry in data) {
        final tgl = DateTime.parse(entry['ijtimak_wib'] as String);
        if (tgl.isAfter(now)) {
          tahunSekarang = entry['tahun_h'] as int;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _perTahun = perTahun;
          _tahunSekarangPerkiraan = tahunSekarang;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat tabel ijtimak: $e');
    }
  }

  String _formatTanggalJam(String iso) {
    final dt = DateTime.parse(iso);
    const bulan = {
      1: 'Jan', 2: 'Feb', 3: 'Mar', 4: 'Apr', 5: 'Mei', 6: 'Jun',
      7: 'Jul', 8: 'Agu', 9: 'Sep', 10: 'Okt', 11: 'Nov', 12: 'Des',
    };
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${bulan[dt.month]} ${dt.year}, $jam.$menit WIB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabel Ijtimak'),
        actions: [HomeButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emerald.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.emerald),
                      const SizedBox(width: 6),
                      Text('Tabel Ijtimak 1440H-1500H',
                          style: AppTypography.bodyLg(color: AppColors.emerald).copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Data resmi Lajnah Falakiyah Ma'had 'Aly Lirboyo. Murni referensi -- "
                    'perhitungan Hijriah aplikasi ini (badge tanggal, jadwal shalat) memakai '
                    'rumus live terpisah, jadi bisa berbeda beberapa menit dari tabel ini '
                    '(sama-sama sahih, cuma metode berbeda).',
                    style: AppTypography.captionEdu(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
            const WatermarkFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    if (_perTahun == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final tahunList = _perTahun!.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: tahunList.length,
      itemBuilder: (context, index) {
        final tahun = tahunList[index];
        final entries = _perTahun![tahun]!..sort((a, b) => (a['bulan_h'] as int).compareTo(b['bulan_h'] as int));
        final iniTahunSekarang = tahun == _tahunSekarangPerkiraan;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            initiallyExpanded: iniTahunSekarang,
            title: Row(
              children: [
                Text('$tahun H', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (iniTahunSekarang) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.85), borderRadius: BorderRadius.circular(9999)),
                    child: const Text('Sekarang', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            children: entries.map((e) {
              return ListTile(
                dense: true,
                leading: SizedBox(
                  width: 28,
                  child: Text('${e['bulan_h']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ),
                title: Text(e['nama_bulan_h'] as String, style: const TextStyle(fontSize: 13.5)),
                subtitle: Text(
                  '${_formatTanggalJam(e['ijtimak_wib'] as String)} \u2022 ${e['hari_pasaran']}',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
