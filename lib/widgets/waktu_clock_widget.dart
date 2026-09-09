import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/kecamatan_model.dart';
import '../services/lokasi_cache_service.dart';
import '../theme/app_theme.dart';

/// Kartu jam WIB (waktu zona resmi) + Waktu Istiwa' (waktu matahari
/// lokal sejati, di mana Dhuhur/zawal selalu tepat jam 12:00) --
/// diletakkan paling atas Home sesuai permintaan pengguna.
///
/// Rumus equation-of-time SENGAJA diduplikasi di sini (bukan dipanggil
/// dari KalkulatorService) mengikuti pola yang sudah dipakai di seluruh
/// aplikasi -- supaya mesin lain yang sudah tervalidasi tidak berisiko
/// tersentuh oleh perubahan di widget UI ini.
class WaktuClockWidget extends StatefulWidget {
  const WaktuClockWidget({super.key});

  @override
  State<WaktuClockWidget> createState() => _WaktuClockWidgetState();
}

class _WaktuClockWidgetState extends State<WaktuClockWidget> {
  Timer? _timer;
  DateTime _sekarang = DateTime.now();
  KecamatanModel? _lokasi;

  @override
  void initState() {
    super.initState();
    _lokasi = LokasiCacheService.instance.lokasiCache;
    _muatLokasi();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _sekarang = DateTime.now());
    });
  }

  Future<void> _muatLokasi() async {
    final lokasi = await LokasiCacheService.instance.ambilLokasi();
    if (mounted && lokasi != null) setState(() => _lokasi = lokasi);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static double _sind(double x) => sin(x * pi / 180);
  static double _cosd(double x) => cos(x * pi / 180);
  static double _tand(double x) => tan(x * pi / 180);

  static double _julianDay(DateTime utc) {
    final y = utc.year, m = utc.month;
    final d = utc.day + (utc.hour + utc.minute / 60 + utc.second / 3600) / 24;
    int yy = y, mm = m;
    if (mm <= 2) { yy -= 1; mm += 12; }
    final a = (yy / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (yy + 4716)).floor() + (30.6001 * (mm + 1)).floor() + d + b - 1524.5;
  }

  /// Equation of time (menit) -- rumus Meeus, sama seperti yang sudah
  /// tervalidasi berkali-kali di seluruh aplikasi (waktu shalat, Rashdul
  /// Kiblat, dll.)
  static double _equationOfTimeMenit(double jd) {
    final t = (jd - 2451545.0) / 36525.0;
    final l0 = (280.46646 + 36000.76983 * t + 0.0003032 * t * t) % 360;
    final m = (357.52911 + 35999.05029 * t - 0.0001537 * t * t) % 360;
    final eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    final e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t;
    final y = pow(_tand(eps0 / 2), 2).toDouble();
    final eot = y * _sind(2 * l0) -
        2 * e * _sind(m) +
        4 * e * y * _sind(m) * _cosd(2 * l0) -
        0.5 * y * y * _sind(4 * l0) -
        1.25 * e * e * _sind(2 * m);
    return eot * 180 / pi * 4;
  }

  /// Waktu Istiwa' (jam desimal, 0-24) untuk lokasi & saat ini.
  double _hitungIstiwa() {
    final lokasi = _lokasi;
    if (lokasi == null || lokasi.utcOffset == null) return 0;
    final jd = _julianDay(_sekarang.toUtc());
    final eot = _equationOfTimeMenit(jd);
    final jamWib = _sekarang.hour + _sekarang.minute / 60 + _sekarang.second / 3600;
    // Istiwa = Waktu Zona - selisih_jam, dengan selisih_jam = eot/60 + bujur/15 - utcOffset
    final selisihJam = eot / 60 + lokasi.lng / 15 - lokasi.utcOffset!;
    var istiwa = jamWib + selisihJam;
    istiwa = istiwa % 24;
    if (istiwa < 0) istiwa += 24;
    return istiwa;
  }

  String _formatJam(double jamDesimal) {
    final h = jamDesimal.floor() % 24;
    final m = ((jamDesimal - jamDesimal.floor()) * 60).floor();
    final s = (((jamDesimal - jamDesimal.floor()) * 60 - m) * 60).round();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final jamWib = '${_sekarang.hour.toString().padLeft(2, '0')}:${_sekarang.minute.toString().padLeft(2, '0')}:${_sekarang.second.toString().padLeft(2, '0')}';
    final istiwa = _lokasi != null ? _formatJam(_hitungIstiwa()) : '--:--:--';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WIB', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(jamWib, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? AppColors.textDark : AppColors.textLight)),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: isDark ? Colors.white12 : Colors.black12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Istiwa\'', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(istiwa, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.emerald)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
