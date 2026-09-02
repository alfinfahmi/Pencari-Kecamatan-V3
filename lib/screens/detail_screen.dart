import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../models/kecamatan_model.dart';
import '../services/app_data_service.dart';
import '../services/qibla_service.dart';
import '../services/hisab_service.dart';
import '../services/hijri_service.dart';
import '../services/prayer_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/watermark_footer.dart';
import '../widgets/home_button.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/qibla_compass.dart';
import '../widgets/prayer_time_table.dart';
import 'add_point_screen.dart';
import 'compass_fullscreen_screen.dart';
import 'prayer_settings_sheet.dart';
import 'export_jadwal_screen.dart';
import 'usulkan_koreksi_screen.dart';

/// Bagian mana di DetailScreen yang harus langsung terlihat saat halaman
/// dibuka -- dipakai oleh 4 tombol menu cepat di KecamatanCard supaya
/// pengguna langsung diarahkan ke bagian yang relevan, bukan selalu dari atas.
enum DetailSection { geografis, kiblat, waktuShalat }

class DetailScreen extends StatefulWidget {
  final KecamatanModel data;
  final DetailSection? initialSection;
  const DetailScreen({super.key, required this.data, this.initialSection});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _prayerSettings = PrayerSettingsService();
  List<WaktuShalatEntry>? _waktuShalat;
  bool _loadingShalat = true;
  DateTime _tanggalDipilih = DateTime.now();
  late KecamatanModel _lokasiWaktuShalat = widget.data;

  @override
  void initState() {
    super.initState();
    _hitungWaktuShalat();
  }

  /// Ganti lokasi acuan KHUSUS untuk bagian Waktu Shalat (tidak mengubah
  /// identitas halaman/lokasi utama di Rincian Geografis & Arah Kiblat --
  /// mirip cara kerja tombol serupa di layar Ekspor Jadwal Shalat).
  Future<void> _gantiLokasiWaktuShalat() async {
    final terpilih = await LocationPickerSheet.show(context, judul: 'Pilih Lokasi untuk Waktu Shalat');
    if (terpilih == kPilihGpsSentinel) {
      await _pakaiGpsUntukWaktuShalat();
    } else if (terpilih is KecamatanModel) {
      setState(() => _lokasiWaktuShalat = terpilih);
      _hitungWaktuShalat();
    }
  }

  Future<void> _pakaiGpsUntukWaktuShalat() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak')));
        }
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aktifkan layanan lokasi (GPS) di perangkat Anda')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final utcOffsetJam = DateTime.now().timeZoneOffset.inHours;
      final namaZona = switch (utcOffsetJam) {
        7 => 'WIB',
        8 => 'WITA',
        9 => 'WIT',
        _ => 'UTC${utcOffsetJam >= 0 ? '+' : ''}$utcOffsetJam',
      };
      setState(() {
        _lokasiWaktuShalat = KecamatanModel(
          id: 'gps_lokasi_saat_ini',
          kecamatan: 'Lokasi Anda Saat Ini',
          kabupaten: null,
          provinsi: '(berdasarkan GPS)',
          lat: pos.latitude,
          lng: pos.longitude,
          latDms: null,
          lngDms: null,
          elevasiM: pos.altitude > 0 ? pos.altitude.round() : 0,
          zonaWaktu: namaZona,
          utcOffset: utcOffsetJam,
        );
      });
      _hitungWaktuShalat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil lokasi GPS: $e')));
      }
    }
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggalDipilih,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Pilih Tanggal Waktu Shalat',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.emerald,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (hasil != null) {
      setState(() {
        _tanggalDipilih = hasil;
        _loadingShalat = true;
      });
      _hitungWaktuShalat();
    }
  }

  Future<void> _hitungWaktuShalat() async {
    final data = _lokasiWaktuShalat;
    if (data.utcOffset == null || data.zonaWaktu == null) {
      setState(() => _loadingShalat = false);
      return;
    }

    final ihtiyath = await _prayerSettings.getIhtiyath();
    final sudutIsya = await _prayerSettings.getSudutIsya();
    final sudutSubuh = await _prayerSettings.getSudutSubuh();

    final hasil = HisabService.hitung(
      tanggal: _tanggalDipilih,
      lat: data.lat,
      lng: data.lng,
      elevasiM: (data.elevasiM ?? 0).toDouble(),
      utcOffset: data.utcOffset!,
      sudutIsya: sudutIsya,
      sudutSubuh: sudutSubuh,
      ihtiyathMenit: ihtiyath,
    );

    if (mounted) {
      setState(() {
        _waktuShalat = hasil;
        _loadingShalat = false;
      });
    }
  }

  Future<void> _bukaMaps(String app) async {
    final data = widget.data;
    final Uri uri;
    if (app == 'google') {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${data.lat},${data.lng}');
    } else {
      uri = Uri.parse('https://waze.com/ul?ll=${data.lat},${data.lng}&navigate=yes');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak bisa membuka ${app == 'google' ? 'Google Maps' : 'Waze'}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kabah = AppDataService.instance.kabah;
    final lirboyo = AppDataService.instance.lirboyo;

    final bearingKiblat = QiblaService.bearingDerajat(
      lat1: data.lat, lng1: data.lng, lat2: kabah.lat, lng2: kabah.lng,
    );
    final jarakKabah = QiblaService.jarakKm(
      lat1: data.lat, lng1: data.lng, lat2: kabah.lat, lng2: kabah.lng,
    );
    final jarakLirboyo = QiblaService.jarakKm(
      lat1: data.lat, lng1: data.lng, lat2: lirboyo.lat, lng2: lirboyo.lng,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (widget.initialSection) {
          DetailSection.geografis => 'Rincian Geografis',
          DetailSection.kiblat => 'Arah Kiblat',
          DetailSection.waktuShalat => 'Waktu Shalat',
          null => '',
        }),
        actions: [
          HomeButton(),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Salin Semua Data',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: data.toClipboardText()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data disalin ke clipboard')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // === Judul halaman (nama lokasi) ===
                  Text(data.kecamatan, style: AppTypography.headlineLg(
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  )),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 15, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [data.kabupaten, data.provinsi, 'Indonesia'].where((e) => e != null).join(', '),
                          style: AppTypography.bodyMd(color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ..._buildKontenSection(context, data, isDark, bearingKiblat, jarakKabah, jarakLirboyo),
                ],
              ),
            ),
            const WatermarkFooter(),
          ],
        ),
      ),
    );
  }

  /// Membangun konten sesuai [widget.initialSection] -- HANYA bagian yang
  /// relevan yang dirender (bukan render semua lalu scroll ke posisi),
  /// supaya tiap tombol menu di KecamatanCard membawa ke halaman yang
  /// benar-benar fokus pada satu topik saja.
  List<Widget> _buildKontenSection(
    BuildContext context,
    KecamatanModel data,
    bool isDark,
    double bearingKiblat,
    double jarakKabah,
    double jarakLirboyo,
  ) {
    switch (widget.initialSection) {
      case DetailSection.geografis:
        return [_kontenGeografis(context, data, isDark)];
      case DetailSection.kiblat:
        return [_kontenKiblat(context, data, isDark, bearingKiblat, jarakKabah, jarakLirboyo)];
      case DetailSection.waktuShalat:
        return [_kontenWaktuShalat(context, data)];
      case null:
        // Fallback (tidak dipakai jalur normal saat ini, semua navigasi
        // selalu menentukan section -- dijaga untuk keamanan saja).
        return [
          _kontenGeografis(context, data, isDark),
          const SizedBox(height: 16),
          _kontenKiblat(context, data, isDark, bearingKiblat, jarakKabah, jarakLirboyo),
          const SizedBox(height: 16),
          _kontenWaktuShalat(context, data),
        ];
    }
  }

  Widget _kontenGeografis(BuildContext context, KecamatanModel data, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _blokCard(
          title: 'Rincian Geografis',
          icon: Icons.public_rounded,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _koordinatKolom('Lintang', data.latDms, data.lat)),
                Expanded(child: _koordinatKolom('Bujur', data.lngDms, data.lng)),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: _labelValueKolom('Ketinggian', data.elevasiM != null ? '${data.elevasiM} m' : '-')),
                Expanded(child: _labelValueKolom(
                  'Zona Waktu',
                  data.zonaWaktu != null ? '${data.zonaWaktu} (UTC+${data.utcOffset})' : '-',
                )),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _bukaMaps('google'),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Peta'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.textDark : AppColors.textLight,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _bukaMaps('waze'),
                    icon: const Icon(Icons.directions_car_filled_outlined, size: 18),
                    label: const Text('Waze'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.textDark : AppColors.textLight,
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (!data.isReferensi) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => UsulkanKoreksiScreen(data: data),
                ));
              },
              icon: const Icon(Icons.edit_location_alt_rounded, size: 18),
              label: const Text('Usulkan Koreksi Data Ini'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.emerald,
                side: const BorderSide(color: AppColors.emerald),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AddPointScreen(induk: data)),
                );
              },
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Tambah Titik di Kecamatan Ini'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.emerald,
                side: const BorderSide(color: AppColors.emerald),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _kontenKiblat(
    BuildContext context,
    KecamatanModel data,
    bool isDark,
    double bearingKiblat,
    double jarakKabah,
    double jarakLirboyo,
  ) {
    return _blokCard(
      title: 'Arah Kiblat',
      icon: Icons.explore_outlined,
      badge: 'Terverifikasi',
      children: [
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CompassFullscreenScreen(
                bearingDerajat: bearingKiblat,
                namaLokasi: data.kecamatan,
              ),
            ));
          },
          child: Center(child: QiblaCompass(bearingDerajat: bearingKiblat)),
        ),
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              Text('Azimut Kiblat', style: AppTypography.bodyMd(color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${bearingKiblat.toStringAsFixed(1)}°',
                      style: AppTypography.headlineLg(color: AppColors.emerald).copyWith(fontSize: 28),
                    ),
                    TextSpan(
                      text: '  (${QiblaService.arahMataAnginSingkat(bearingKiblat)})',
                      style: AppTypography.bodyMd(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text("Jarak ke Ka'bah", style: AppTypography.bodyMd(color: Colors.grey.shade600)),
              Text(
                '${jarakKabah.toStringAsFixed(0)} km',
                style: AppTypography.dataDisplay(fontSize: 16, color: isDark ? AppColors.textDark : AppColors.textLight),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Jarak ke Lirboyo: ${jarakLirboyo.toStringAsFixed(1)} km',
          style: AppTypography.captionEdu(color: Colors.grey.shade500),
        ),
        Text(
          'Sudut kiblat DMS: ${QiblaService.bearingKeDms(bearingKiblat)}',
          style: AppTypography.captionEdu(color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _kontenWaktuShalat(BuildContext context, KecamatanModel data) {
    return _blokCard(
      title: 'Waktu Shalat',
      icon: Icons.access_time_rounded,
      trailing: _buildHijriLabel(),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _lokasiWaktuShalat.kecamatan,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                ),
              ),
              TextButton(
                onPressed: _gantiLokasiWaktuShalat,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
                child: const Text('Ganti Lokasi', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: _pilihTanggal,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, size: 15, color: AppColors.emerald),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatTanggalHariIndonesia(_tanggalDipilih),
                      style: AppTypography.bodyLg(color: AppColors.emerald).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.edit_calendar_outlined, size: 16, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
        ),
        if (_loadingShalat)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_waktuShalat == null)
          Text(
            'Zona waktu tidak tersedia untuk titik ini, waktu shalat tidak dapat dihitung.',
            style: AppTypography.captionEdu(color: Colors.grey.shade500),
          )
        else
          PrayerTimeTable(entries: _waktuShalat!, labelZona: _lokasiWaktuShalat.zonaWaktu ?? 'Zona'),
        const SizedBox(height: 4),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final changed = await PrayerSettingsSheet.show(context);
                  if (changed == true) _hitungWaktuShalat();
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Sesuaikan Parameter', style: TextStyle(fontSize: 12.5)),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ExportJadwalScreen(data: _lokasiWaktuShalat)),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('Ekspor Jadwal', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ),
        Text(
          'Perhitungan otomatis (deklinasi matahari & equation of time), sudah memperhitungkan '
          'koreksi kerendahan ufuk dari elevasi tempat. Validasi lanjut terhadap rujukan resmi '
          'direkomendasikan sebelum dipakai operasional.\n'
          '* Tanggal Hijriah: perkiraan hisab (ijtimak + tinggi hilal, kriteria MABIMS 2021), '
          'bukan penetapan resmi '
          '(bisa berbeda 1 hari dari sidang isbat/rukyatul hilal).',
          style: AppTypography.captionEdu(color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _blokCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    String? badge,
    Widget? trailing,
  }) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.emerald),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: AppTypography.headlineMd(
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ).copyWith(fontSize: 16)),
                  ),
                  if (badge != null) _badge(badge),
                  if (trailing != null) trailing,
                ],
              ),
              const Divider(height: 20),
              ...children,
            ],
          ),
        ),
      );
    });
  }

  /// Format tanggal ala Indonesia dengan "Ahad" (bukan "Minggu") untuk hari
  /// pertama pekan -- ditulis manual (bukan intl DateFormat locale 'id_ID')
  /// supaya tidak bergantung pada inisialisasi locale data yang belum
  /// pernah dipanggil di main.dart (menghindari risiko crash locale).
  static const _namaHari = {
    1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis',
    5: 'Jumat', 6: 'Sabtu', 7: 'Ahad',
  };
  static const _namaBulanMasehi = {
    1: 'Januari', 2: 'Februari', 3: 'Maret', 4: 'April', 5: 'Mei', 6: 'Juni',
    7: 'Juli', 8: 'Agustus', 9: 'September', 10: 'Oktober', 11: 'November', 12: 'Desember',
  };

  String _formatTanggalHariIndonesia(DateTime tanggal) {
    final hari = _namaHari[tanggal.weekday]!;
    final bulan = _namaBulanMasehi[tanggal.month]!;
    return '$hari, ${tanggal.day} $bulan ${tanggal.year}';
  }

  Widget _buildHijriLabel() {
    final data = _lokasiWaktuShalat;
    if (data.utcOffset == null) return const SizedBox.shrink();
    final hijri = HijriService.instance.konversi(
      _tanggalDipilih,
      lat: data.lat,
      lng: data.lng,
      utcOffset: data.utcOffset!,
    );
    return Tooltip(
      message: 'Perkiraan hisab (ijtimak + tinggi hilal, kriteria MABIMS 2021: '
          'tinggi hilal ≥3°, elongasi ≥6.4°). Bisa berbeda 1 hari dari '
          'penetapan resmi (sidang isbat/rukyatul hilal sungguhan) — bukan '
          'untuk kepastian awal bulan ibadah.'
          '${hijri.istikmal ? ' Bulan sebelumnya istikmal (30 hari).' : ''}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            '${hijri.label} *',
            style: AppTypography.bodyMd(color: Colors.grey.shade500).copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.85),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(text, style: AppTypography.labelCaps(color: AppColors.emeraldDark).copyWith(fontSize: 10.5)),
    );
  }

  Widget _koordinatKolom(String label, String? dms, double desimal) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.bodyMd(color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(
            dms ?? '$desimal°',
            style: AppTypography.dataDisplay(color: isDark ? AppColors.textDark : AppColors.textLight),
          ),
          if (dms != null)
            Text(
              desimal.toString(),
              style: AppTypography.dataDisplay(fontSize: 12, color: Colors.grey.shade500),
            ),
        ],
      );
    });
  }

  Widget _labelValueKolom(String label, String value) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.bodyMd(color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value, style: AppTypography.bodyLg(color: isDark ? AppColors.textDark : AppColors.textLight).copyWith(fontWeight: FontWeight.w600)),
        ],
      );
    });
  }
}
