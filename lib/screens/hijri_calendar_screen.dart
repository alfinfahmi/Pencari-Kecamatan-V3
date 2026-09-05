import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/kecamatan_model.dart';
import '../services/hijri_service.dart';
import '../services/reverse_geocode_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/watermark_footer.dart';
import '../widgets/home_button.dart';
import '../widgets/location_picker_sheet.dart';

/// Kalender dua sistem (Hijriah & Masehi) -- navigasi per bulan Masehi,
/// tiap hari otomatis menampilkan tanggal Hijriah yang sepadan (dihitung
/// dari HijriService, mesin hisab live yang sama dipakai di seluruh
/// aplikasi).
///
/// CATATAN JUJUR: hari-hari penting yang ditandai di sini (Maulid, Isra
/// Mi'raj, dst.) TETAP tanggalnya secara hisab urutan hari dalam bulan
/// Hijriah -- BEDA dari awal Ramadhan/Syawal/Dzulhijjah yang butuh
/// penetapan resmi (sidang isbat/rukyat). Semua tanggal Hijriah di
/// kalender ini tetap PERKIRAAN hisab (bisa berbeda 1 hari dari
/// penetapan resmi), sama seperti fitur Hijriah lain di aplikasi ini.
class HijriCalendarScreen extends StatefulWidget {
  const HijriCalendarScreen({super.key});

  @override
  State<HijriCalendarScreen> createState() => _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends State<HijriCalendarScreen> {
  KecamatanModel? _lokasi;
  bool _memuatLokasi = false;
  DateTime _bulanTampil = DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const _namaBulanMasehi = {
    1: 'Januari', 2: 'Februari', 3: 'Maret', 4: 'April', 5: 'Mei', 6: 'Juni',
    7: 'Juli', 8: 'Agustus', 9: 'September', 10: 'Oktober', 11: 'November', 12: 'Desember',
  };
  static const _namaHariSingkat = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Ahad'];

  /// Hari-hari penting yang tanggal hisabnya TETAP (urutan hari dalam
  /// bulan Hijriah), BUKAN yang butuh penetapan resmi.
  static const _hariPenting = {
    (1, 1): 'Tahun Baru Islam',
    (1, 10): 'Hari Asyura',
    (3, 12): 'Maulid Nabi Muhammad SAW',
    (7, 27): "Isra Mi'raj",
    (9, 17): 'Nuzulul Quran',
    (12, 9): 'Hari Arafah',
  };

  @override
  void initState() {
    super.initState();
    _muatLokasiDariGps();
  }

  Future<void> _muatLokasiDariGps() async {
    setState(() => _memuatLokasi = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final pos = await Geolocator.getCurrentPosition();
      final utcOffsetJam = DateTime.now().timeZoneOffset.inHours;
      final namaZona = switch (utcOffsetJam) {
        7 => 'WIB',
        8 => 'WITA',
        9 => 'WIT',
        _ => 'UTC${utcOffsetJam >= 0 ? '+' : ''}$utcOffsetJam',
      };
      final lokasi = await lengkapiInfoLokasiGps(
        lat: pos.latitude,
        lng: pos.longitude,
        elevasiM: pos.altitude > 0 ? pos.altitude.round() : 0,
        zonaWaktu: namaZona,
        utcOffset: utcOffsetJam,
      );
      if (mounted) setState(() => _lokasi = lokasi);
    } catch (_) {
      // Diamkan -- kalender tetap tampil (kolom Hijriah kosong) kalau
      // lokasi gagal didapat.
    } finally {
      if (mounted) setState(() => _memuatLokasi = false);
    }
  }

  Future<void> _gantiLokasi() async {
    final terpilih = await LocationPickerSheet.show(context, judul: 'Pilih Lokasi untuk Kalender');
    if (terpilih == kPilihGpsSentinel) {
      await _muatLokasiDariGps();
    } else if (terpilih is KecamatanModel) {
      setState(() => _lokasi = terpilih);
    }
  }

  void _gantiBulan(int delta) {
    setState(() {
      _bulanTampil = DateTime(_bulanTampil.year, _bulanTampil.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender Hijriah & Masehi'),
        actions: [HomeButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildBarisLokasi(),
            _buildNavigasiBulan(),
            const Divider(height: 1),
            Expanded(child: _buildGridKalender()),
            _buildCatatan(),
            const WatermarkFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBarisLokasi() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: _memuatLokasi
                ? Text('Mengambil lokasi...', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500))
                : Text(
                    _lokasi != null ? _lokasi!.kecamatan : 'Lokasi belum tersedia',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                  ),
          ),
          TextButton(
            onPressed: _memuatLokasi ? null : _gantiLokasi,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
            child: const Text('Ganti Lokasi', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigasiBulan() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _gantiBulan(-1)),
          Text(
            '${_namaBulanMasehi[_bulanTampil.month]} ${_bulanTampil.year}',
            style: AppTypography.headlineMd(),
          ),
          IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _gantiBulan(1)),
        ],
      ),
    );
  }

  Widget _buildGridKalender() {
    final lokasi = _lokasi;
    final jumlahHari = DateTime(_bulanTampil.year, _bulanTampil.month + 1, 0).day;
    final hari1 = DateTime(_bulanTampil.year, _bulanTampil.month, 1);
    final offsetAwal = hari1.weekday - 1;
    final now = DateTime.now();

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: _namaHariSingkat
                .map((h) => Expanded(
                      child: Center(
                        child: Text(h, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.grey.shade600)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.78),
            itemCount: offsetAwal + jumlahHari,
            itemBuilder: (context, index) {
              if (index < offsetAwal) return const SizedBox.shrink();
              final tanggalMasehi = DateTime(_bulanTampil.year, _bulanTampil.month, index - offsetAwal + 1);
              final iniHariIni = tanggalMasehi.year == now.year && tanggalMasehi.month == now.month && tanggalMasehi.day == now.day;

              TanggalHijriah? hijri;
              String? namaPenting;
              if (lokasi != null && lokasi.utcOffset != null) {
                hijri = HijriService.instance.konversi(tanggalMasehi, lat: lokasi.lat, lng: lokasi.lng, utcOffset: lokasi.utcOffset!);
                namaPenting = _hariPenting[(hijri.bulanH, hijri.hari)];
              }

              return InkWell(
                onTap: () => _tampilkanDetailHari(tanggalMasehi, hijri, namaPenting),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: iniHariIni ? AppColors.emerald.withOpacity(0.15) : null,
                    borderRadius: BorderRadius.circular(8),
                    border: iniHariIni ? Border.all(color: AppColors.emerald) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${tanggalMasehi.day}',
                        style: TextStyle(
                          fontWeight: iniHariIni ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                          color: iniHariIni ? AppColors.emeraldDark : null,
                        ),
                      ),
                      if (hijri != null)
                        Text('${hijri.hari}', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                      if (namaPenting != null)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 5, height: 5,
                          decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _tampilkanDetailHari(DateTime tanggalMasehi, TanggalHijriah? hijri, String? namaPenting) {
    const namaHari = {1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis', 5: 'Jumat', 6: 'Sabtu', 7: 'Ahad'};
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${namaHari[tanggalMasehi.weekday]}, ${tanggalMasehi.day} ${_namaBulanMasehi[tanggalMasehi.month]} ${tanggalMasehi.year}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            if (hijri != null)
              Text(hijri.label, style: AppTypography.bodyLg(color: AppColors.emerald))
            else
              Text('Tanggal Hijriah tidak tersedia (lokasi belum dipilih)', style: TextStyle(color: Colors.grey.shade500)),
            if (namaPenting != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text(namaPenting, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Tanggal Hijriah perkiraan hisab, bisa berbeda 1 hari dari penetapan resmi.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatatan() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Text(
        '\u2022 Tanda kuning: hari penting dengan tanggal hisab tetap (Maulid, Isra Mi\'raj, dst.). '
        'Awal Ramadhan/Syawal/Dzulhijjah TIDAK ditandai di sini karena butuh penetapan resmi.\n'
        '\u2022 Semua tanggal Hijriah adalah perkiraan hisab, bisa berbeda 1 hari dari sidang isbat/rukyat.',
        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, height: 1.4),
      ),
    );
  }
}
