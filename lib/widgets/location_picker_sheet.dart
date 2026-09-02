import 'package:flutter/material.dart';
import '../models/kecamatan_model.dart';
import '../services/app_data_service.dart';
import '../theme/app_theme.dart';

/// Sentinel dikembalikan saat pengguna memilih "Gunakan Lokasi GPS",
/// dibedakan dari null (dismiss tanpa memilih apa pun) dan dari
/// KecamatanModel (memilih lokasi tertentu lewat pencarian).
const kPilihGpsSentinel = 'GUNAKAN_GPS';

/// Bottom sheet untuk memilih lokasi: cari kecamatan ATAU pakai GPS
/// perangkat langsung. Dipakai di widget waktu shalat Home dan layar
/// Ekspor Jadwal Shalat -- satu komponen, satu pengalaman konsisten.
///
/// Mengembalikan salah satu dari: `null` (dibatalkan), [kPilihGpsSentinel]
/// (String, kalau pengguna pilih GPS), atau [KecamatanModel] (kalau
/// pengguna pilih hasil pencarian).
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key, this.judul = 'Pilih Lokasi'});

  final String judul;

  static Future<Object?> show(BuildContext context, {String judul = 'Pilih Lokasi'}) {
    return showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (context) => LocationPickerSheet(judul: judul),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _controller = TextEditingController();
  List<KecamatanModel> _hasil = [];
  bool _mencari = false;

  Future<void> _cari(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _hasil = []);
      return;
    }
    setState(() => _mencari = true);
    final hasil = await AppDataService.instance.search(query, limit: 20);
    if (mounted) setState(() { _hasil = hasil; _mencari = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(kPilihGpsSentinel),
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('Gunakan Lokasi GPS Perangkat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.emerald,
                    side: const BorderSide(color: AppColors.emerald),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('atau cari alamat', style: TextStyle(fontSize: 11, color: Colors.grey))),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: false,
                  onChanged: _cari,
                  decoration: InputDecoration(
                    hintText: 'Cari kecamatan, kabupaten...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _mencari
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _hasil.length,
                    itemBuilder: (context, i) {
                      final item = _hasil[i];
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(item.kecamatan),
                        subtitle: Text('${item.kabupaten ?? '-'}, ${item.provinsi}'),
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
