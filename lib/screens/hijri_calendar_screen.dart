import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/kecamatan_model.dart';
import '../services/hijri_service.dart';
import '../services/reverse_geocode_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/watermark_footer.dart';
import '../widgets/home_button.dart';
import 'kriteria_hilal_settings_sheet.dart';
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
  // Urutan kolom kalender: Ahad di depan (sesuai referensi), bukan Senin.
  static const _namaHariKolom = ['Ahad', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
  static const _namaHariLengkap = {1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis', 5: 'Jumat', 6: 'Sabtu', 7: 'Ahad'};
  static const _angkaArab = ['\u0660', '\u0661', '\u0662', '\u0663', '\u0664', '\u0665', '\u0666', '\u0667', '\u0668', '\u0669'];

  static String _keAngkaArab(int n) => n.toString().split('').map((d) => _angkaArab[int.parse(d)]).join();

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
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Kriteria Imkan Rukyat',
            onPressed: () async {
              final berubah = await KriteriaHilalSettingsSheet.show(context);
              if (berubah == true && context.mounted) setState(() {});
            },
          ),
          HomeButton(),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildBarisLokasi(),
            _buildNavigasiBulan(),
            const Divider(height: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  // Batasi lebar maksimum -- tanpa ini, di layar lebar
                  // (desktop/tablet/web) 7 kolom jadi sangat lebar, dan
                  // karena tingginya proporsional (childAspectRatio),
                  // kotak kalender jadi raksasa. Dibatasi supaya ukurannya
                  // tetap wajar seperti di HP, cukup diberi ruang kosong
                  // di kiri-kanan pada layar lebar.
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _buildGridKalender(),
                ),
              ),
            ),
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

  /// Label rentang bulan Hijriah yang tercakup dalam bulan Masehi yang
  /// sedang tampil (mis. "Rabiul Awal - Rabiul Akhir 1448"), sesuai
  /// referensi desain -- satu bulan Masehi hampir selalu melintasi 2
  /// bulan Hijriah karena panjang bulannya beda (~29.5 vs 30/31 hari).
  String? _labelRentangHijriah() {
    final lokasi = _lokasi;
    if (lokasi == null || lokasi.utcOffset == null) return null;

    final hari1 = _bulanTampil;
    final hariTerakhir = DateTime(_bulanTampil.year, _bulanTampil.month + 1, 0);
    final hijriAwal = HijriService.instance.konversi(hari1, lat: lokasi.lat, lng: lokasi.lng, utcOffset: lokasi.utcOffset!);
    final hijriAkhir = HijriService.instance.konversi(hariTerakhir, lat: lokasi.lat, lng: lokasi.lng, utcOffset: lokasi.utcOffset!);

    if (hijriAwal.bulanH == hijriAkhir.bulanH && hijriAwal.tahunH == hijriAkhir.tahunH) {
      return '${hijriAwal.namaBulanH} ${hijriAwal.tahunH}';
    }
    if (hijriAwal.tahunH == hijriAkhir.tahunH) {
      return '${hijriAwal.namaBulanH} - ${hijriAkhir.namaBulanH} ${hijriAwal.tahunH}';
    }
    return '${hijriAwal.namaBulanH} ${hijriAwal.tahunH} - ${hijriAkhir.namaBulanH} ${hijriAkhir.tahunH}';
  }

  Widget _buildNavigasiBulan() {
    final labelHijriah = _labelRentangHijriah();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _gantiBulan(-1)),
          Column(
            children: [
              Text(
                '${_namaBulanMasehi[_bulanTampil.month]} ${_bulanTampil.year}',
                style: AppTypography.headlineMd(),
              ),
              if (labelHijriah != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(labelHijriah, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
                ),
            ],
          ),
          IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _gantiBulan(1)),
        ],
      ),
    );
  }

  Widget _buildGridKalender() {
    final lokasi = _lokasi;
    final hari1 = DateTime(_bulanTampil.year, _bulanTampil.month, 1);
    final jumlahHariBulanIni = DateTime(_bulanTampil.year, _bulanTampil.month + 1, 0).day;
    // weekday Dart: Senin=1..Ahad=7. Kolom kita mulai dari Ahad(indeks 0),
    // jadi offset = weekday % 7 (Ahad->0, Senin->1, ..., Sabtu->6).
    final offsetAwal = hari1.weekday % 7;
    final totalSel = offsetAwal + jumlahHariBulanIni;
    final extraSetelah = (7 - totalSel % 7) % 7;
    final totalGrid = totalSel + extraSetelah;
    final now = DateTime.now();

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: _namaHariKolom
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.8,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: totalGrid,
            itemBuilder: (context, index) {
              // Satu rumus untuk ketiga kasus (bulan lalu/ini/depan) --
              // menambah/mengurangi hari dari tanggal 1 bulan yang tampil.
              final tanggalMasehi = hari1.add(Duration(days: index - offsetAwal));
              final diLuarBulanIni = tanggalMasehi.month != _bulanTampil.month || tanggalMasehi.year != _bulanTampil.year;
              final iniHariIni = tanggalMasehi.year == now.year && tanggalMasehi.month == now.month && tanggalMasehi.day == now.day;
              final iniJumat = tanggalMasehi.weekday == 5;
              final iniAhad = tanggalMasehi.weekday == 7;

              TanggalHijriah? hijri;
              String? namaPenting;
              if (lokasi != null && lokasi.utcOffset != null) {
                hijri = HijriService.instance.konversi(tanggalMasehi, lat: lokasi.lat, lng: lokasi.lng, utcOffset: lokasi.utcOffset!);
                namaPenting = _hariPenting[(hijri.bulanH, hijri.hari)];
              }

              // Warna angka Masehi: hari ini > redup (luar bulan) > Ahad
              // (merah) > Jumat (hijau) > biasa -- meniru pola referensi.
              Color warnaAngka;
              if (diLuarBulanIni) {
                warnaAngka = Colors.grey.withOpacity(0.35);
              } else if (iniHariIni) {
                warnaAngka = AppColors.emeraldDark;
              } else if (iniAhad) {
                warnaAngka = Colors.red.shade300;
              } else if (iniJumat) {
                warnaAngka = AppColors.emerald;
              } else {
                warnaAngka = Theme.of(context).brightness == Brightness.dark ? AppColors.textDark : AppColors.textLight;
              }
              final warnaHijriKecil = diLuarBulanIni ? Colors.grey.withOpacity(0.3) : Colors.grey.shade500;
              final warnaPasaran = diLuarBulanIni ? Colors.grey.withOpacity(0.3) : Colors.grey.shade500;

              return InkWell(
                onTap: diLuarBulanIni ? null : () => _tampilkanDetailHari(tanggalMasehi, hijri, namaPenting),
                borderRadius: BorderRadius.circular(10),
                hoverColor: AppColors.emerald.withOpacity(0.08),
                splashColor: AppColors.emerald.withOpacity(0.15),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: iniHariIni ? Border.all(color: AppColors.emerald, width: 1.4) : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hijri != null)
                        Text(_keAngkaArab(hijri.hari), style: TextStyle(fontSize: 10, color: warnaHijriKecil)),
                      Text(
                        '${tanggalMasehi.day}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: warnaAngka),
                      ),
                      if (!diLuarBulanIni) ...[
                        Text(HijriService.hitungPasaran(tanggalMasehi), style: TextStyle(fontSize: 9.5, color: warnaPasaran)),
                        if (namaPenting != null)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 5, height: 5,
                            decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                          ),
                      ],
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

  Widget _barisDetailKalender(String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600))),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(nilai, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _tampilkanDetailHari(DateTime tanggalMasehi, TanggalHijriah? hijri, String? namaPenting) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_namaHariLengkap[tanggalMasehi.weekday]} ${HijriService.hitungPasaran(tanggalMasehi)}, '
              '${tanggalMasehi.day} ${_namaBulanMasehi[tanggalMasehi.month]} ${tanggalMasehi.year}',
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
            if (hijri != null) ...[
              const Divider(height: 24),
              Text('Keadaan Hilal Awal Bulan Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              _barisDetailKalender(
                'Waktu ijtimak',
                '${hijri.ijtimakAwalBulan.day}/${hijri.ijtimakAwalBulan.month}/${hijri.ijtimakAwalBulan.year} '
                '${hijri.ijtimakAwalBulan.hour.toString().padLeft(2, '0')}:${hijri.ijtimakAwalBulan.minute.toString().padLeft(2, '0')} WIB',
              ),
              _barisDetailKalender('Tinggi hilal saat maghrib', '${hijri.tinggiHilalDerajat.toStringAsFixed(2)}\u00b0'),
              _barisDetailKalender('Elongasi', '${hijri.elongasiDerajat.toStringAsFixed(2)}\u00b0'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    hijri.mabimsTerpenuhi ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 15,
                    color: hijri.mabimsTerpenuhi ? AppColors.emerald : Colors.deepOrange.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hijri.mabimsTerpenuhi ? 'Kriteria MABIMS terpenuhi' : 'Kriteria MABIMS tidak terpenuhi (istikmal)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: hijri.mabimsTerpenuhi ? AppColors.emerald : Colors.deepOrange.shade700,
                    ),
                  ),
                ],
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
    Widget legenda(Color warna, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: warna, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              legenda(AppColors.emerald, 'Hari ini'),
              legenda(Colors.red.shade300, 'Ahad'),
              legenda(AppColors.emerald, 'Jumat'),
              legenda(AppColors.gold, 'Hari penting'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Angka kecil di atas: tanggal Hijriah (angka Arab). '
            'Awal Ramadhan/Syawal/Dzulhijjah TIDAK ditandai di sini karena butuh penetapan resmi. '
            'Semua tanggal Hijriah adalah perkiraan hisab, bisa berbeda 1 hari dari sidang isbat/rukyat.',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500, height: 1.4),
          ),
        ],
      ),
    );
  }
}
