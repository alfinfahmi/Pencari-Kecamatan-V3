import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/kecamatan_model.dart';
import '../services/kamera_rukyat_service.dart';
import '../services/lokasi_cache_service.dart';
import '../theme/app_theme.dart';
import '../widgets/home_button.dart';
import '../widgets/location_picker_sheet.dart';

/// Warna mode malam (red-light) -- dipilih merah tua supaya tidak
/// membuyarkan adaptasi gelap mata pengamat, konvensi umum astronomi
/// lapangan (observatorium, pelaut, dll.)
const _merahMalam = Color(0xFFFF3B30);

/// Layar "Kamera Rukyat" -- live view kamera dengan overlay AR posisi
/// hilal terhitung (azimut, tinggi, elongasi, umur bulan), garis ufuk,
/// waterpass digital, kontrol exposure/fokus manual, mode malam
/// (red-light), dan mode monokrom.
///
/// **PENTING (baca sebelum uji coba di device sungguhan):** overlay AR
/// ini bergantung pada sensor kompas (arah) DAN accelerometer (kemiringan
/// & kemiringan-samping/roll) perangkat. Rumus-rumus sensor
/// (`KameraRukyatService.pitchDariAccelerometer`/`rollDariAccelerometer`)
/// belum pernah diuji di perangkat fisik -- karena itu ada kontrol
/// "Kalibrasi" di layar ini: kalau marker hilal terasa meleset/terbalik
/// arah naik-turunnya, geser slider kalibrasi sampai cocok dengan
/// pengamatan Anda sendiri (mis. arahkan kamera ke Matahari yang jelas
/// terlihat, cocokkan marker Matahari -- bukan hilal -- ke posisi
/// sebenarnya, baru percaya pada marker hilal).
///
/// Kontrol Exposure Compensation & Focus Lock memakai API resmi paket
/// `camera` (`setExposureOffset`/`setFocusMode`) -- TIDAK termasuk
/// kontrol ISO/Shutter Speed mentah (paket ini tidak menyediakan akses
/// itu; butuh akses Camera2 API native langsung, di luar cakupan
/// implementasi saat ini).
class KameraRukyatScreen extends StatefulWidget {
  const KameraRukyatScreen({super.key});

  @override
  State<KameraRukyatScreen> createState() => _KameraRukyatScreenState();
}

class _KameraRukyatScreenState extends State<KameraRukyatScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  String? _errorKamera;

  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _headingDerajat = 0;
  double _akurasiKompas = -1; // derajat, -1 = tidak diketahui
  double _pitchMentahDerajat = 0;
  double _rollDerajat = 0;
  double _kalibrasiOffset = 0; // derajat, dikoreksi manual oleh pengguna
  bool _sensorTersedia = true;

  KecamatanModel? _lokasi;
  Timer? _timerJam;
  DateTime _sekarangUtc = DateTime.now().toUtc();

  // --- Kontrol kamera manual ---
  double _exposureOffset = 0;
  double _minExposure = 0;
  double _maxExposure = 0;
  bool _fokusTerkunci = false;
  bool _modeGrayscale = false;
  bool _modeMalam = false;

  // --- Haptic saat target terkunci ---
  DateTime? _terakhirGetar;

  double get _pitchTerkoreksi => _pitchMentahDerajat + _kalibrasiOffset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Layar HARUS tetap menyala selama sesi rukyat -- pengamatan bisa
    // berlangsung lama, dan layar mati di tengah pengamatan (mengikuti
    // pengaturan timeout HP biasa) sangat mengganggu. Dimatikan lagi di
    // dispose() begitu pengguna keluar dari layar ini, supaya tidak
    // menguras baterai HP di luar sesi rukyat.
    WakelockPlus.enable();
    _inisialisasiKamera();
    _dengarkanSensor();
    _lokasi = LokasiCacheService.instance.lokasiCache;
    _muatLokasi();
    _timerJam = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _sekarangUtc = DateTime.now().toUtc());
    });
  }

  Future<void> _inisialisasiKamera() async {
    try {
      final kameraTersedia = await availableCameras();
      if (kameraTersedia.isEmpty) {
        setState(() => _errorKamera = 'Tidak ada kamera terdeteksi pada perangkat ini.');
        return;
      }
      final belakang = kameraTersedia.firstWhere(
        (k) => k.lensDirection == CameraLensDirection.back,
        orElse: () => kameraTersedia.first,
      );
      final controller = CameraController(belakang, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      // Rentang exposure compensation didukung -- beberapa perangkat/
      // kamera tidak mendukung sama sekali (min==max==0), kontrol
      // di UI otomatis disembunyikan kalau begitu.
      double minExp = 0, maxExp = 0;
      try {
        minExp = await controller.getMinExposureOffset();
        maxExp = await controller.getMaxExposureOffset();
      } catch (_) {
        // Diamkan -- sebagian perangkat/implementasi kamera tidak
        // mendukung query rentang exposure ini; kontrol otomatis
        // tersembunyi karena min==max==0.
      }
      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _minExposure = minExp;
        _maxExposure = maxExp;
      });
    } catch (e) {
      if (mounted) setState(() => _errorKamera = 'Gagal mengakses kamera: $e');
    }
  }

  void _dengarkanSensor() {
    try {
      if (FlutterCompass.events != null) {
        _compassSub = FlutterCompass.events!.listen((event) {
          if (mounted && event.heading != null) {
            setState(() {
              _headingDerajat = event.heading!;
              _akurasiKompas = event.accuracy ?? -1;
            });
          }
        }, onError: (_) { if (mounted) setState(() => _sensorTersedia = false); });
      } else {
        _sensorTersedia = false;
      }
      _accelSub = accelerometerEventStream().listen((event) {
        if (!mounted) return;
        final pitch = KameraRukyatService.pitchDariAccelerometer(event.x, event.y, event.z);
        final roll = KameraRukyatService.rollDariAccelerometer(event.x, event.y, event.z);
        setState(() {
          _pitchMentahDerajat = pitch;
          _rollDerajat = roll;
        });
      }, onError: (_) { if (mounted) setState(() => _sensorTersedia = false); });
    } catch (_) {
      setState(() => _sensorTersedia = false);
    }
  }

  Future<void> _muatLokasi({bool paksaRefresh = false}) async {
    final lokasi = await LokasiCacheService.instance.ambilLokasi(paksaRefresh: paksaRefresh);
    if (mounted && lokasi != null) setState(() => _lokasi = lokasi);
  }

  Future<void> _gantiLokasi() async {
    final terpilih = await LocationPickerSheet.show(context, judul: 'Pilih Lokasi Pengamatan');
    if (terpilih == kPilihGpsSentinel) {
      await _muatLokasi(paksaRefresh: true);
    } else if (terpilih is KecamatanModel) {
      LokasiCacheService.instance.simpan(terpilih);
      setState(() => _lokasi = terpilih);
    }
  }

  Future<void> _jepret() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final file = await controller.takePicture();
      final dir = await getApplicationDocumentsDirectory();
      final namaFile = 'rukyat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(file.path).copy('${dir.path}/$namaFile');
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto tersimpan: $namaFile')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan foto: $e')));
      }
    }
  }

  Future<void> _toggleFokusKunci() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final baru = !_fokusTerkunci;
    try {
      await controller.setFocusMode(baru ? FocusMode.locked : FocusMode.auto);
      setState(() => _fokusTerkunci = baru);
      HapticFeedback.selectionClick();
    } catch (_) {
      // Diamkan -- sebagian perangkat/implementasi kamera tidak
      // mendukung kunci fokus manual; tombol tetap ada tapi tidak
      // berefek pada perangkat itu.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perangkat ini tidak mendukung kunci fokus manual.')),
        );
      }
    }
  }

  Future<void> _ubahExposure(double nilai) async {
    setState(() => _exposureOffset = nilai);
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.setExposureOffset(nilai);
    } catch (_) {
      // Diamkan -- sebagian perangkat tidak mendukung, slider tetap
      // ada tapi tidak berefek nyata pada gambar di perangkat itu.
    }
  }

  /// Getaran haptic singkat saat target (Hilal) TEPAT di tengah
  /// crosshair -- dengan jeda 2 detik antar getaran supaya tidak
  /// bergetar terus-menerus selama target tetap terkunci.
  void _cekTargetTerkunci((double, double)? posisiHilal) {
    if (posisiHilal == null || _lokasi == null) return;
    final (selAz, selTinggi) = KameraRukyatService.selisihArahKeTarget(
      azimutTarget: posisiHilal.$1, tinggiTarget: posisiHilal.$2,
      headingKamera: _headingDerajat, pitchKamera: _pitchTerkoreksi,
    );
    const ambangKunci = 1.5; // derajat
    final terkunci = selAz.abs() < ambangKunci && selTinggi.abs() < ambangKunci;
    if (!terkunci) return;
    final sekarang = DateTime.now();
    if (_terakhirGetar == null || sekarang.difference(_terakhirGetar!) > const Duration(seconds: 2)) {
      _terakhirGetar = sekarang;
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // PENTING (perbaikan crash nyata FLUTTER-3 dari Sentry): setelah
      // dispose(), _cameraController WAJIB di-null-kan + setState() supaya
      // build() (dipicu timer jam yang tetap berjalan) jatuh ke tampilan
      // loading, bukan mencoba CameraPreview(_cameraController!) dengan
      // controller yang sudah dibuang -- itulah penyebab
      // "buildPreview() was called on a disposed CameraController".
      controller.dispose();
      if (mounted) setState(() => _cameraController = null);
    } else if (state == AppLifecycleState.resumed) {
      _inisialisasiKamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _cameraController?.dispose();
    _compassSub?.cancel();
    _accelSub?.cancel();
    _timerJam?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warnaAksen = _modeMalam ? _merahMalam : AppColors.emerald;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: _modeMalam ? _merahMalam : Colors.white,
        title: Text('Kamera Rukyat', style: TextStyle(color: _modeMalam ? _merahMalam : Colors.white)),
        iconTheme: IconThemeData(color: _modeMalam ? _merahMalam : Colors.white),
        actions: [
          IconButton(
            tooltip: _modeMalam ? 'Matikan mode malam' : 'Mode malam (red-light)',
            icon: Icon(_modeMalam ? Icons.nightlight_round : Icons.nightlight_outlined, color: warnaAksen),
            onPressed: () => setState(() => _modeMalam = !_modeMalam),
          ),
          HomeButton(),
        ],
      ),
      body: SafeArea(
        child: _errorKamera != null
            ? _tampilanError()
            : _cameraController == null || !_cameraController!.value.isInitialized
                ? Center(child: CircularProgressIndicator(color: warnaAksen))
                : _tampilanKamera(warnaAksen),
      ),
    );
  }

  Widget _tampilanError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(_errorKamera!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _tampilanKamera(Color warnaAksen) {
    final lokasi = _lokasi;
    (double, double)? posisiHilal;
    (double, double)? posisiMatahari;
    double? elongasi;
    double? umurBulanJam;
    DateTime? ghurubMatahari;
    DateTime? ghurubBulan;
    double? lagMenit;
    if (lokasi != null) {
      posisiHilal = KameraRukyatService.posisiBulanSaatIni(utc: _sekarangUtc, lat: lokasi.lat, lng: lokasi.lng);
      posisiMatahari = KameraRukyatService.posisiMatahariSaatIni(utc: _sekarangUtc, lat: lokasi.lat, lng: lokasi.lng);
      elongasi = KameraRukyatService.elongasiSaatIni(utc: _sekarangUtc);
      umurBulanJam = KameraRukyatService.umurBulanJam(utc: _sekarangUtc);
      ghurubMatahari = KameraRukyatService.ghurubMatahari(tanggalUtc: _sekarangUtc, lat: lokasi.lat, lng: lokasi.lng);
      ghurubBulan = KameraRukyatService.ghurubBulan(tanggalUtc: _sekarangUtc, lat: lokasi.lat, lng: lokasi.lng);
      lagMenit = KameraRukyatService.lagMenit(tanggalUtc: _sekarangUtc, lat: lokasi.lat, lng: lokasi.lng);
      _cekTargetTerkunci(posisiHilal);
    }

    Widget preview = CameraPreview(_cameraController!);
    if (_modeGrayscale) {
      preview = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: preview,
      );
    }
    if (_modeMalam) {
      // Overlay merah transparan di atas preview -- bukan mengubah warna
      // asli citra (supaya hasil FOTO tetap warna asli), cuma tampilan
      // layar saat live-view demi menjaga adaptasi gelap mata pengamat.
      preview = Stack(fit: StackFit.expand, children: [
        preview,
        Container(color: _merahMalam.withOpacity(0.18)),
      ]);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        preview,
        LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _OverlayPainter(
                headingDerajat: _headingDerajat,
                pitchDerajat: _pitchTerkoreksi,
                posisiHilal: posisiHilal,
                posisiMatahari: posisiMatahari,
                warnaAksen: warnaAksen,
                modeMalam: _modeMalam,
              ),
            );
          },
        ),
        // --- HUD atas: koordinat, arah kompas, jam presisi, status sensor ---
        Positioned(
          left: 10, right: 10, top: 6,
          child: _hudAtas(lokasi, warnaAksen),
        ),
        if (!_sensorTersedia)
          Positioned(
            top: 60, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.85), borderRadius: BorderRadius.circular(8)),
                child: const Text('Sensor kompas/kemiringan tidak tersedia -- overlay tidak akurat', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          )
        else if (_akurasiKompas >= 0 && _akurasiKompas > 15)
          // CATATAN JUJUR: skala pasti nilai `accuracy` dari flutter_compass
          // (derajat kontinu, atau level diskrit 0-3) belum saya pastikan
          // tanpa uji di device sungguhan -- ambang "15" di sini asumsi
          // "derajat", bisa jadi perlu disesuaikan (mis. jadi ambang ">1"
          // kalau ternyata levelnya diskrit). Peringatan ini aman diabaikan
          // kalau ternyata salah ambang -- tidak memengaruhi akurasi
          // overlay itu sendiri, cuma teks bantuan.
          Positioned(
            top: 60, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.orange.shade900.withOpacity(0.85), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.explore_off_outlined, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text('Kompas kurang akurat -- gerakkan HP pola angka 8 untuk kalibrasi ulang', style: TextStyle(color: Colors.white, fontSize: 10.5)),
                  ],
                ),
              ),
            ),
          ),
        // --- Waterpass digital (kiri atas, di bawah HUD) ---
        Positioned(
          left: 10, top: 78,
          child: _waterpass(warnaAksen),
        ),
        Positioned(
          left: 10, right: 10, bottom: 96,
          child: _panelInfo(lokasi, posisiHilal, posisiMatahari, elongasi, umurBulanJam, ghurubMatahari, ghurubBulan, lagMenit, warnaAksen),
        ),
        // --- Kontrol thumb-zone: semua di area bawah, mudah dijangkau satu tangan ---
        Positioned(
          left: 10, right: 10, bottom: 8,
          child: _kontrolBawah(warnaAksen),
        ),
      ],
    );
  }

  Widget _hudAtas(KecamatanModel? lokasi, Color warnaAksen) {
    final jamStr = '${_sekarangUtc.toLocal().hour.toString().padLeft(2, '0')}:'
        '${_sekarangUtc.toLocal().minute.toString().padLeft(2, '0')}:'
        '${_sekarangUtc.toLocal().second.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.gps_fixed, size: 12, color: lokasi != null ? warnaAksen : Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              lokasi != null ? '${lokasi.lat.toStringAsFixed(4)}, ${lokasi.lng.toStringAsFixed(4)}' : 'Lokasi belum tersedia',
              style: TextStyle(color: _modeMalam ? _merahMalam : Colors.white, fontSize: 10.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.explore_outlined, size: 12, color: _modeMalam ? _merahMalam : Colors.white70),
          const SizedBox(width: 3),
          Text('${_headingDerajat.toStringAsFixed(0)}\u00b0', style: TextStyle(color: _modeMalam ? _merahMalam : Colors.white70, fontSize: 10.5)),
          const SizedBox(width: 8),
          Text(jamStr, style: TextStyle(color: _modeMalam ? _merahMalam : Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Indikator waterpass digital sederhana -- lingkaran dengan titik yang
  /// bergeser sesuai pitch (atas-bawah) & roll (kiri-kanan) perangkat.
  /// Titik hijau/merah di tengah lingkaran = HP benar-benar rata.
  Widget _waterpass(Color warnaAksen) {
    const ukuran = 56.0;
    const batasDerajat = 20.0; // rentang tampilan penuh lingkaran
    final dx = (_rollDerajat / batasDerajat).clamp(-1.0, 1.0) * (ukuran / 2 - 8);
    final dy = (_pitchTerkoreksi / batasDerajat).clamp(-1.0, 1.0) * (ukuran / 2 - 8);
    final rata = _rollDerajat.abs() < 1.5 && _pitchTerkoreksi.abs() < 1.5;
    return Container(
      width: ukuran, height: ukuran,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        shape: BoxShape.circle,
        border: Border.all(color: (rata ? Colors.greenAccent : Colors.white24), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 1, height: ukuran, color: Colors.white24),
          Container(width: ukuran, height: 1, color: Colors.white24),
          Transform.translate(
            offset: Offset(dx, dy),
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: rata ? Colors.greenAccent : Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelInfo(
    KecamatanModel? lokasi,
    (double, double)? posisiHilal,
    (double, double)? posisiMatahari,
    double? elongasi,
    double? umurBulanJam,
    DateTime? ghurubMatahari,
    DateTime? ghurubBulan,
    double? lagMenit,
    Color warnaAksen,
  ) {
    String fmtJamWib(DateTime? utc) {
      if (utc == null) return '--:--';
      final wib = utc.add(const Duration(hours: 7));
      return '${wib.hour.toString().padLeft(2, '0')}:${wib.minute.toString().padLeft(2, '0')} WIB';
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade300),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  lokasi?.kecamatan ?? 'Lokasi belum tersedia',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: _gantiLokasi,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: Text('Ganti', style: TextStyle(fontSize: 11, color: warnaAksen)),
              ),
            ],
          ),
          if (posisiHilal != null) ...[
            const SizedBox(height: 4),
            Text(
              'Hilal: azimut ${posisiHilal.$1.toStringAsFixed(1)}\u00b0, tinggi ${posisiHilal.$2.toStringAsFixed(1)}\u00b0'
              '${elongasi != null ? ', elong. ${elongasi.toStringAsFixed(1)}\u00b0' : ''}'
              '${umurBulanJam != null ? ', umur ~${umurBulanJam.toStringAsFixed(1)} jam' : ''}',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
          if (posisiMatahari != null) ...[
            Text(
              'Matahari: azimut ${posisiMatahari.$1.toStringAsFixed(1)}\u00b0, tinggi ${posisiMatahari.$2.toStringAsFixed(1)}\u00b0',
              style: TextStyle(color: Colors.orange.shade200, fontSize: 11),
            ),
          ],
          if (ghurubMatahari != null || ghurubBulan != null) ...[
            const SizedBox(height: 2),
            Text(
              'Ghurub: Matahari ${fmtJamWib(ghurubMatahari)}  \u2022  Bulan ${fmtJamWib(ghurubBulan)}'
              '${lagMenit != null ? '  \u2022  Lag ${lagMenit.toStringAsFixed(0)} mnt' : ''}',
              style: TextStyle(color: Colors.grey.shade300, fontSize: 10.5),
            ),
          ],
          Text(
            'Kamera: arah ${_headingDerajat.toStringAsFixed(0)}\u00b0, kemiringan ${_pitchTerkoreksi.toStringAsFixed(0)}\u00b0',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Kalibrasi:', style: TextStyle(color: Colors.grey, fontSize: 10.5)),
              Expanded(
                child: Slider(
                  value: _kalibrasiOffset,
                  min: -30, max: 30,
                  activeColor: warnaAksen,
                  onChanged: (v) => setState(() => _kalibrasiOffset = v),
                ),
              ),
              Text('${_kalibrasiOffset.toStringAsFixed(0)}\u00b0', style: const TextStyle(color: Colors.grey, fontSize: 10.5)),
            ],
          ),
          if (_maxExposure > _minExposure)
            Row(
              children: [
                Icon(Icons.exposure, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Expanded(
                  child: Slider(
                    value: _exposureOffset.clamp(_minExposure, _maxExposure),
                    min: _minExposure, max: _maxExposure,
                    activeColor: warnaAksen,
                    onChanged: _ubahExposure,
                  ),
                ),
                Text(_exposureOffset.toStringAsFixed(1), style: const TextStyle(color: Colors.grey, fontSize: 10.5)),
              ],
            ),
        ],
      ),
    );
  }

  /// Semua tombol kontrol ditempatkan di sini (thumb-zone, bawah layar)
  /// supaya mudah dijangkau satu ibu jari saat HP dipasang di tripod.
  Widget _kontrolBawah(Color warnaAksen) {
    Widget tombolBulat({required IconData icon, required VoidCallback onTap, bool aktif = false, String? tooltip}) {
      return Tooltip(
        message: tooltip ?? '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: aktif ? warnaAksen.withOpacity(0.9) : Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
              border: Border.all(color: aktif ? warnaAksen : Colors.white24, width: 1.5),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        tombolBulat(
          icon: _modeGrayscale ? Icons.filter_b_and_w : Icons.filter_b_and_w_outlined,
          aktif: _modeGrayscale,
          tooltip: 'Mode Monokrom',
          onTap: () => setState(() => _modeGrayscale = !_modeGrayscale),
        ),
        tombolBulat(
          icon: _fokusTerkunci ? Icons.center_focus_strong : Icons.center_focus_weak_outlined,
          aktif: _fokusTerkunci,
          tooltip: 'Kunci Fokus',
          onTap: _toggleFokusKunci,
        ),
        InkWell(
          onTap: _jepret,
          borderRadius: BorderRadius.circular(36),
          child: Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              color: warnaAksen,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
          ),
        ),
        tombolBulat(
          icon: Icons.refresh_rounded,
          tooltip: 'Segarkan Lokasi',
          onTap: () => _muatLokasi(paksaRefresh: true),
        ),
        tombolBulat(
          icon: Icons.wb_iridescent_outlined,
          tooltip: 'Reset Exposure',
          onTap: () => _ubahExposure(0),
        ),
      ],
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double headingDerajat;
  final double pitchDerajat;
  final (double, double)? posisiHilal;
  final (double, double)? posisiMatahari;
  final Color warnaAksen;
  final bool modeMalam;

  _OverlayPainter({
    required this.headingDerajat, required this.pitchDerajat,
    this.posisiHilal, this.posisiMatahari,
    required this.warnaAksen, required this.modeMalam,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final warnaCrosshair = modeMalam ? _merahMalam.withOpacity(0.7) : Colors.white.withOpacity(0.6);
    final paintCrosshair = Paint()..color = warnaCrosshair..strokeWidth = 1;
    final pusat = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(pusat.translate(-14, 0), pusat.translate(14, 0), paintCrosshair);
    canvas.drawLine(pusat.translate(0, -14), pusat.translate(0, 14), paintCrosshair);
    canvas.drawCircle(pusat, 30, Paint()..color = warnaCrosshair..style = PaintingStyle.stroke..strokeWidth = 1);

    const fovVertikal = 45.0;
    final fracHorizon = (-pitchDerajat) / (fovVertikal / 2);
    if (fracHorizon.abs() < 1.5) {
      final yHorizon = size.height / 2 - fracHorizon * (size.height / 2);
      canvas.drawLine(
        Offset(0, yHorizon), Offset(size.width, yHorizon),
        Paint()..color = (modeMalam ? _merahMalam : Colors.cyanAccent).withOpacity(0.5)..strokeWidth = 1.5,
      );
    }

    final warnaMatahari = modeMalam ? _merahMalam : Colors.orange;
    final warnaHilal = modeMalam ? _merahMalam : Colors.greenAccent;

    if (posisiMatahari != null) {
      final (az, tinggi) = posisiMatahari!;
      final p = KameraRukyatService.proyeksiKeLayar(
        azimutTarget: az, tinggiTarget: tinggi,
        headingKamera: headingDerajat, pitchKamera: pitchDerajat,
        lebarLayar: size.width, tinggiLayar: size.height,
      );
      if (p != null) {
        _gambarMarker(canvas, Offset(p.$1, p.$2), warnaMatahari, 'Matahari');
      } else {
        final (selAz, selTinggi) = KameraRukyatService.selisihArahKeTarget(
          azimutTarget: az, tinggiTarget: tinggi,
          headingKamera: headingDerajat, pitchKamera: pitchDerajat,
        );
        _gambarPanahTepi(canvas, size, selAz, selTinggi, warnaMatahari, 'Matahari');
      }
    }

    if (posisiHilal != null) {
      final (az, tinggi) = posisiHilal!;
      final p = KameraRukyatService.proyeksiKeLayar(
        azimutTarget: az, tinggiTarget: tinggi,
        headingKamera: headingDerajat, pitchKamera: pitchDerajat,
        lebarLayar: size.width, tinggiLayar: size.height,
      );
      if (p != null) {
        _gambarMarker(canvas, Offset(p.$1, p.$2), warnaHilal, 'Hilal');
      } else {
        final (selAz, selTinggi) = KameraRukyatService.selisihArahKeTarget(
          azimutTarget: az, tinggiTarget: tinggi,
          headingKamera: headingDerajat, pitchKamera: pitchDerajat,
        );
        _gambarPanahTepi(canvas, size, selAz, selTinggi, warnaHilal, 'Hilal');
      }
    }
  }

  /// Panah di tepi layar menunjuk ke arah target yang berada di LUAR
  /// bidang pandang kamera saat ini -- membantu pengguna tahu ke mana
  /// harus memutar/mengarahkan HP tanpa perlu menebak-nebak. Sudut
  /// putar panah dihitung dari selisih azimut (kiri/kanan) & tinggi
  /// (atas/bawah) gabungan, diproyeksikan ke tepi persegi panjang layar
  /// (bukan lingkaran) supaya panahnya selalu pas di pinggir, di sisi
  /// yang benar (atas/bawah/kiri/kanan/pojok).
  void _gambarPanahTepi(Canvas canvas, Size size, double selisihAzimut, double selisihTinggi, Color warna, String label) {
    final pusat = Offset(size.width / 2, size.height / 2);
    // Sumbu Y layar terbalik dari "tinggi" (naik = nilai Y makin kecil).
    final arahX = selisihAzimut;
    final arahY = -selisihTinggi;
    if (arahX == 0 && arahY == 0) return;

    // Proyeksikan arah (arahX, arahY) ke tepi kotak layar (bukan lingkaran)
    // -- cari faktor skala terkecil supaya titik (arahX*t, arahY*t) tepat
    // menyentuh salah satu dari 4 sisi kotak (dengan margin dari tepi).
    const margin = 36.0;
    final batasX = size.width / 2 - margin;
    final batasY = size.height / 2 - margin;
    final tX = arahX == 0 ? double.infinity : (batasX / arahX.abs());
    final tY = arahY == 0 ? double.infinity : (batasY / arahY.abs());
    final t = tX < tY ? tX : tY;
    final titikTepi = pusat.translate(arahX * t, arahY * t);

    final sudutRotasi = atan2(arahY, arahX);
    final jarakDerajat = sqrt(selisihAzimut * selisihAzimut + selisihTinggi * selisihTinggi);

    canvas.save();
    canvas.translate(titikTepi.dx, titikTepi.dy);
    canvas.rotate(sudutRotasi);
    final path = Path()
      ..moveTo(14, 0)
      ..lineTo(-8, -9)
      ..lineTo(-8, 9)
      ..close();
    canvas.drawPath(path, Paint()..color = warna.withOpacity(0.9));
    canvas.restore();

    final tp = TextPainter(
      text: TextSpan(
        text: '$label  ${jarakDerajat.toStringAsFixed(0)}\u00b0',
        style: TextStyle(color: warna, fontSize: 10.5, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black, blurRadius: 3)]),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    // Label diletakkan agak menjauh dari ujung panah ke arah pusat layar,
    // supaya tidak terpotong tepi layar.
    final arahPanjang = sqrt(arahX * arahX + arahY * arahY);
    final offsetLabel = titikTepi.translate(-arahX / arahPanjang * 30 - tp.width / 2, -arahY / arahPanjang * 30 - tp.height / 2);
    tp.paint(canvas, offsetLabel);
  }

  void _gambarMarker(Canvas canvas, Offset pos, Color warna, String label) {
    canvas.drawCircle(pos, 18, Paint()..color = warna.withOpacity(0.15));
    canvas.drawCircle(pos, 18, Paint()..color = warna..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawLine(pos.translate(-24, 0), pos.translate(-18, 0), Paint()..color = warna..strokeWidth = 2);
    canvas.drawLine(pos.translate(18, 0), pos.translate(24, 0), Paint()..color = warna..strokeWidth = 2);
    canvas.drawLine(pos.translate(0, -24), pos.translate(0, -18), Paint()..color = warna..strokeWidth = 2);
    canvas.drawLine(pos.translate(0, 18), pos.translate(0, 24), Paint()..color = warna..strokeWidth = 2);

    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: warna, fontSize: 11, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black, blurRadius: 3)])),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, pos.translate(-tp.width / 2, 22));
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.headingDerajat != headingDerajat ||
      oldDelegate.pitchDerajat != pitchDerajat ||
      oldDelegate.posisiHilal != posisiHilal ||
      oldDelegate.posisiMatahari != posisiMatahari ||
      oldDelegate.modeMalam != modeMalam;
}
