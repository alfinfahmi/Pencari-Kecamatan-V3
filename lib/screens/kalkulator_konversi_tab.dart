import 'package:flutter/material.dart';
import '../models/kecamatan_model.dart';
import '../services/kalkulator_service.dart';
import '../services/hijri_service.dart';
import '../services/lokasi_cache_service.dart';
import '../theme/app_theme.dart';
import '../widgets/location_picker_sheet.dart';

const _namaBulanHijriahKonversi = {
  1: 'Muharram', 2: 'Safar', 3: 'Rabiul Awwal', 4: 'Rabiul Akhir',
  5: 'Jumadil Awwal', 6: 'Jumadil Akhir', 7: 'Rajab', 8: "Sya'ban",
  9: 'Ramadhan', 10: 'Syawal', 11: "Dzulqa'dah", 12: 'Dzulhijjah',
};

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

  // --- Masehi <-> Hijriyah ---
  KecamatanModel? _lokasi;
  bool _memuatLokasi = false;
  DateTime _tanggalMasehiUntukHijri = DateTime.now();
  TanggalHijriah? _hasilHijri;
  final _tahunHController = TextEditingController();
  int _bulanHDipilih = 1;
  final _tanggalHController = TextEditingController();
  DateTime? _hasilMasehi;
  String? _errorHijriKeMasehi;

  @override
  void initState() {
    super.initState();
    _lokasi = LokasiCacheService.instance.lokasiCache;
    _muatLokasiDariGps();
  }

  Future<void> _muatLokasiDariGps({bool paksaRefresh = false}) async {
    if (_lokasi == null) setState(() => _memuatLokasi = true);
    try {
      final lokasi = await LokasiCacheService.instance.ambilLokasi(paksaRefresh: paksaRefresh);
      if (mounted && lokasi != null) setState(() => _lokasi = lokasi);
    } finally {
      if (mounted) setState(() => _memuatLokasi = false);
    }
  }

  Future<void> _gantiLokasi() async {
    final terpilih = await LocationPickerSheet.show(context, judul: 'Pilih Lokasi');
    if (terpilih == kPilihGpsSentinel) {
      await _muatLokasiDariGps(paksaRefresh: true);
    } else if (terpilih is KecamatanModel) {
      LokasiCacheService.instance.simpan(terpilih);
      setState(() => _lokasi = terpilih);
    }
  }

  Future<void> _pilihTanggalMasehiUntukHijri() async {
    final terpilih = await showDatePicker(
      context: context, initialDate: _tanggalMasehiUntukHijri,
      firstDate: DateTime(1, 1, 1), lastDate: DateTime(2200),
    );
    if (terpilih != null) setState(() { _tanggalMasehiUntukHijri = terpilih; _hasilHijri = null; });
  }

  void _konversiKeHijri() {
    final lokasi = _lokasi;
    if (lokasi == null || lokasi.utcOffset == null) return;
    setState(() {
      _hasilHijri = HijriService.instance.konversi(
        _tanggalMasehiUntukHijri,
        lat: lokasi.lat, lng: lokasi.lng, utcOffset: lokasi.utcOffset!,
        elevasiM: (lokasi.elevasiM ?? 0).toDouble(),
      );
    });
  }

  void _konversiKeMasehi() {
    final lokasi = _lokasi;
    if (lokasi == null || lokasi.utcOffset == null) return;
    final tahunH = int.tryParse(_tahunHController.text);
    final tanggalH = int.tryParse(_tanggalHController.text);
    if (tahunH == null || tanggalH == null || tanggalH < 1 || tanggalH > 30) {
      setState(() { _errorHijriKeMasehi = 'Isi Tahun H dan Tanggal H dengan angka yang valid (Tanggal H: 1-30).'; _hasilMasehi = null; });
      return;
    }
    setState(() {
      _errorHijriKeMasehi = null;
      final awalBulan = HijriService.tentukanAwalBulan(
        tahunH: tahunH, bulanH: _bulanHDipilih,
        lat: lokasi.lat, lng: lokasi.lng, utcOffset: lokasi.utcOffset!,
        elevasiM: (lokasi.elevasiM ?? 0).toDouble(),
      );
      _hasilMasehi = awalBulan.tanggal1.add(Duration(days: tanggalH - 1));
    });
  }

  @override
  void dispose() {
    _desimalController.dispose();
    _dController.dispose();
    _mController.dispose();
    _sController.dispose();
    _jdController.dispose();
    _tahunHController.dispose();
    _tanggalHController.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final abuSekunder = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final abuTersier = isDark ? Colors.grey.shade500 : Colors.grey.shade500;
    final abuLabel = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
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
                  Icon(Icons.calendar_today_outlined, size: 14, color: abuTersier),
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
                style: TextStyle(fontSize: 11, color: abuTersier),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _kartuSeksi(
            judul: 'Tanggal Masehi \u2194 Hijriyah',
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 13, color: abuTersier),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _lokasi != null ? _lokasi!.kecamatan : (_memuatLokasi ? 'Mengambil lokasi...' : 'Lokasi belum tersedia'),
                      style: TextStyle(fontSize: 12, color: abuLabel),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(onPressed: _memuatLokasi ? null : _gantiLokasi, child: const Text('Ganti', style: TextStyle(fontSize: 12))),
                ],
              ),
              Text(
                'Hasil bergantung lokasi (kriteria hilal/imkan rukyat berbeda tiap tempat) -- '
                'sama seperti mesin hisab utama aplikasi, bukan kalender tabular generik.',
                style: TextStyle(fontSize: 10.5, color: abuTersier),
              ),
              const SizedBox(height: 10),
              Text('Masehi \u2192 Hijriyah', style: TextStyle(fontSize: 11.5, color: abuSekunder, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: abuTersier),
                  const SizedBox(width: 6),
                  Text('${_tanggalMasehiUntukHijri.day}/${_tanggalMasehiUntukHijri.month}/${_tanggalMasehiUntukHijri.year}', style: const TextStyle(fontSize: 13)),
                  const Spacer(),
                  TextButton(onPressed: _pilihTanggalMasehiUntukHijri, child: const Text('Pilih Tanggal', style: TextStyle(fontSize: 12))),
                ],
              ),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: (_lokasi != null && _lokasi!.utcOffset != null) ? _konversiKeHijri : null,
                style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                child: const Text('Ubah ke Hijriyah'),
              ),
              if (_hasilHijri != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.emerald.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${_hasilHijri!.hari} ${_hasilHijri!.namaBulanH} ${_hasilHijri!.tahunH} H'
                    '${_hasilHijri!.istikmal ? ' (istikmal)' : ''}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.emerald),
                  ),
                ),
              ],
              const Divider(height: 24),
              Text('Hijriyah \u2192 Masehi', style: TextStyle(fontSize: 11.5, color: abuSekunder, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _tahunHController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tahun H', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      initialValue: _bulanHDipilih,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Bulan H', isDense: true),
                      items: _namaBulanHijriahKonversi.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setState(() => _bulanHDipilih = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _tanggalHController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tgl H', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: (_lokasi != null && _lokasi!.utcOffset != null) ? _konversiKeMasehi : null,
                style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
                child: const Text('Ubah ke Masehi'),
              ),
              if (_errorHijriKeMasehi != null) ...[
                const SizedBox(height: 8),
                Text(_errorHijriKeMasehi!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
              if (_hasilMasehi != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.emerald.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${_hasilMasehi!.day}/${_hasilMasehi!.month}/${_hasilMasehi!.year} M',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.emerald),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _kartuSeksi({required String judul, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08)),
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
