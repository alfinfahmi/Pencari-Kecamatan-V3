import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/kecamatan_model.dart';
import '../services/hijri_service.dart';
import '../services/as_syahru_service.dart';
import '../services/meeus_hisab_service.dart';
import '../services/meeus_presisi_tinggi_service.dart';
import '../services/hisab_detail.dart';
import '../services/reverse_geocode_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/watermark_footer.dart';
import '../widgets/home_button.dart';
import '../widgets/location_picker_sheet.dart';

/// Laporan hisab awal bulan -- menampilkan hasil DUA metode (Jean Meeus &
/// As-Syahru) berdampingan lewat tab, supaya pengguna bisa memilih atau
/// membandingkan. Desain kartu modern, bukan tabel formal tradisional --
/// tapi seluruh detail isi laporan tradisional (Markaz, data matahari &
/// bulan, tinggi hilal Hakiki/Mar'i, elongasi, azimut, ghurub, keadaan
/// hilal, arah rukyat, kesimpulan) tetap tercakup lengkap.
///
/// SENGAJA dirancang supaya metode hisab lain yang mungkin ditambahkan ke
/// depannya tinggal ditambahkan sebagai tab baru -- lihat `_metodeList`.
class HisabAwalBulanScreen extends StatefulWidget {
  const HisabAwalBulanScreen({super.key});

  @override
  State<HisabAwalBulanScreen> createState() => _HisabAwalBulanScreenState();
}

class _HisabAwalBulanScreenState extends State<HisabAwalBulanScreen> with SingleTickerProviderStateMixin {
  KecamatanModel? _lokasi;
  bool _memuatLokasi = false;
  final _tahunHController = TextEditingController(text: '1448');
  int _bulanHDipilih = 4;
  late TabController _tabController;

  /// Daftar metode yang tersedia -- tambahkan entri baru di sini kalau
  /// nanti ada metode hisab lain, tab baru otomatis muncul tanpa perlu
  /// ubah struktur layar ini.
  ///
  /// `cariIjtimakSendiri` OPSIONAL: kalau metode itu punya cara sendiri
  /// menghitung waktu ijtimak (seperti Jean Meeus lewat algoritma Bab 49
  /// yang tervalidasi terpisah), isi di sini supaya ijtimak yang
  /// ditampilkan benar-benar milik metode itu sendiri -- bukan ikut
  /// waktu ijtimak bersama dari HijriService. Kalau null (seperti
  /// As-Syahru saat ini), dipakai waktu ijtimak bersama sebagai fallback
  /// karena kami belum punya sumber tervalidasi untuk ijtimak khas
  /// As-Syahru sendiri.
  static final _metodeList = <(
    String label,
    HasilHisabDetail Function({
      required DateTime ijtimakUtc,
      required double lat,
      required double lng,
      required double elevasiM,
      required int utcOffset,
    }),
    DateTime Function({required int tahunH, required int bulanH})?,
  )>[
    ('Jean Meeus', MeeusHisabService.hitung, MeeusHisabService.cariIjtimakUtc),
    ('As-Syahru', AsSyahruService.hitung, AsSyahruService.cariIjtimakUtc),
    ('Meeus Presisi Tinggi', MeeusPresisiTinggiService.hitung, MeeusPresisiTinggiService.cariIjtimakUtc),
  ];

  static const _namaBulanHijriah = {
    1: 'Muharram', 2: 'Safar', 3: 'Rabiul Awal', 4: 'Rabiul Akhir',
    5: 'Jumadil Ula', 6: 'Jumadil Tsani', 7: 'Rajab', 8: "Sya'ban",
    9: 'Ramadhan', 10: 'Syawal', 11: "Dzulqa'dah", 12: 'Dzulhijjah',
  };
  static const _namaHariLengkap = {1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis', 5: 'Jumat', 6: 'Sabtu', 7: 'Ahad'};
  static const _namaBulanMasehi = {
    1: 'Januari', 2: 'Februari', 3: 'Maret', 4: 'April', 5: 'Mei', 6: 'Juni',
    7: 'Juli', 8: 'Agustus', 9: 'September', 10: 'Oktober', 11: 'November', 12: 'Desember',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _metodeList.length, vsync: this);
    _muatLokasiDariGps();
  }

  @override
  void dispose() {
    _tahunHController.dispose();
    _tabController.dispose();
    super.dispose();
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
      if (mounted) {
        final hijriSekarang = HijriService.instance.konversi(
          DateTime.now(), lat: lokasi.lat, lng: lokasi.lng, utcOffset: lokasi.utcOffset!,
          elevasiM: (lokasi.elevasiM ?? 0).toDouble(),
        );
        setState(() {
          _lokasi = lokasi;
          _tahunHController.text =
              (hijriSekarang.bulanH == 12 ? hijriSekarang.tahunH + 1 : hijriSekarang.tahunH).toString();
          _bulanHDipilih = hijriSekarang.bulanH == 12 ? 1 : hijriSekarang.bulanH + 1;
        });
      }
    } catch (_) {
      // Diamkan -- pengguna tetap bisa pilih lokasi manual.
    } finally {
      if (mounted) setState(() => _memuatLokasi = false);
    }
  }

  Future<void> _gantiLokasi() async {
    final terpilih = await LocationPickerSheet.show(context, judul: 'Pilih Lokasi/Markaz Rukyah');
    if (terpilih == kPilihGpsSentinel) {
      await _muatLokasiDariGps();
    } else if (terpilih is KecamatanModel) {
      setState(() => _lokasi = terpilih);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.backgroundDark : const Color(0xFFF6F8F7),
      appBar: AppBar(
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        title: const Text('Hisab Awal Bulan'),
        actions: [HomeButton()],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.gold,
          tabs: _metodeList.map((m) => Tab(text: m.$1)).toList(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildBarisKontrol(),
            Expanded(
              child: (_lokasi == null || _lokasi!.utcOffset == null)
                  ? Center(
                      child: Text(
                        _memuatLokasi ? 'Mengambil lokasi...' : 'Pilih lokasi dahulu untuk menghitung.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : (int.tryParse(_tahunHController.text) == null)
                      ? Center(child: Text('Isi Tahun H yang valid.', style: TextStyle(color: Colors.grey.shade500)))
                      : TabBarView(
                          controller: _tabController,
                          children: _metodeList.map((m) => _buildIsiMetode(m.$2, m.$3)).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarisKontrol() {
    return Container(
      color: AppColors.emerald,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _lokasi != null ? _lokasi!.kecamatan : 'Lokasi belum tersedia',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: _memuatLokasi ? null : _gantiLokasi,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero, foregroundColor: AppColors.gold,
                ),
                child: const Text('Ganti Lokasi', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _tahunHController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Tahun H',
                    labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                    floatingLabelStyle: const TextStyle(color: Colors.white, fontSize: 11),
                    isDense: true,
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _bulanHDipilih,
                  dropdownColor: AppColors.primaryLight,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Bulan',
                    labelStyle: TextStyle(color: Colors.white70, fontSize: 11),
                    floatingLabelStyle: TextStyle(color: Colors.white, fontSize: 11),
                    isDense: true,
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
                  ),
                  items: _namaBulanHijriah.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() => _bulanHDipilih = v ?? _bulanHDipilih),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIsiMetode(
    HasilHisabDetail Function({
      required DateTime ijtimakUtc,
      required double lat,
      required double lng,
      required double elevasiM,
      required int utcOffset,
    }) fungsiHitung,
    DateTime Function({required int tahunH, required int bulanH})? cariIjtimakSendiri,
  ) {
    final lokasi = _lokasi!;
    final tahunH = int.parse(_tahunHController.text);
    final bulanH = _bulanHDipilih;

    final awal = HijriService.tentukanAwalBulan(
      tahunH: tahunH, bulanH: bulanH, lat: lokasi.lat, lng: lokasi.lng,
      utcOffset: lokasi.utcOffset!, elevasiM: (lokasi.elevasiM ?? 0).toDouble(),
    );
    // Kalau metode ini punya cara sendiri menghitung ijtimak (mis. Jean
    // Meeus lewat algoritma Bab 49 tervalidasi terpisah), pakai itu --
    // supaya waktu ijtimak yang ditampilkan benar-benar milik metode ini,
    // bukan ikut angka bersama dari HijriService.
    final ijtimakUtc = cariIjtimakSendiri != null
        ? cariIjtimakSendiri(tahunH: tahunH, bulanH: bulanH)
        : awal.ijtimak.subtract(Duration(hours: lokasi.utcOffset!));
    final ijtimakLokal = ijtimakUtc.add(Duration(hours: lokasi.utcOffset!));
    final hasil = fungsiHitung(
      ijtimakUtc: ijtimakUtc, lat: lokasi.lat, lng: lokasi.lng,
      elevasiM: (lokasi.elevasiM ?? 0).toDouble(), utcOffset: lokasi.utcOffset!,
    );

    final bulanSebelumnyaH = bulanH == 1 ? 12 : bulanH - 1;
    final hariIjtimakSaja = DateTime(ijtimakLokal.year, ijtimakLokal.month, ijtimakLokal.day);
    final tanggal1 = hasil.memenuhiMabims2021
        ? hariIjtimakSaja.add(const Duration(days: 1))
        : hariIjtimakSaja.add(const Duration(days: 2));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Center(
        child: ConstrainedBox(
          // Batasi lebar maksimum -- tanpa ini, di layar lebar (desktop)
          // kartu-kartu jadi melebar penuh ke seluruh layar, sulit dibaca.
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kartuKesimpulan(hasil, bulanH, tahunH, tanggal1),
          const SizedBox(height: 12),
          _kartuSeksi(
            judul: 'Markaz & Ijtimak',
            ikon: Icons.explore_outlined,
            children: [
              _baris('Markaz / Tempat Rukyah', lokasi.kecamatan),
              _baris('Lintang', _dms(lokasi.lat, 'LU', 'LS')),
              _baris('Bujur', _dms(lokasi.lng, 'BT', 'BB')),
              _baris('Ketinggian', '${lokasi.elevasiM ?? 0} m'),
              const Divider(height: 18),
              _baris('Ijtimak akhir ${_namaBulanHijriah[bulanSebelumnyaH]} $tahunH',
                  '${_namaHariLengkap[ijtimakLokal.weekday]} ${HijriService.hitungPasaran(ijtimakLokal)}'),
              _baris('Tanggal & Jam',
                  '${ijtimakLokal.day} ${_namaBulanMasehi[ijtimakLokal.month]} ${ijtimakLokal.year}, '
                  '${_jamStr(_utcJamKeLokal(ijtimakUtc, lokasi.utcOffset!))} ${lokasi.zonaWaktu ?? ''}'),
            ],
          ),
          const SizedBox(height: 12),
          _kartuSeksi(
            judul: 'Data Matahari',
            ikon: Icons.wb_sunny_outlined,
            children: [
              _baris('Deklinasi', _dmsSudut(hasil.deklinasiMatahari)),
              _baris('Sudut Waktu', _dmsSudut(hasil.sudutWaktuMatahari)),
              _baris('Bujur Astronomis', _dmsSudut(hasil.bujurMatahari)),
              _baris('Tinggi Saat Terbenam (Standar)', _dmsSudut(hasil.tinggiMatahariSaatTerbenam)),
              _baris('Ghurub (Maghrib)', '${_jamStr(hasil.ghurubMatahariJam)} ${lokasi.zonaWaktu ?? ''}', tebal: true),
              _baris('Azimut', '${_dmsSudut(hasil.azimutMatahari)} BU'),
            ],
          ),
          const SizedBox(height: 12),
          _kartuHilal(hasil),
          const SizedBox(height: 12),
          _kartuSeksi(
            judul: 'Data Bulan',
            ikon: Icons.nightlight_outlined,
            children: [
              _baris('Deklinasi', _dmsSudut(hasil.deklinasiBulan)),
              _baris('Sudut Waktu', _dmsSudut(hasil.sudutWaktuBulan)),
              _baris('Bujur Astronomis', _dmsSudut(hasil.bujurBulan)),
              _baris('Azimut', '${_dmsSudut(hasil.azimutBulan)} BU'),
              _baris('Ghurub Hilal', '${_jamStr(hasil.ghurubHilalJam)} ${lokasi.zonaWaktu ?? ''}'),
              _baris('Lama Hilal (Muksu)', _lamaHilalStr(hasil.lamaHilalJam)),
              _baris('Nurul Hilal', hasil.nurulHilal.toStringAsFixed(3)),
              _baris('Jarak dgn Matahari',
                  '${_dmsSudut(hasil.jarakAzimutMatahariBulan.abs())} di ${hasil.jarakAzimutMatahariBulan >= 0 ? 'utara' : 'selatan'}'),
              _baris('Keadaan Hilal', hasil.keadaanHilalArah),
              _baris('Arah Rukyatul Hilal', _dmsSudut(hasil.azimutBulan)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dihitung oleh LF Ma\'had \'Aly Lirboyo -- MHM Kediri. Kriteria: MABIMS 2021 '
            '(irtifa \u2265 3\u00b0, elongasi \u2265 6.4\u00b0). Penetapan resmi Ramadhan/Syawal/Dzulhijjah '
            'tetap menunggu sidang isbat.',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 12),
          const WatermarkFooter(),
        ],
          ),
        ),
      ),
    );
  }

  Widget _kartuKesimpulan(HasilHisabDetail hasil, int bulanH, int tahunH, DateTime tanggal1) {
    final warna = hasil.memenuhiMabims2021 ? AppColors.emerald : Colors.deepOrange.shade700;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [warna, warna.withOpacity(0.75)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: warna.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(hasil.memenuhiMabims2021 ? Icons.check_circle_rounded : Icons.info_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                hasil.memenuhiMabims2021 ? 'Kriteria Imkan Rukyat Terpenuhi' : 'Istikmal (Kriteria Belum Terpenuhi)',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Awal ${_namaBulanHijriah[bulanH]} $tahunH H',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(
            '${_namaHariLengkap[tanggal1.weekday]}, ${tanggal1.day} ${_namaBulanMasehi[tanggal1.month]} ${tanggal1.year}',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _pilKesimpulan('Tinggi Mar\'i', '${hasil.tinggiHilalMari.toStringAsFixed(2)}\u00b0'),
              const SizedBox(width: 8),
              _pilKesimpulan('Elongasi', '${hasil.elongasi.toStringAsFixed(2)}\u00b0'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pilKesimpulan(String label, String nilai) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            Text(nilai, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _kartuHilal(HasilHisabDetail hasil) {
    final warna = hasil.memenuhiMabims2021 ? AppColors.emerald : Colors.deepOrange.shade700;
    return Container(
      decoration: BoxDecoration(
        color: warna.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warna.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.nightlight_round, color: warna, size: 18),
              const SizedBox(width: 6),
              Text('Keadaan Hilal', style: TextStyle(color: warna, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _statHilal('Hakiki', hasil.tinggiHilalHakiki, warna)),
              const SizedBox(width: 10),
              Expanded(child: _statHilal("Mar'i", hasil.tinggiHilalMari, warna)),
              const SizedBox(width: 10),
              Expanded(child: _statHilal('Elongasi', hasil.elongasi, warna)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statHilal(String label, double nilai, Color warna) {
    return Column(
      children: [
        Text('${nilai.toStringAsFixed(2)}\u00b0', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: warna)),
        Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _kartuSeksi({required String judul, required IconData ikon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 17, color: AppColors.emerald),
              const SizedBox(width: 6),
              Text(judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _baris(String label, String nilai, {bool tebal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(nilai, textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, fontWeight: tebal ? FontWeight.bold : FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _dmsSudut(double derajat) {
    final neg = derajat < 0;
    final abs = derajat.abs();
    final d = abs.truncate();
    final mFull = (abs - d) * 60;
    final m = mFull.truncate();
    final s = (mFull - m) * 60;
    return '${neg ? '-' : ''}$d\u00b0 $m\' ${s.toStringAsFixed(2)}"';
  }

  String _dms(double derajat, String labelPositif, String labelNegatif) {
    final label = derajat >= 0 ? labelPositif : labelNegatif;
    return '${_dmsSudut(derajat.abs())} $label';
  }

  double _utcJamKeLokal(DateTime utc, int utcOffset) {
    final lokal = utc.add(Duration(hours: utcOffset));
    return lokal.hour + lokal.minute / 60 + lokal.second / 3600;
  }

  String _jamStr(double jamDesimal) {
    final j = jamDesimal.truncate();
    final mFull = (jamDesimal - j) * 60;
    final m = mFull.truncate();
    final s = (mFull - m) * 60;
    return '${j.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toStringAsFixed(0).padLeft(2, '0')}';
  }

  String _lamaHilalStr(double jamDesimal) {
    final j = jamDesimal.truncate();
    final mFull = (jamDesimal - j) * 60;
    final m = mFull.truncate();
    final s = ((mFull - m) * 60).round();
    return '${j}j ${m}m ${s}d';
  }
}
