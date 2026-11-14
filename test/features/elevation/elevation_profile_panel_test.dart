import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/geo_math.dart';
import 'package:usturlap/features/elevation/elevation_profile_panel.dart';
import 'package:latlong2/latlong.dart';

/// E8 / F2: yükseklik profili paneli (rota ya da çizgi).
void main() {
  const a = LatLng(37.0, 37.0);
  final b = GeoMath.destination(a, 2000, 0);

  Future<void> pump(WidgetTester tester, ElevationAt elevation) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [elevationAtProvider.overrideWithValue(elevation)],
        child: MaterialApp(
          home: Scaffold(
            body: ElevationProfilePanel(
              title: 'TEPE YOLU: yükseklik profili',
              points: [a, b],
              pointNames: const ['BAŞLANGIÇ', 'KN1'],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('çıkış / iniş, uç yükseklikler, en dik eğimler', (tester) async {
    // 1500 m boyunca %20 çık (700 → 1000), sonra %20 in.
    await pump(tester, (p) async {
      final d = GeoMath.distance(a, p);
      return d <= 1500 ? 700 + d * 0.2 : 1000 - (d - 1500) * 0.2;
    });
    expect(find.text('TEPE YOLU: yükseklik profili'), findsOneWidget);
    expect(
      find.text('↗ 300 m · ↘ 100 m · en yüksek 1000 m · en alçak 700 m'),
      findsOneWidget,
    );
    expect(
      find.text('En dik çıkış %20 · en dik iniş −%20 · uzunluk 2.00 km'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('arazi verisi yoksa söyler', (tester) async {
    await pump(tester, (_) async => null);
    expect(find.textContaining('arazi verisi yok'), findsOneWidget);
  });

  test('eğim rengi ve yazımı', () {
    expect(gradeColor(5), Colors.lightGreenAccent);
    expect(gradeColor(-15), Colors.amber);
    expect(gradeColor(25), Colors.redAccent);
    expect(fmtGrade(18.4), '%18');
    expect(fmtGrade(-12.6), '−%13');
  });
}
