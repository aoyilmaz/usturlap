import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/geo_math.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';
import 'package:usturlap/features/hud/resection_panel.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/resection_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// E5: geriden kestirme paneli (coğrafi kuzey, derece — varsayılan ayar).
void main() {
  late AppDatabase db;
  const me = LatLng(37.06, 37.38);
  final hill = GeoMath.destination(me, 2500, 0); // kuzeyde
  final tower = GeoMath.destination(me, 2000, 90); // doğuda

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }

  /// Panel [visible] false olunca kaldırılır; sağlayıcı kapsamı açık kalır.
  late ValueNotifier<bool> visible;

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      final repo = WaypointRepository(db);
      await repo.add(name: 'TEPE', position: hill);
      await repo.add(name: 'KULE', position: tower);
    });
    visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, on, _) =>
                  on ? ResectionPanel(onCenter: (_) {}) : const SizedBox(),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await settle(tester);
    }
    return ProviderScope.containerOf(
      tester.element(find.byType(ResectionPanel)),
    );
  }

  Future<void> pick(WidgetTester tester, int row, String name) async {
    final dd = find.byType(DropdownButtonFormField<int>).at(row);
    await tester.ensureVisible(dd);
    await tester.tap(dd);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> bearing(WidgetTester tester, int row, String text) async {
    await tester.enterText(find.byType(TextField).at(row), text);
    await tester.pump();
  }

  testWidgets('iki kerterizle konum + önizleme; konumum yap', (tester) async {
    final c = await pump(tester);
    expect(find.text('En az iki nokta ve kerteriz gir.'), findsOneWidget);
    await pick(tester, 0, 'TEPE');
    await bearing(tester, 0, '0');
    await pick(tester, 1, 'KULE');
    await bearing(tester, 1, '90');
    await tester.pump(); // önizleme çizimden sonra
    expect(find.textContaining('Hata alanı: ±'), findsOneWidget);
    final preview = c.read(resectionPreviewProvider)!;
    expect(preview.sightings, hasLength(2));
    expect(GeoMath.distance(preview.result.position!, me), lessThan(15));

    await tester.ensureVisible(find.text('Konumum yap'));
    await tester.tap(find.text('Konumum yap'));
    await tester.pump();
    final manual = c.read(manualPositionProvider)!;
    expect(GeoMath.distance(manual, me), lessThan(15));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('geçersiz kerteriz ve tutarsız okuma uyarılır', (tester) async {
    await pump(tester);
    await pick(tester, 0, 'TEPE');
    await bearing(tester, 0, '400');
    expect(find.text('0–360'), findsOneWidget);
    await bearing(tester, 0, '0');
    await pick(tester, 1, 'KULE');
    await bearing(tester, 1, '270'); // ters okunmuş
    expect(find.textContaining('Kerterizler tutarsız'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('panel kapanınca önizleme temizlenir', (tester) async {
    final c = await pump(tester);
    await pick(tester, 0, 'TEPE');
    await bearing(tester, 0, '0');
    await tester.pump();
    expect(c.read(resectionPreviewProvider), isNotNull);
    visible.value = false;
    await tester.pump();
    expect(c.read(resectionPreviewProvider), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
