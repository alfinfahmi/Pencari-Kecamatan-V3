import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/kecamatan_model.dart';
import '../services/kalkulator_service.dart';
import '../services/qibla_service.dart';
import '../services/reverse_geocode_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/location_picker_sheet.dart';

class KalkulatorRashdulTab extends StatefulWidget {
  const KalkulatorRashdulTab({super.key});
  @override
  State<KalkulatorRashdulTab> createState() => _KalkulatorRashdulTabState();
}

class _KalkulatorRashdulTabState extends State<KalkulatorRashdulTab> {
  KecamatanModel? _lokasi;
  bool _memuatLokasi = false;
  DateTime _tanggalLokal = DateTime.now();

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
        7 => 'WIB', 8 => 'WITA', 9 => 'WIT',
        _ => 'UTC${utcOffsetJam >= 0 ? '+' : ''}$utcOffsetJam',
      };
      final lokasi = await lengkapiInfoLokasiGps(
        lat: pos.latitude, lng: pos.longitude,
        elevasiM: pos.altitude > 0 ? pos.altitude.round() : 0,
        zonaWaktu: namaZona, utcOffset: utcOffsetJam,
      );
      if (mounted) setState(() => _lokasi = lokasi);
    } catch (_) {
      // Diamkan -- pengguna tetap bisa pilih lokasi manual.
    } finally {
      if (mounted) setState(() => _memuatLokasi = false);
    }
  }

  Future<void> _gantiLokasi() async {
    final terpilih = await LocationPickerSheet.show(context, judul: 'Pilih Lokasi');
    if (terpilih == kPilihGpsSentinel) {
      await _muatLokasiDariGps();
    } else if (terpilih is KecamatanModel) {
      setState(() => _lokasi = terpilih);
    }
  }

  Future<void> _pilihTanggal() async {
    final terpilih = await showDatePicker(
      context: context,
      initialDate: _tanggalLokal,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (terpilih != null) setState(() => _tanggalLokal = terpilih);
  }

  @override
  Widget build(BuildContext context) {
    final tahun = DateTime.now().year;
    final globalNaik = KalkulatorService.cariRashdulGlobal(tahun: tahun, naik: true);
    final globalTurun = KalkulatorService.cariRashdulGlobal(tahun: tahun, naik: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kartuSeksi(
            judul: 'Rashdul Kiblat Global $tahun',
            ikon: Icons.public,
            children: [
              Text(
                'Momen matahari tepat di atas Ka\'bah -- bayangan benda tegak di '
                'seluruh dunia (yang siang hari) saat itu otomatis menunjuk arah kiblat.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              _barisWaktuUtc('Momen I (deklinasi menaik)', globalNaik),
              const SizedBox(height: 6),
              _barisWaktuUtc('Momen II (deklinasi menurun)', globalTurun),
            ],
          ),
          const SizedBox(height: 16),
          _kartuSeksi(
            judul: 'Rashdul Kiblat Lokal',
            ikon: Icons.location_on_outlined,
            children: [
              Text(
                'Waktu bayangan matahari menunjukkan arah kiblat presisi '
                '(hari ini, di lokasi Anda) -- cara kalibrasi arah kiblat '
                'paling akurat, tanpa perlu kompas.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 15, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _lokasi != null ? _lokasi!.kecamatan : (_memuatLokasi ? 'Mengambil lokasi...' : 'Lokasi belum tersedia'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                  ),
                  TextButton(onPressed: _memuatLokasi ? null : _gantiLokasi, child: const Text('Ganti', style: TextStyle(fontSize: 12))),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text('${_tanggalLokal.day}/${_tanggalLokal.month}/${_tanggalLokal.year}', style: const TextStyle(fontSize: 12.5)),
                  TextButton(onPressed: _pilihTanggal, child: const Text('Ganti Tanggal', style: TextStyle(fontSize: 12))),
                ],
              ),
              const SizedBox(height: 8),
              if (_lokasi != null && _lokasi!.utcOffset != null) _hasilRashdulLokal(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hasilRashdulLokal() {
    final lokasi = _lokasi!;
    final arahKiblat = QiblaService.bearingDerajat(
      lat1: lokasi.lat, lng1: lokasi.lng,
      lat2: KalkulatorService.kabahLat, lng2: KalkulatorService.kabahLng,
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.emerald.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Arah kiblat dari lokasi ini: ${arahKiblat.toStringAsFixed(2)}\u00b0', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          _hasilTashilulAmtsilah(lokasi, arahKiblat),
        ],
      ),
    );
  }

  Widget _hasilTashilulAmtsilah(KecamatanModel lokasi, double arahKiblat) {
    final (siangJam, malamJam) = KalkulatorService.cariRashdulLokalTashilulAmtsilah(
      tanggalLokal: _tanggalLokal,
      lat: lokasi.lat, lng: lokasi.lng,
      utcOffset: lokasi.utcOffset!,
      arahKiblat: arahKiblat,
    );
    String jamKeString(double jam) {
      final h = jam.floor();
      final m = ((jam - h) * 60).floor();
      final s = (((jam - h) * 60 - m) * 60).round();
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Metode kitab Tashilul Amtsilah:', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(
          '${jamKeString(siangJam)} ${lokasi.zonaWaktu ?? ''}  (siang -- bisa dipakai kalibrasi)',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.emerald),
        ),
        Text(
          '${jamKeString(malamJam)} ${lokasi.zonaWaktu ?? ''}  (malam -- cuma solusi geometris, matahari tidak terlihat)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _barisWaktuUtc(String label, DateTime utc) {
    final wib = utc.add(const Duration(hours: 7));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          Text(
            '${wib.day}/${wib.month}/${wib.year}  ${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')}:${wib.second.toString().padLeft(2, '0')} WIB',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '(${utc.day}/${utc.month}/${utc.year}  ${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}:${utc.second.toString().padLeft(2, '0')} UTC -- sesuaikan zona waktu Anda kalau di luar WIB)',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _kartuSeksi({required String judul, required IconData ikon, required List<Widget> children}) {
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
          Row(children: [
            Icon(ikon, size: 17, color: AppColors.emerald),
            const SizedBox(width: 6),
            Expanded(child: Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          ]),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
