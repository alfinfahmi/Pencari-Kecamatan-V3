import 'package:flutter/material.dart';
import '../services/kalkulator_service.dart';
import '../theme/app_theme.dart';

class KalkulatorKonversiTab extends StatefulWidget {
  const KalkulatorKonversiTab({super.key});
  @override
  State<KalkulatorKonversiTab> createState() => _KalkulatorKonversiTabState();
}

class _KalkulatorKonversiTabState extends State<KalkulatorKonversiTab> {
  // --- DMS <-> Desimal ---
  final _desimalController = TextEditingController();
  final _dController = TextEditingController();
  final _mController = TextEditingController();
  final _sController = TextEditingController();

  // --- Julian Day <-> Tanggal ---
  DateTime _tanggalUntukJd = DateTime.now();
  final _jdController = TextEditingController();

  @override
  void dispose() {
    _desimalController.dispose();
    _dController.dispose();
    _mController.dispose();
    _sController.dispose();
    _jdController.dispose();
    super.dispose();
  }

  void _desimalKeDms() {
    final v = double.tryParse(_desimalController.text.replaceAll(',', '.'));
    if (v == null) return;
    final (d, m, s) = KalkulatorService.desimalKeDms(v);
    setState(() {
      _dController.text = d.toString();
      _mController.text = m.toString();
      _sController.text = s.toStringAsFixed(2);
    });
  }

  void _dmsKeDesimal() {
    final d = int.tryParse(_dController.text);
    final m = int.tryParse(_mController.text);
    final s = double.tryParse(_sController.text.replaceAll(',', '.'));
    if (d == null || m == null || s == null) return;
    final v = KalkulatorService.dmsKeDesimal(d, m, s);
    setState(() => _desimalController.text = v.toStringAsFixed(6));
  }

  Future<void> _pilihTanggalJd() async {
    final terpilih = await showDatePicker(
      context: context, initialDate: _tanggalUntukJd,
      firstDate: DateTime(1, 1, 1), lastDate: DateTime(2200),
    );
    if (terpilih != null) {
      setState(() {
        _tanggalUntukJd = terpilih;
        _jdController.text = KalkulatorService.julianDay(terpilih).toStringAsFixed(4);
      });
    }
  }

  void _jdKeTanggal() {
    final jd = double.tryParse(_jdController.text.replaceAll(',', '.'));
    if (jd == null) return;
    setState(() => _tanggalUntukJd = KalkulatorService.julianDayKeTanggal(jd));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kartuSeksi(
            judul: 'Derajat Desimal \u2194 DMS',
            children: [
              TextField(
                controller: _desimalController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Derajat desimal', isDense: true),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _desimalKeDms,
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  label: const Text('Ubah ke DMS'),
                ),
              ),
              Row(
                children: [
                  Expanded(child: TextField(controller: _dController, keyboardType: const TextInputType.numberWithOptions(signed: true), decoration: const InputDecoration(labelText: 'Derajat', isDense: true))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _mController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Menit', isDense: true))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _sController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Detik', isDense: true))),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _dmsKeDesimal,
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: const Text('Ubah ke Desimal'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _kartuSeksi(
            judul: 'Tanggal Masehi \u2194 Julian Day',
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text('${_tanggalUntukJd.day}/${_tanggalUntukJd.month}/${_tanggalUntukJd.year} 00:00 UTC', style: const TextStyle(fontSize: 13)),
                  const Spacer(),
                  TextButton(onPressed: _pilihTanggalJd, child: const Text('Pilih Tanggal', style: TextStyle(fontSize: 12))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _jdController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Julian Day', isDense: true),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _jdKeTanggal,
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: const Text('Ubah Julian Day ke Tanggal'),
                ),
              ),
              Text(
                'Julian Day dihitung untuk jam 00:00 UTC pada tanggal tersebut.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kartuSeksi({required String judul, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emerald)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
