import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/custom_point_model.dart';
import '../models/kecamatan_model.dart';
import '../services/custom_point_service.dart';
import '../theme/app_theme.dart';
import '../widgets/watermark_footer.dart';

class AddPointScreen extends StatefulWidget {
  final KecamatanModel induk;
  const AddPointScreen({super.key, required this.induk});

  @override
  State<AddPointScreen> createState() => _AddPointScreenState();
}

class _AddPointScreenState extends State<AddPointScreen> {
  final _namaController = TextEditingController();
  final _catatanController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _elevasiController = TextEditingController();
  TitikTipe _tipe = TitikTipe.masjid;
  bool _loadingGps = false;
  bool _saving = false;

  final _service = CustomPointService();

  Future<void> _ambilLokasiGps() async {
    setState(() => _loadingGps = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      _latController.text = pos.latitude.toStringAsFixed(7);
      _lngController.text = pos.longitude.toStringAsFixed(7);
      // Elevasi diisi otomatis dari GPS, tapi field tetap bisa diedit manual
      // (GPS altitude akurasinya kasar, jadi pengguna perlu bisa mengoreksi).
      if (pos.altitude != 0) {
        _elevasiController.text = pos.altitude.round().toString();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil lokasi GPS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingGps = false);
    }
  }

  Future<void> _simpan() async {
    if (_namaController.text.trim().isEmpty ||
        _latController.text.trim().isEmpty ||
        _lngController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama, latitude, dan longitude wajib diisi')),
      );
      return;
    }

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format koordinat tidak valid')),
      );
      return;
    }

    setState(() => _saving = true);

    final point = CustomPointModel(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      nama: _namaController.text.trim(),
      tipe: _tipe.name,
      kecamatanId: widget.induk.id,
      kecamatanNama: widget.induk.kecamatan,
      kabupatenNama: widget.induk.kabupaten,
      provinsiNama: widget.induk.provinsi,
      lat: lat,
      lng: lng,
      elevasiM: int.tryParse(_elevasiController.text.trim()),
      catatan: _catatanController.text.trim().isEmpty ? null : _catatanController.text.trim(),
      tanggalDibuat: DateTime.now().toIso8601String(),
    );

    await _service.add(point);

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(point);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Titik kustom berhasil disimpan')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Titik Kustom')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: AppColors.emerald.withOpacity(0.06),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hierarki (otomatis)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          const SizedBox(height: 6),
                          Text('${widget.induk.kecamatan} → ${widget.induk.kabupaten ?? '-'} → ${widget.induk.provinsi}',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _namaController,
                    decoration: const InputDecoration(labelText: 'Nama Lokasi', hintText: 'Contoh: Masjid Al-Ikhlas'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TitikTipe>(
                    initialValue: _tipe,
                    decoration: const InputDecoration(labelText: 'Tipe'),
                    items: TitikTipe.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(_labelTipe(t))))
                        .toList(),
                    onChanged: (v) => setState(() => _tipe = v ?? TitikTipe.masjid),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                          decoration: const InputDecoration(labelText: 'Latitude'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                          decoration: const InputDecoration(labelText: 'Longitude'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _loadingGps ? null : _ambilLokasiGps,
                    icon: _loadingGps
                        ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Ambil dari GPS Perangkat'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _elevasiController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Elevasi (mdpl) — opsional'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _catatanController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Catatan — opsional'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _simpan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan Titik'),
                ),
              ),
            ),
            const WatermarkFooter(),
          ],
        ),
      ),
    );
  }

  String _labelTipe(TitikTipe t) {
    switch (t) {
      case TitikTipe.desa:
        return 'Desa';
      case TitikTipe.dusun:
        return 'Dusun';
      case TitikTipe.masjid:
        return 'Masjid';
      case TitikTipe.lainnya:
        return 'Lainnya';
    }
  }
}
