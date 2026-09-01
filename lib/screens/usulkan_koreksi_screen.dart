import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/kecamatan_model.dart';
import '../models/koreksi_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';

class UsulkanKoreksiScreen extends StatefulWidget {
  final KecamatanModel data;
  const UsulkanKoreksiScreen({super.key, required this.data});

  @override
  State<UsulkanKoreksiScreen> createState() => _UsulkanKoreksiScreenState();
}

class _UsulkanKoreksiScreenState extends State<UsulkanKoreksiScreen> {
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _elevasiController;
  final _catatanController = TextEditingController();
  bool _saving = false;
  bool _loadingGps = false;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(text: widget.data.lat.toString());
    _lngController = TextEditingController(text: widget.data.lng.toString());
    _elevasiController = TextEditingController(text: widget.data.elevasiM?.toString() ?? '');
  }

  /// Mengambil koordinat GPS perangkat saat ini dan mengisi field
  /// latitude/longitude secara otomatis -- berguna saat pengusul benar-benar
  /// berada di lokasi yang datanya ingin dikoreksi.
  Future<void> _ambilLokasiGps() async {
    setState(() => _loadingGps = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak — tidak bisa mengambil GPS')),
          );
        }
        return;
      }

      final layananAktif = await Geolocator.isLocationServiceEnabled();
      if (!layananAktif) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aktifkan layanan lokasi (GPS) di perangkat Anda')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      _latController.text = pos.latitude.toStringAsFixed(7);
      _lngController.text = pos.longitude.toStringAsFixed(7);
      if (pos.altitude != 0) {
        _elevasiController.text = pos.altitude.round().toString();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koordinat GPS berhasil diambil')),
        );
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

  Future<void> _kirim() async {
    if (!SupabaseService.instance.isLoggedIn) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      if (result != true) return;
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

    final koreksi = KoreksiModel(
      kecamatanId: widget.data.id,
      kecamatanNama: widget.data.kecamatan,
      kabupatenNama: widget.data.kabupaten,
      provinsiNama: widget.data.provinsi,
      latLama: widget.data.lat,
      lngLama: widget.data.lng,
      elevasiLama: widget.data.elevasiM,
      latBaru: lat,
      lngBaru: lng,
      elevasiBaru: int.tryParse(_elevasiController.text.trim()),
      catatanPengusul: _catatanController.text.trim().isEmpty ? null : _catatanController.text.trim(),
    );

    final terkirimLangsung = await SupabaseService.instance.kirimKoreksi(koreksi);

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(terkirimLangsung
          ? 'Usulan koreksi terkirim, menunggu peninjauan.'
          : 'Anda sedang offline — usulan disimpan lokal, akan otomatis terkirim saat online.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usulkan Koreksi Data')),
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
                          Text(widget.data.kecamatan, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${widget.data.kabupaten ?? '-'}, ${widget.data.provinsi}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                          const Divider(height: 16),
                          Text('Data saat ini: ${widget.data.lat}, ${widget.data.lng}'
                              '${widget.data.elevasiM != null ? ' • ${widget.data.elevasiM} mdpl' : ''}',
                              style: const TextStyle(fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Data yang diusulkan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                          decoration: const InputDecoration(labelText: 'Latitude Baru'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                          decoration: const InputDecoration(labelText: 'Longitude Baru'),
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
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.emerald, side: const BorderSide(color: AppColors.emerald)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _elevasiController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Elevasi Baru (mdpl) — opsional'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _catatanController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Catatan / Sumber Data',
                      hintText: 'mis. hasil pengukuran GPS lapangan tanggal ...',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _kirim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Kirim Usulan Koreksi'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
