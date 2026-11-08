import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/geo_math.dart';
import 'package:kerteriz/domain/models/route_plan.dart';
import 'package:kerteriz/features/routes/route_profile_panel.dart';
import 'package:latlong2/latlong.dart';

/// E8: rota yükseklik profili paneli.
void main() {
  const a = LatLng(37.0, 37.0);
  final route = RoutePlan(
    uid: 'r',
    name: 'TEPE YOLU',
    points: [a, GeoMath.destination(a, 2000, 0)],
    createdAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, ElevationAt elevation) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [routeElevationAtProvider.overrideWithValue(elevation)],
        child: MaterialApp(
          home: Scaffold(body: RouteProfilePanel(route: route)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('çıkış / iniş ve uç yükseklikler; grafik çizilir', (
    tester,
  ) async {
    // Başlangıçtan kuzeye: 700 m → 1000 m, sonra 900 m'ye in.
    await pump(tester, (p) async {
      final d = GeoMath.distance(a, p);
      return d <= 1500 ? 700 + d * 0.2 : 1000 - (d - 1500) * 0.2;
    });
    expect(find.text('TEPE YOLU: yükseklik profili'), findsOneWidget);
    expect(
      find.text('↗ 300 m · ↘ 100 m · en yüksek 1000 m · en alçak 700 m'),
      findsOneWidget,
    );
    expect(find.text('Uzunluk 2.00 km'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arazi verisi yoksa söyler', (tester) async {
    await pump(tester, (_) async => null);
    expect(find.textContaining('arazi verisi yok'), findsOneWidget);
  });
}
