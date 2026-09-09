import 'package:flutter/material.dart';
import '../services/kalkulator_service.dart';
import '../theme/app_theme.dart';
import '../widgets/home_button.dart';
import 'kalkulator_rashdul_tab.dart';
import 'kalkulator_konversi_tab.dart';

/// Layar "Kalkulator" -- 3 alat bantu falak: Segitiga Bola, Rashdul
/// Kiblat (global & lokal), dan konversi umum (DMS/desimal, Julian Day).
class KalkulatorScreen extends StatefulWidget {
  const KalkulatorScreen({super.key});

  @override
  State<KalkulatorScreen> createState() => _KalkulatorScreenState();
}

class _KalkulatorScreenState extends State<KalkulatorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalkulator'),
        actions: [HomeButton()],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.emerald,
          indicatorColor: AppColors.emerald,
          tabs: const [
            Tab(text: 'Rashdul Kiblat'),
            Tab(text: 'Konversi Umum'),
            Tab(text: 'Segitiga Bola'),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: TabBarView(
              controller: _tabController,
              children: const [
                KalkulatorRashdulTab(),
                KalkulatorKonversiTab(),
                _TabSegitigaBola(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// TAB 1: SEGITIGA BOLA
// =========================================================================

enum _JenisDiketahui { sss, sas, asa, aaa }

class _TabSegitigaBola extends StatefulWidget {
  const _TabSegitigaBola();
  @override
  State<_TabSegitigaBola> createState() => _TabSegitigaBolaState();
}

class _TabSegitigaBolaState extends State<_TabSegitigaBola> {
  _JenisDiketahui _jenis = _JenisDiketahui.sss;
  final _c1 = TextEditingController();
  final _c2 = TextEditingController();
  final _c3 = TextEditingController();
  (double, double, double, double, double, double)? _hasil;
  String? _error;

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  (String, String, String) get _labelInput => switch (_jenis) {
        _JenisDiketahui.sss => ('Sisi a (°)', 'Sisi b (°)', 'Sisi c (°)'),
        _JenisDiketahui.sas => ('Sisi b (°)', 'Sisi c (°)', 'Sudut A apit (°)'),
        _JenisDiketahui.asa => ('Sudut B (°)', 'Sudut C (°)', 'Sisi a apit (°)'),
        _JenisDiketahui.aaa => ('Sudut A (°)', 'Sudut B (°)', 'Sudut C (°)'),
      };

  void _hitung() {
    final v1 = double.tryParse(_c1.text.replaceAll(',', '.'));
    final v2 = double.tryParse(_c2.text.replaceAll(',', '.'));
    final v3 = double.tryParse(_c3.text.replaceAll(',', '.'));
    if (v1 == null || v2 == null || v3 == null) {
      setState(() { _error = 'Isi ketiga nilai dengan angka yang valid.'; _hasil = null; });
      return;
    }
    setState(() {
      _error = null;
      _hasil = switch (_jenis) {
        _JenisDiketahui.sss => KalkulatorService.selesaikanSSS(v1, v2, v3),
        _JenisDiketahui.sas => KalkulatorService.selesaikanSAS(v1, v2, v3),
        _JenisDiketahui.asa => KalkulatorService.selesaikanASA(v1, v2, v3),
        _JenisDiketahui.aaa => KalkulatorService.selesaikanAAA(v1, v2, v3),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final (l1, l2, l3) = _labelInput;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alat bantu klasik ilmu falak: masukkan 3 unsur yang diketahui '
            'dari segitiga bola (sisi a,b,c berhadapan dengan sudut A,B,C), '
            'aplikasi hitung 3 unsur sisanya.',
            style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<_JenisDiketahui>(
            initialValue: _jenis,
            decoration: const InputDecoration(labelText: 'Yang diketahui', isDense: true),
            items: const [
              DropdownMenuItem(value: _JenisDiketahui.sss, child: Text('3 Sisi (SSS)')),
              DropdownMenuItem(value: _JenisDiketahui.sas, child: Text('2 Sisi + Sudut Apit (SAS)')),
              DropdownMenuItem(value: _JenisDiketahui.asa, child: Text('2 Sudut + Sisi Apit (ASA)')),
              DropdownMenuItem(value: _JenisDiketahui.aaa, child: Text('3 Sudut (AAA)')),
            ],
            onChanged: (v) => setState(() { _jenis = v!; _hasil = null; _error = null; }),
          ),
          const SizedBox(height: 14),
          TextField(controller: _c1, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(labelText: l1, isDense: true)),
          const SizedBox(height: 10),
          TextField(controller: _c2, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(labelText: l2, isDense: true)),
          const SizedBox(height: 10),
          TextField(controller: _c3, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(labelText: l3, isDense: true)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _hitung,
            style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
            child: const Text('Hitung'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_hasil != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hasil', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _barisHasil('Sisi a', _hasil!.$1),
                  _barisHasil('Sisi b', _hasil!.$2),
                  _barisHasil('Sisi c', _hasil!.$3),
                  const Divider(height: 16),
                  _barisHasil('Sudut A', _hasil!.$4),
                  _barisHasil('Sudut B', _hasil!.$5),
                  _barisHasil('Sudut C', _hasil!.$6),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _barisHasil(String label, double nilai) {
    final (d, m, s) = KalkulatorService.desimalKeDms(nilai);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text("${nilai.toStringAsFixed(4)}\u00b0  ($d\u00b0 $m' ${s.toStringAsFixed(1)}\")", style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
