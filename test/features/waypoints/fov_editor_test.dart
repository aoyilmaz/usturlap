import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/domain/models/contact.dart';
import 'package:kerteriz/domain/models/sensor_fov.dart';
import 'package:kerteriz/domain/models/waypoint.dart';
import 'package:kerteriz/features/waypoints/fov_editor.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// E9: görüş konisi penceresi (coğrafi kuzey, derece).
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('menzil metni', () {
    expect(parseFovRange('800'), 800);
    expect(parseFovRange('1,5km'), 1500);
    expect(parseFovRange('0'), isNull);
    expect(parseFovRange('150km'), isNull);
    expect(parseFovRange('100 200'), isNull);
    expect(parseFovRange('x'), isNull);
  });

  Future<Future<({SensorFov? fov})?>> pump(
    WidgetTester tester,
    Waypoint wp,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late BuildContext ctx;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          selfContactProvider.overrideWithValue(
            Contact(
              callsign: 'KURT-1',
              position: const LatLng(37, 37),
              headingDeg: 135,
              timestamp: DateTime.utc(2026, 11, 8),
              isSelf: true,
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    final f = showFovDialog(ctx, wp);
    await tester.pumpAndSettle();
    return f;
  }

  Waypoint wp({SensorFov? fov}) => Waypoint(
    id: 1,
    uid: 'sn1',
    name: 'SN-1',
    position: const LatLng(37, 37),
    createdAt: DateTime(2026),
    affiliation: Affiliation.sensor,
    fov: fov,
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('pusuladan yön, açıklık, menzil → kaydet', (tester) async {
    final result = await pump(tester, wp());
    await tester.tap(find.byTooltip('Yönü pusuladan al'));
    await tester.pump();
    expect(find.text('135'), findsOneWidget);
    await tester.tap(find.text('90°'));
    await tester.enterText(find.widgetWithText(TextField, '1000'), 'x');
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(find.textContaining('1 m – 100 km'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'x'), '2,5km');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(
      (await result)!.fov,
      const SensorFov(azimuth: 135, width: 90, range: 2500),
    );
    await dispose(tester);
  });

  testWidgets('var olan koni düzenlenir ya da kaldırılır', (tester) async {
    final result = await pump(
      tester,
      wp(fov: const SensorFov(azimuth: 45, width: 60, range: 800)),
    );
    expect(find.text('45'), findsOneWidget);
    expect(find.text('800'), findsOneWidget);
    await tester.tap(find.text('Kaldır'));
    await tester.pumpAndSettle();
    final r = await result;
    expect(r, isNotNull);
    expect(r!.fov, isNull);
    await dispose(tester);
  });
}
