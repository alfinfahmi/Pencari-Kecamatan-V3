import 'package:flutter/material.dart';
import '../models/kecamatan_model.dart';
import '../services/kalkulator_service.dart';
import '../services/qibla_service.dart';
import '../services/lokasi_cache_service.dart';
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
    // Tampilkan cache dulu (instan, kalau ada) sambil tetap coba
    // menyegarkan di latar belakang -- lebih responsif daripada
    // selalu menunggu GPS baru tiap layar dibuka.
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
            judul: 'Rashdul Kiblat Global $tahun',
            ikon: Icons.public,
            children: [
              Text(
                'Momen matahari tepat di atas Ka\'bah -- bayangan benda tegak di '
                'seluruh dunia (yang siang hari) saat itu otomatis menunjuk arah kiblat.',
                style: TextStyle(fontSize: 12, color: abuSekunder),
              ),
              const SizedBox(height: 10),
              _barisWaktuUtc('Momen I (deklinasi menaik)', globalNaik, isDark),
              const SizedBox(height: 6),
              _barisWaktuUtc('Momen II (deklinasi menurun)', globalTurun, isDark),
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
                style: TextStyle(fontSize: 12, color: abuSekunder),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 15, color: abuTersier),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _lokasi != null ? _lokasi!.kecamatan : (_memuatLokasi ? 'Mengambil lokasi...' : 'Lokasi belum tersedia'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: abuLabel),
                    ),
                  ),
                  TextButton(onPressed: _memuatLokasi ? null : _gantiLokasi, child: const Text('Ganti', style: TextStyle(fontSize: 12))),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: abuTersier),
                  const SizedBox(width: 6),
                  Text('${_tanggalLokal.day}/${_tanggalLokal.month}/${_tanggalLokal.year}', style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.textDark : AppColors.textLight)),
                  TextButton(onPressed: _pilihTanggal, child: const Text('Ganti Tanggal', style: TextStyle(fontSize: 12))),
                ],
              ),
              const SizedBox(height: 8),
              if (_lokasi != null && _lokasi!.utcOffset != null) _hasilRashdulLokal(isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hasilRashdulLokal(bool isDark) {
    final lokasi = _lokasi!;
    final arahKiblat = QiblaService.bearingDerajat(
      lat1: lokasi.lat, lng1: lokasi.lng,
      lat2: KalkulatorService.kabahLat, lng2: KalkulatorService.kabahLng,
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.emerald.withOpacity(isDark ? 0.14 : 0.08), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Arah kiblat dari lokasi ini: ${arahKiblat.toStringAsFixed(2)}\u00b0', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
          const SizedBox(height: 6),
          _hasilTashilulAmtsilah(lokasi, arahKiblat, isDark),
        ],
      ),
    );
  }

  Widget _hasilTashilulAmtsilah(KecamatanModel lokasi, double arahKiblat, bool isDark) {
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
        Text('Metode kitab Tashilul Amtsilah:', style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(
          '${jamKeString(siangJam)} ${lokasi.zonaWaktu ?? ''}  (siang -- bisa dipakai kalibrasi)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? AppColors.primaryDark : AppColors.emerald),
        ),
        Text(
          '${jamKeString(malamJam)} ${lokasi.zonaWaktu ?? ''}  (malam -- cuma solusi geometris, matahari tidak terlihat)',
          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _barisWaktuUtc(String label, DateTime utc, bool isDark) {
    final wib = utc.add(const Duration(hours: 7));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          Text(
            '${wib.day}/${wib.month}/${wib.year}  ${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')}:${wib.second.toString().padLeft(2, '0')} WIB',
            style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.textDark : AppColors.textLight),
          ),
          Text(
            '(${utc.day}/${utc.month}/${utc.year}  ${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}:${utc.second.toString().padLeft(2, '0')} UTC -- sesuaikan zona waktu Anda kalau di luar WIB)',
            style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _kartuSeksi({required String judul, required IconData ikon, required List<Widget> children}) {
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
          Row(children: [
            Icon(ikon, size: 17, color: isDark ? AppColors.primaryDark : AppColors.emerald),
            const SizedBox(width: 6),
            Expanded(child: Text(judul, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppColors.textDark : AppColors.textLight))),
          ]),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
