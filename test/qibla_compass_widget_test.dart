import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pencari_kecamatan/widgets/qibla_compass.dart';

void main() {
  testWidgets('QiblaCompass merender tanpa error meski sensor kompas tidak tersedia',
      (WidgetTester tester) async {
    // Di lingkungan test, flutter_compass tidak punya sensor sungguhan
    // sehingga widget otomatis harus jatuh ke mode statis (lihat
    // _sensorError handling di qibla_compass.dart) tanpa melempar exception.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: QiblaCompass(bearingDerajat: 295.15)),
        ),
      ),
    );

    // Beri kesempatan microtask/stream listener pertama berjalan.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(QiblaCompass), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QiblaCompass menerima berbagai nilai bearing tanpa error',
      (WidgetTester tester) async {
    for (final bearing in [0.0, 90.0, 180.0, 270.0, 359.9]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: QiblaCompass(bearingDerajat: bearing)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'bearing=$bearing seharusnya tidak error');
    }
  });
}
