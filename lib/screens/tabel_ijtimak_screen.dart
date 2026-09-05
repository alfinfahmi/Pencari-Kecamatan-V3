import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import '../models/kecamatan_model.dart';
import '../services/hijri_service.dart';
import '../services/reverse_geocode_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/watermark_footer.dart';
import '../widgets/home_button.dart';
import '../widgets/location_picker_sheet.dart';

/// Menampilkan tabel ijtimak akhir bulan resmi Lajnah Falakiyah Ma'had
/// 'Aly Lirboyo (1440H-1500H, 732 entri) sebagai referensi, LENGKAP dengan
/// detail keadaan hilal (tinggi & elongasi) di lokasi pilihan pengguna.
///
/// Waktu ijtimak MURNI untuk dilihat -- TIDAK dipakai sebagai sumber
/// perhitungan aplikasi (mesin hisab Hijriah aplikasi ini memakai rumus
/// live terpisah), jadi kedua angka bisa saja berbeda beberapa menit
/// karena metode hitung berbeda meski sama-sama sahih. Detail hilal DI
/// LAYAR INI dihitung langsung dari waktu ijtimak tabel, jadi konsisten
/// dengan angka ijtimak yang ditampilkan.
class TabelIjtimakScreen extends StatefulWidget {
  const TabelIjtimakScreen({super.key});

  @override
  State<TabelIjtimakScreen> createState() => _TabelIjtimakScreenState();
}

class _TabelIjtimakScreenState extends State<TabelIjtimakScreen> {
  Map<int, List<Map<String, dynamic>>>? _perTahun;
  String? _error;
  int? _tahunSekarangPerkiraan;

  final _tahunController = TextEditingController();
  int? _bulanFilter;

  KecamatanModel? _lokasi;
  bool _memuatLokasi = false;

  static const _namaBulanHijriah = {
    1: 'Muharram', 2: 'Safar', 3: 'Rabiul Awwal', 4: 'Rabiul Akhir',
    5: 'Jumadil Awwal', 6: 'Jumadil Akhir', 7: 'Rajab', 8: "Sya'ban",
    9: 'Ramadhan', 10: 'Syawal', 11: "Dzulqa'dah", 12: 'Dzulhijjah',
  };

  @override
  void dispose() {
    _tahunController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _muat();
    _muatLokasiDariGps();
  }

  Future<void> _muat() async {
    try {
      final raw = await rootBundle.loadString('assets/data/tabel_ijtimak.json');
      final jsonMap = json.decode(raw) as Map<String, dynamic>;
      final data = (jsonMap['data'] as List).cast<Map<String, dynamic>>();

      final perTahun = <int, List<Map<String, dynamic>>>{};
      for (final entry in data) {
        final tahun = entry['tahun_h'] as int;
        perTahun.putIfAbsent(tahun, () => []).add(entry);
      }

      final now = DateTime.now();
      int? tahunSekarang;
      for (final entry in data) {
        final tgl = HijriService.parseWibSebagaiUtc(entry['ijtimak_wib'] as String);
        if (tgl.isAfter(now)) {
          tahunSekarang = entry['tahun_h'] as int;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _perTahun = perTahun;
          _tahunSekarangPerkiraan = tahunSekarang;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat tabel ijtimak: $e');
    }
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
      // Diamkan -- detail hilal cukup disembunyikan kalau lokasi gagal
      // didapat, tabel ijtimak sendiri tetap tampil normal.
    } finally {
      if (mounted) setState(() => _memuatLokasi = false);
    }
  }

  Future<void> _gantiLokasi() async {
    final terpilih = await LocationPickerSheet.show(context, judul: 'Pilih Lokasi untuk Keadaan Hilal');
    if (terpilih == kPilihGpsSentinel) {
      await _muatLokasiDariGps();
    } else if (terpilih is KecamatanModel) {
      setState(() => _lokasi = terpilih);
    }
  }

  static const _namaHariLengkap = {1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis', 5: 'Jumat', 6: 'Sabtu', 7: 'Ahad'};

  /// Nama hari + pasaran dihitung ULANG di sini (bukan dari field
  /// `hari_pasaran` hasil ekstraksi Excel dulu) -- ternyata kolom pasaran
  /// hasil ekstraksi lama SALAH (kesalahan pemetaan teks Arab->Indonesia,
  /// meski tanggal & nama harinya sendiri terbukti benar). Dihitung ulang
  /// pakai rumus yang sudah divalidasi terhadap sumber independen.
  /// Warna keadaan hilal, 3 tingkat (bukan biner ya/tidak):
  /// - Hijau: kriteria MABIMS terpenuhi (tinggi >=3 derajat, elongasi >=6.4)
  /// - Kuning: hilal SUDAH di atas ufuk (tinggi positif) tapi belum
  ///   memenuhi ambang MABIMS -- lebih "dekat" daripada kasus negatif
  /// - Oranye: hilal masih di BAWAH ufuk (tinggi negatif) -- jelas belum
  ///   mungkin terlihat
  Color _warnaKeadaanHilal(bool memenuhi, double tinggiHilal) {
    if (memenuhi) return AppColors.emerald;
    if (tinggiHilal > 0) return Colors.amber.shade800;
    return Colors.orange.shade700;
  }

  String _formatHariPasaran(DateTime tanggal) {
    final hari = _namaHariLengkap[tanggal.weekday]!;
    final pasaran = HijriService.hitungPasaran(tanggal);
    return '$hari $pasaran';
  }

  String _formatTanggalJam(String iso) {
    final dt = HijriService.parseWibSebagaiUtc(iso);
    const bulan = {
      1: 'Jan', 2: 'Feb', 3: 'Mar', 4: 'Apr', 5: 'Mei', 6: 'Jun',
      7: 'Jul', 8: 'Agu', 9: 'Sep', 10: 'Okt', 11: 'Nov', 12: 'Des',
    };
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${bulan[dt.month]} ${dt.year}, $jam.$menit WIB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabel Ijtimak'),
        actions: [HomeButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              decoration: BoxDecoration(
                color: AppColors.emerald.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emerald.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.emerald),
                      const SizedBox(width: 6),
                      Text('Tabel Ijtimak 1440H-1500H',
                          style: AppTypography.bodyLg(color: AppColors.emerald).copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Data ijtimak akhir bulan. Murni referensi -- '
                    'perhitungan Data Hijriah aplikasi ini (badge tanggal, jadwal shalat) memakai '
                    'rumus live terpisah, jadi bisa berbeda beberapa menit dari tabel ini',
                    style: AppTypography.captionEdu(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            _buildBarisLokasi(),
            _buildKotakPencarian(),
            Expanded(child: _buildBody()),
            const WatermarkFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBarisLokasi() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: _memuatLokasi
                ? Text('Mengambil lokasi...', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500))
                : Text(
                    _lokasi != null
                        ? 'Keadaan hilal untuk: ${_lokasi!.kecamatan}'
                        : 'Lokasi belum tersedia -- detail hilal disembunyikan',
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

  Widget _buildKotakPencarian() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _tahunController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tahun H', isDense: true, hintText: 'mis. 1448'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<int?>(
              initialValue: _bulanFilter,
              decoration: const InputDecoration(labelText: 'Bulan', isDense: true),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Semua Bulan')),
                ..._namaBulanHijriah.entries
                    .map((e) => DropdownMenuItem<int?>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _bulanFilter = v),
            ),
          ),
          if (_tahunController.text.isNotEmpty || _bulanFilter != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Reset filter',
              onPressed: () => setState(() {
                _tahunController.clear();
                _bulanFilter = null;
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    if (_perTahun == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final tahunFilter = int.tryParse(_tahunController.text.trim());
    var tahunList = _perTahun!.keys.toList()..sort();
    if (tahunFilter != null) {
      tahunList = tahunList.where((t) => t == tahunFilter).toList();
    }

    if (tahunList.isEmpty) {
      return Center(
        child: Text(
          _tahunController.text.trim().isEmpty
              ? 'Tidak ditemukan'
              : 'Tahun $tahunFilter di luar rentang tabel (1440H-1500H)',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: tahunList.length,
      itemBuilder: (context, index) {
        final tahun = tahunList[index];
        var entries = _perTahun![tahun]!..sort((a, b) => (a['bulan_h'] as int).compareTo(b['bulan_h'] as int));
        if (_bulanFilter != null) {
          entries = entries.where((e) => e['bulan_h'] == _bulanFilter).toList();
        }
        final sedangMencari = tahunFilter != null || _bulanFilter != null;
        final iniTahunSekarang = tahun == _tahunSekarangPerkiraan;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            initiallyExpanded: iniTahunSekarang || sedangMencari,
            title: Row(
              children: [
                Text('$tahun H', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (iniTahunSekarang) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.85), borderRadius: BorderRadius.circular(9999)),
                    child: const Text('Sekarang', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            children: entries.map((e) => _buildBarisBulan(e)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBarisBulan(Map<String, dynamic> e) {
    final ijtimakWib = HijriService.parseWibSebagaiUtc(e['ijtimak_wib'] as String);
    final lokasi = _lokasi;

    ({bool memenuhi, double tinggiHilal, double elongasi})? hilal;
    if (lokasi != null && lokasi.utcOffset != null) {
      hilal = HijriService.hitungKeadaanHilalPadaIjtimak(
        ijtimakWib: ijtimakWib,
        lat: lokasi.lat,
        lng: lokasi.lng,
        utcOffset: lokasi.utcOffset!,
      );
    }

    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 28,
        child: Text('${e['bulan_h']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      ),
      title: Text(e['nama_bulan_h'] as String, style: const TextStyle(fontSize: 13.5)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatTanggalJam(e['ijtimak_wib'] as String)} \u2022 ${_formatHariPasaran(ijtimakWib)}',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          if (hilal != null) ...[
            const SizedBox(height: 3),
            Text(
              'Tinggi hilal ${hilal.tinggiHilal.toStringAsFixed(1)}\u00b0, '
              'elongasi ${hilal.elongasi.toStringAsFixed(1)}\u00b0 '
              '(menuju bulan berikutnya)',
              style: TextStyle(
                fontSize: 10.5,
                color: _warnaKeadaanHilal(hilal.memenuhi, hilal.tinggiHilal),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      isThreeLine: hilal != null,
    );
  }
}
