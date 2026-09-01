import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import '../theme/app_theme.dart';

/// Kompas kiblat — digambar manual dengan CustomPainter, TIDAK memakai tile
/// peta online, sehingga tetap konsisten dengan syarat aplikasi 100% offline.
///
/// Dua mode:
/// - LIVE: mengikuti sensor magnetometer perangkat sungguhan.
/// - STATIS: fallback kalau sensor tak tersedia (desktop/web), utara tetap
///   di atas, derajat bearing tetap akurat.
class QiblaCompass extends StatefulWidget {
  final double bearingDerajat;
  final double size;

  const QiblaCompass({
    super.key,
    required this.bearingDerajat,
    this.size = 180,
  });

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  StreamSubscription<CompassEvent>? _subscription;
  double? _headingDerajat;
  bool _sensorError = false;

  @override
  void initState() {
    super.initState();
    _listenCompass();
  }

  void _listenCompass() {
    try {
      if (FlutterCompass.events == null) {
        setState(() => _sensorError = true);
        return;
      }
      _subscription = FlutterCompass.events!.listen(
        (event) {
          if (!mounted) return;
          if (event.heading == null) return;
          setState(() => _headingDerajat = event.heading);
        },
        onError: (_) {
          if (mounted) setState(() => _sensorError = true);
        },
      );
    } catch (_) {
      setState(() => _sensorError = true);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool get _isLive => !_sensorError && _headingDerajat != null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialRotationDeg = _isLive ? -(_headingDerajat!) : 0.0;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size - 6,
            height: widget.size - 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: dialRotationDeg * pi / 180,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _CompassPainter(
                bearingDerajat: widget.bearingDerajat,
                isDark: isDark,
              ),
            ),
          ),
          if (_isLive)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double bearingDerajat;
  final bool isDark;

  _CompassPainter({required this.bearingDerajat, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    _drawBezel(canvas, center, radius);
    _drawTicks(canvas, center, radius);
    _drawLabels(canvas, center, radius);
    _drawNeedle(canvas, center, radius);
    _drawCenterPin(canvas, center);
  }

  void _drawBezel(Canvas canvas, Offset center, double radius) {
    final faceColors = isDark
        ? [const Color(0xFF232320), const Color(0xFF16150F)]
        : [Colors.white, const Color(0xFFF3F0E8)];

    final facePaint = Paint()
      ..shader = RadialGradient(
        colors: faceColors,
        stops: const [0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, facePaint);

    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = AppColors.gold.withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      center, radius - 5,
      Paint()
        ..color = AppColors.gold.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final baseColor = isDark ? Colors.white : AppColors.emeraldDark;

    for (int i = 0; i < 36; i++) {
      final derajat = i * 10;
      final angle = derajat * pi / 180;
      final isCardinal = derajat % 90 == 0;
      final isMajor = derajat % 30 == 0;

      final panjang = isCardinal ? 16.0 : (isMajor ? 11.0 : 6.0);
      final tebal = isCardinal ? 2.4 : (isMajor ? 1.6 : 1.0);
      final opasitas = isCardinal ? 0.9 : (isMajor ? 0.55 : 0.3);

      final outer = Offset(center.dx + radius * sin(angle), center.dy - radius * cos(angle));
      final innerR = radius - panjang;
      final inner = Offset(center.dx + innerR * sin(angle), center.dy - innerR * cos(angle));

      canvas.drawLine(
        inner, outer,
        Paint()
          ..color = baseColor.withOpacity(opasitas)
          ..strokeWidth = tebal
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawLabels(Canvas canvas, Offset center, double radius) {
    _drawLabel(canvas, 'U', center, radius - 32, 0);
    _drawLabel(canvas, 'T', center, radius - 32, 90);
    _drawLabel(canvas, 'S', center, radius - 32, 180);
    _drawLabel(canvas, 'B', center, radius - 32, 270);
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius) {
    final needleColor = isDark ? AppColors.tertiaryDark : AppColors.tertiaryLight;
    final ekorColor = isDark ? Colors.white38 : Colors.black26;

    final needleAngle = bearingDerajat * pi / 180;
    final panjangDepan = radius - 22;
    const panjangBelakang = 20.0;
    const lebarSayap = 6.5;

    final tip = Offset(
      center.dx + panjangDepan * sin(needleAngle),
      center.dy - panjangDepan * cos(needleAngle),
    );
    final tailAngle = needleAngle + pi;
    final tail = Offset(
      center.dx + panjangBelakang * sin(tailAngle),
      center.dy - panjangBelakang * cos(tailAngle),
    );
    final perp = needleAngle + pi / 2;
    final sayapKanan = Offset(center.dx + lebarSayap * sin(perp), center.dy - lebarSayap * cos(perp));
    final sayapKiri = Offset(center.dx - lebarSayap * sin(perp), center.dy + lebarSayap * cos(perp));

    final depanPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(sayapKanan.dx, sayapKanan.dy)
      ..lineTo(sayapKiri.dx, sayapKiri.dy)
      ..close();
    canvas.drawShadow(depanPath, Colors.black, 3, false);
    canvas.drawPath(depanPath, Paint()..color = needleColor);

    final belakangPath = Path()
      ..moveTo(tail.dx, tail.dy)
      ..lineTo(sayapKanan.dx, sayapKanan.dy)
      ..lineTo(sayapKiri.dx, sayapKiri.dy)
      ..close();
    canvas.drawPath(belakangPath, Paint()..color = ekorColor);

    canvas.drawLine(tip, tail, Paint()..color = Colors.black.withOpacity(0.15)..strokeWidth = 0.8);

    canvas.drawCircle(tip, 3.5, Paint()..color = AppColors.gold);
    canvas.drawCircle(
      tip, 3.5,
      Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawCenterPin(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 5.5, Paint()..color = isDark ? const Color(0xFF3A3A36) : const Color(0xFFDDD8C8));
    canvas.drawCircle(
      center, 5.5,
      Paint()
        ..color = AppColors.gold.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      center.translate(-1.4, -1.4), 1.6,
      Paint()..color = Colors.white.withOpacity(isDark ? 0.5 : 0.9),
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset center, double dist, double angleDeg) {
    final angle = angleDeg * pi / 180;
    final pos = Offset(
      center.dx + dist * sin(angle),
      center.dy - dist * cos(angle),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.emeraldDark,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.bearingDerajat != bearingDerajat || oldDelegate.isDark != isDark;
}
