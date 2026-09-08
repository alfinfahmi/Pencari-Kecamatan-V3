import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import '../models/kecamatan_model.dart';
import '../services/kamera_rukyat_service.dart';
import '../services/reverse_geocode_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/home_button.dart';
import '../widgets/location_picker_sheet.dart';

/// Layar "Kamera Rukyat" -- live view kamera dengan overlay AR posisi
/// hilal terhitung (azimut & tinggi), plus garis ufuk & info pendukung.
///
/// **PENTING (baca sebelum uji coba di device sungguhan):** overlay AR
/// ini bergantung pada sensor kompas (arah) DAN accelerometer (kemiringan)
/// perangkat. Rumus kemiringannya (`KameraRukyatService.pitchDariAccelerometer`)
/// belum pernah diuji di perangkat fisik -- karena itu ada kontrol
/// "Kalibrasi" di layar ini: kalau marker hilal terasa meleset/terbalik
/// arah naik-turunnya, geser slider kalibrasi sampai cocok dengan
/// pengamatan Anda sendiri (mis. arahkan kamera ke Matahari yang jelas
/// terlihat, cocokkan marker Matahari -- bukan hilal -- ke posisi
/// sebenarnya, baru percaya pada marker hilal).
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
  double _pitchMentahDerajat = 0;
  double _kalibrasiOffset = 0; // derajat, dikoreksi manual oleh pengguna
  bool _sensorTersedia = true;

  KecamatanModel? _lokasi;
  Timer? _timerJam;
  DateTime _sekarangUtc = DateTime.now().toUtc();

  double get _pitchTerkoreksi => _pitchMentahDerajat + _kalibrasiOffset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inisialisasiKamera();
    _dengarkanSensor();
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
      if (!mounted) return;
      setState(() => _cameraController = controller);
    } catch (e) {
      if (mounted) setState(() => _errorKamera = 'Gagal mengakses kamera: $e');
    }
  }

  void _dengarkanSensor() {
    try {
      if (FlutterCompass.events != null) {
        _compassSub = FlutterCompass.events!.listen((event) {
          if (mounted && event.heading != null) setState(() => _headingDerajat = event.heading!);
        }, onError: (_) { if (mounted) setState(() => _sensorTersedia = false); });
      } else {
        _sensorTersedia = false;
      }
      _accelSub = accelerometerEventStream().listen((event) {
        if (!mounted) return;
        final pitch = KameraRukyatService.pitchDariAccelerometer(event.x, event.y, event.z);
        setState(() => _pitchMentahDerajat = pitch);
      }, onError: (_) { if (mounted) setState(() => _sensorTersedia = false); });
    } catch (_) {
      setState(() => _sensorTersedia = false);
    }
  }

  Future<void> _muatLokasi() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final pos = await Geolocator.getCurrentPosition();
      final lokasi = await lengkapiInfoLokasiGps(
        lat: pos.latitude, lng: pos.longitude,
        elevasiM: pos.altitude > 0 ? pos.altitude.round() : 0,
        zonaWaktu: 'WIB', utcOffset: 7,
      );
      if (mounted) setState(() => _lokasi = lokasi);
    } catch (_) {
      // Diamkan -- pengguna tetap bisa pilih lokasi manual.
    }
  }

  Future<void> _gantiLokasi() async {
    final terpilih = await LocationPickerSheet.show(context, judul: 'Pilih Lokasi Pengamatan');
    if (terpilih == kPilihGpsSentinel) {
      await _muatLokasi();
    } else if (terpilih is KecamatanModel) {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _inisialisasiKamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _compassSub?.cancel();
    _accelSub?.cancel();
    _timerJam?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: const Text('Kamera Rukyat'),
        actions: [HomeButton()],
      ),
      body: SafeArea(
        child: _errorKamera != null
            ? _tampilanError()
            : _cameraController == null || !_cameraController!.value.isInitialized
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _tampilanKamera(),
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

  Widget _tampilanKamera() {
    final lokasi = _lokasi;
    (double, double)? posisiHilal;
    (double, double)? posisiMatahari;
    if (lokasi != null) {
      posisiHilal = KameraRukyatService.posisiBulanSaatIni(utc: _sekarangUtc, lat: lokasi.lat, lng: lokasi.lng);
      posisiMatahari = KameraRukyatService.posisiMatahariSaatIni(utc: _sekarangUtc, lat: lokasi.lat, lng: lokasi.lng);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _OverlayPainter(
                headingDerajat: _headingDerajat,
                pitchDerajat: _pitchTerkoreksi,
                posisiHilal: posisiHilal,
                posisiMatahari: posisiMatahari,
              ),
            );
          },
        ),
        if (!_sensorTersedia)
          Positioned(
            top: 8, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.red.shade900.withOpacity(0.85), borderRadius: BorderRadius.circular(8)),
                child: const Text('Sensor kompas/kemiringan tidak tersedia -- overlay tidak akurat', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ),
        Positioned(
          left: 10, right: 10, bottom: 10,
          child: _panelInfo(lokasi, posisiHilal, posisiMatahari),
        ),
        Positioned(
          right: 10, top: 10,
          child: FloatingActionButton(
            heroTag: 'jepret',
            backgroundColor: AppColors.emerald,
            onPressed: _jepret,
            child: const Icon(Icons.camera_alt),
          ),
        ),
      ],
    );
  }

  Widget _panelInfo(KecamatanModel? lokasi, (double, double)? posisiHilal, (double, double)? posisiMatahari) {
    return Container(
      padding: const EdgeInsets.all(12),
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
                child: const Text('Ganti', style: TextStyle(fontSize: 11, color: AppColors.gold)),
              ),
            ],
          ),
          if (posisiHilal != null) ...[
            const SizedBox(height: 4),
            Text(
              'Hilal (terhitung): azimut ${posisiHilal.$1.toStringAsFixed(1)}\u00b0, tinggi ${posisiHilal.$2.toStringAsFixed(1)}\u00b0',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          if (posisiMatahari != null) ...[
            Text(
              'Matahari: azimut ${posisiMatahari.$1.toStringAsFixed(1)}\u00b0, tinggi ${posisiMatahari.$2.toStringAsFixed(1)}\u00b0',
              style: TextStyle(color: Colors.orange.shade200, fontSize: 11),
            ),
          ],
          Text(
            'Kamera: arah ${_headingDerajat.toStringAsFixed(0)}\u00b0, kemiringan ${_pitchTerkoreksi.toStringAsFixed(0)}\u00b0',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Kalibrasi:', style: TextStyle(color: Colors.grey, fontSize: 10.5)),
              Expanded(
                child: Slider(
                  value: _kalibrasiOffset,
                  min: -30, max: 30,
                  activeColor: AppColors.gold,
                  onChanged: (v) => setState(() => _kalibrasiOffset = v),
                ),
              ),
              Text('${_kalibrasiOffset.toStringAsFixed(0)}\u00b0', style: const TextStyle(color: Colors.grey, fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final double headingDerajat;
  final double pitchDerajat;
  final (double, double)? posisiHilal;
  final (double, double)? posisiMatahari;

  _OverlayPainter({required this.headingDerajat, required this.pitchDerajat, this.posisiHilal, this.posisiMatahari});

  @override
  void paint(Canvas canvas, Size size) {
    final paintCrosshair = Paint()..color = Colors.white.withOpacity(0.6)..strokeWidth = 1;
    final pusat = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(pusat.translate(-14, 0), pusat.translate(14, 0), paintCrosshair);
    canvas.drawLine(pusat.translate(0, -14), pusat.translate(0, 14), paintCrosshair);

    const fovVertikal = 45.0;
    final fracHorizon = (-pitchDerajat) / (fovVertikal / 2);
    if (fracHorizon.abs() < 1.5) {
      final yHorizon = size.height / 2 - fracHorizon * (size.height / 2);
      canvas.drawLine(
        Offset(0, yHorizon), Offset(size.width, yHorizon),
        Paint()..color = Colors.cyanAccent.withOpacity(0.5)..strokeWidth = 1.5,
      );
    }

    if (posisiMatahari != null) {
      final (az, tinggi) = posisiMatahari!;
      final p = KameraRukyatService.proyeksiKeLayar(
        azimutTarget: az, tinggiTarget: tinggi,
        headingKamera: headingDerajat, pitchKamera: pitchDerajat,
        lebarLayar: size.width, tinggiLayar: size.height,
      );
      if (p != null) _gambarMarker(canvas, Offset(p.$1, p.$2), Colors.orange, 'Matahari');
    }

    if (posisiHilal != null) {
      final (az, tinggi) = posisiHilal!;
      final p = KameraRukyatService.proyeksiKeLayar(
        azimutTarget: az, tinggiTarget: tinggi,
        headingKamera: headingDerajat, pitchKamera: pitchDerajat,
        lebarLayar: size.width, tinggiLayar: size.height,
      );
      if (p != null) _gambarMarker(canvas, Offset(p.$1, p.$2), Colors.greenAccent, 'Hilal');
    }
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
      oldDelegate.posisiMatahari != posisiMatahari;
}
