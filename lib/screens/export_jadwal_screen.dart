import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/kecamatan_model.dart';
import '../services/hisab_service.dart';
import '../services/hijri_service.dart';
import '../services/prayer_settings_service.dart';
import '../theme/app_theme.dart';

enum _ModeRentang { masehi, hijriah }
enum _TampilanTanggal { masehi, hijriah, keduanya }

const _namaBulanHijriah = {
  1: 'Muharram', 2: 'Safar', 3: 'Rabiul Awwal', 4: 'Rabiul Akhir',
  5: 'Jumadil Awwal', 6: 'Jumadil Akhir', 7: 'Rajab', 8: "Sya'ban",
  9: 'Ramadhan', 10: 'Syawal', 11: "Dzulqa'dah", 12: 'Dzulhijjah',
};
const _namaBulanMasehi = {
  1: 'Januari', 2: 'Februari', 3: 'Maret', 4: 'April', 5: 'Mei', 6: 'Juni',
  7: 'Juli', 8: 'Agustus', 9: 'September', 10: 'Oktober', 11: 'November', 12: 'Desember',
};

class ExportJadwalScreen extends StatefulWidget {
  final KecamatanModel data;
  const ExportJadwalScreen({super.key, required this.data});

  @override
  State<ExportJadwalScreen> createState() => _ExportJadwalScreenState();
}

class _ExportJadwalScreenState extends State<ExportJadwalScreen> {
  final _prayerSettings = PrayerSettingsService();

  _ModeRentang _mode = _ModeRentang.masehi;
  _TampilanTanggal _tampilan = _TampilanTanggal.keduanya;

  DateTime _masehiMulai = DateTime.now();
  DateTime _masehiSelesai = DateTime.now().add(const Duration(days: 6));

  int _hTahunMulai = 1448, _hBulanMulai = 1, _hTanggalMulai = 1;
  int _hTahunSelesai = 1448, _hBulanSelesai = 1, _hTanggalSelesai = 7;

  bool _memproses = false;

  Future<void> _pilihTanggalMasehi(bool mulai) async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: mulai ? _masehiMulai : _masehiSelesai,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (hasil != null) {
      setState(() {
        if (mulai) {
          _masehiMulai = hasil;
        } else {
          _masehiSelesai = hasil;
        }
      });
    }
  }

  DateTime _hijriahKeMasehi(int tahunH, int bulanH, int tanggalH) {
    final awal = HijriService.tentukanAwalBulan(
      tahunH: tahunH,
      bulanH: bulanH,
      lat: widget.data.lat,
      lng: widget.data.lng,
      utcOffset: widget.data.utcOffset ?? 7,
    );
    return awal.tanggal1.add(Duration(days: tanggalH - 1));
  }

  Future<void> _buatPdf() async {
    final data = widget.data;
    if (data.utcOffset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zona waktu tidak tersedia untuk lokasi ini.')),
      );
      return;
    }

    setState(() => _memproses = true);

    final tglMulai = _mode == _ModeRentang.masehi
        ? DateTime(_masehiMulai.year, _masehiMulai.month, _masehiMulai.day)
        : _hijriahKeMasehi(_hTahunMulai, _hBulanMulai, _hTanggalMulai);
    final tglSelesai = _mode == _ModeRentang.masehi
        ? DateTime(_masehiSelesai.year, _masehiSelesai.month, _masehiSelesai.day)
        : _hijriahKeMasehi(_hTahunSelesai, _hBulanSelesai, _hTanggalSelesai);

    if (tglSelesai.isBefore(tglMulai)) {
      setState(() => _memproses = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tanggal selesai harus setelah tanggal mulai.')),
        );
      }
      return;
    }
    final jumlahHari = tglSelesai.difference(tglMulai).inDays + 1;
    if (jumlahHari > 100) {
      setState(() => _memproses = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rentang maksimal 100 hari per ekspor (supaya PDF tidak terlalu besar).')),
        );
      }
      return;
    }

    final ihtiyath = await _prayerSettings.getIhtiyath();
    final sudutIsya = await _prayerSettings.getSudutIsya();
    final sudutSubuh = await _prayerSettings.getSudutSubuh();

    final baris = <List<String>>[];
    for (int i = 0; i < jumlahHari; i++) {
      final tgl = tglMulai.add(Duration(days: i));
      final waktu = HisabService.hitung(
        tanggal: tgl,
        lat: data.lat,
        lng: data.lng,
        elevasiM: (data.elevasiM ?? 0).toDouble(),
        utcOffset: data.utcOffset!,
        sudutIsya: sudutIsya,
        sudutSubuh: sudutSubuh,
        ihtiyathMenit: ihtiyath,
      );

      String labelTanggal = _formatLabelTanggal(tgl, data);
      String fmt(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

      baris.add([
        labelTanggal,
        fmt(waktu[0].waktuDaerah), // Imsak
        fmt(waktu[1].waktuDaerah), // Subuh
        fmt(waktu[2].waktuDaerah), // Terbit
        fmt(waktu[3].waktuDaerah), // Dhuha
        fmt(waktu[4].waktuDaerah), // Dhuhur
        fmt(waktu[5].waktuDaerah), // Ashar
        fmt(waktu[6].waktuDaerah), // Maghrib
        fmt(waktu[7].waktuDaerah), // Isya
      ]);
    }

    final pdfBytes = await _generatePdf(baris, data);

    setState(() => _memproses = false);
    if (!mounted) return;
    await Printing.sharePdf(bytes: pdfBytes, filename: 'jadwal_shalat_${data.kecamatan}.pdf');
  }

  String _formatLabelTanggal(DateTime tgl, KecamatanModel data) {
    const namaHari = {1: 'Sen', 2: 'Sel', 3: 'Rab', 4: 'Kam', 5: 'Jum', 6: 'Sab', 7: 'Ahad'};
    final labelMasehi = '${namaHari[tgl.weekday]}, ${tgl.day} ${_namaBulanMasehi[tgl.month]} ${tgl.year}';

    if (_tampilan == _TampilanTanggal.masehi) return labelMasehi;

    final hijri = HijriService.instance.konversi(tgl, lat: data.lat, lng: data.lng, utcOffset: data.utcOffset!);
    final labelHijri = '${hijri.hari} ${hijri.namaBulanH} ${hijri.tahunH} H';

    if (_tampilan == _TampilanTanggal.hijriah) return labelHijri;
    return '$labelMasehi\n$labelHijri'; // keduanya
  }

  Future<Uint8List> _generatePdf(List<List<String>> baris, KecamatanModel data) async {
    final doc = pw.Document();
    const headers = ['Tanggal', 'Imsak', 'Subuh', 'Terbit', 'Dhuha', 'Dzuhur', 'Ashar', 'Maghrib', "Isya'"];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Jadwal Waktu Shalat', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(
              '${data.kecamatan}${data.kabupaten != null ? ', ${data.kabupaten}' : ''}, ${data.provinsi}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Koordinat: ${data.lat}, ${data.lng}  |  Elevasi: ${data.elevasiM ?? 0} m  |  Zona: ${data.zonaWaktu ?? '-'}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(),
            pw.Text(
              "LF Ma'had 'Aly Lirboyo — MHM Kediri  |  Perkiraan hisab, validasi lanjut direkomendasikan sebelum dipakai operasional.",
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text('Halaman ${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
          ],
        ),
        build: (context) => [
          pw.Table.fromTextArray(
            headers: headers,
            data: baris,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor(13 / 255, 92 / 255, 58 / 255)),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {0: pw.Alignment.centerLeft},
            columnWidths: {0: const pw.FlexColumnWidth(2.4)},
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          ),
        ],
      ),
    );

    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ekspor Jadwal Shalat')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.data.kecamatan, style: AppTypography.headlineMd()),
            Text('${widget.data.kabupaten ?? '-'}, ${widget.data.provinsi}',
                style: AppTypography.bodyMd(color: Colors.grey.shade600)),
            const SizedBox(height: 20),

            const Text('Mode Rentang Tanggal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            SegmentedButton<_ModeRentang>(
              segments: const [
                ButtonSegment(value: _ModeRentang.masehi, label: Text('Masehi')),
                ButtonSegment(value: _ModeRentang.hijriah, label: Text('Hijriah')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),

            if (_mode == _ModeRentang.masehi) ..._buildInputMasehi() else ..._buildInputHijriah(),

            const SizedBox(height: 20),
            const Text('Tampilkan Tanggal Sebagai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            SegmentedButton<_TampilanTanggal>(
              segments: const [
                ButtonSegment(value: _TampilanTanggal.masehi, label: Text('Masehi')),
                ButtonSegment(value: _TampilanTanggal.hijriah, label: Text('Hijriah')),
                ButtonSegment(value: _TampilanTanggal.keduanya, label: Text('Keduanya')),
              ],
              selected: {_tampilan},
              onSelectionChanged: (s) => setState(() => _tampilan = s.first),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _memproses ? null : _buatPdf,
                icon: _memproses
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(_memproses ? 'Membuat PDF...' : 'Buat & Bagikan PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Maksimal 100 hari per ekspor. Perhitungan otomatis, validasi lanjut direkomendasikan.',
              style: AppTypography.captionEdu(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildInputMasehi() {
    String fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
    return [
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pilihTanggalMasehi(true),
              child: Text('Mulai: ${fmt(_masehiMulai)}'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pilihTanggalMasehi(false),
              child: Text('Selesai: ${fmt(_masehiSelesai)}'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildInputHijriah() {
    return [
      const Text('Tanggal Mulai (Hijriah)', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 6),
      _hijriahRow(
        tanggal: _hTanggalMulai, bulan: _hBulanMulai, tahun: _hTahunMulai,
        onTanggal: (v) => setState(() => _hTanggalMulai = v),
        onBulan: (v) => setState(() => _hBulanMulai = v),
        onTahun: (v) => setState(() => _hTahunMulai = v),
      ),
      const SizedBox(height: 16),
      const Text('Tanggal Selesai (Hijriah)', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 6),
      _hijriahRow(
        tanggal: _hTanggalSelesai, bulan: _hBulanSelesai, tahun: _hTahunSelesai,
        onTanggal: (v) => setState(() => _hTanggalSelesai = v),
        onBulan: (v) => setState(() => _hBulanSelesai = v),
        onTahun: (v) => setState(() => _hTahunSelesai = v),
      ),
    ];
  }

  Widget _hijriahRow({
    required int tanggal,
    required int bulan,
    required int tahun,
    required ValueChanged<int> onTanggal,
    required ValueChanged<int> onBulan,
    required ValueChanged<int> onTahun,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int>(
            initialValue: tanggal,
            decoration: const InputDecoration(labelText: 'Tgl', isDense: true),
            items: List.generate(30, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
            onChanged: (v) => onTanggal(v ?? tanggal),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<int>(
            initialValue: bulan,
            decoration: const InputDecoration(labelText: 'Bulan', isDense: true),
            items: _namaBulanHijriah.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => onBulan(v ?? bulan),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextFormField(
            initialValue: '$tahun',
            decoration: const InputDecoration(labelText: 'Tahun H', isDense: true),
            keyboardType: TextInputType.number,
            onChanged: (v) => onTahun(int.tryParse(v) ?? tahun),
          ),
        ),
      ],
    );
  }
}
