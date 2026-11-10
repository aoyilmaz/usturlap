import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/elevation/elevation_store.dart';
import 'package:kerteriz/domain/models/contact.dart';
import 'package:kerteriz/features/elevation/elevation_data_panel.dart';
import 'package:kerteriz/providers/elevation_providers.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

import '../../data/elevation/dem_test_data.dart';

/// F1: Yükseklik verisi paneli.
void main() {
  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dem_panel_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<ProviderContainer> pump(WidgetTester tester, LatLng me) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = ElevationStore(directory: () async => dir);
    await tester.runAsync(
      () => store.importBytes(makeHgt(1201, (r, c) => 1), 'N39E032.hgt'),
    );
    final panel = ElevationDataPanel(onCenter: (_) {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          elevationStoreProvider.overrideWithValue(store),
          selfContactProvider.overrideWithValue(
            Contact(
              callsign: 'KURT-1',
              position: me,
              timestamp: DateTime.utc(2026, 11, 9),
              isSelf: true,
            ),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: panel)),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    return ProviderScope.containerOf(tester.element(find.byWidget(panel)));
  }

  testWidgets('kareler listelenir; bulunduğun kare var', (tester) async {
    final c = await pump(tester, const LatLng(39.9, 32.8));
    expect(find.text('N37E037'), findsOneWidget); // uygulamayla gelen
    expect(find.text('N39E032'), findsOneWidget);
    expect(find.textContaining('uygulamayla gelen örnek'), findsOneWidget);
    expect(find.text('Bulunduğun kare (N39E032) cihazda.'), findsOneWidget);
    // Örnek silinemez; içe aktarılan silinebilir.
    expect(find.byTooltip('Sil: N37E037'), findsNothing);
    expect(find.byTooltip('Sil: N39E032'), findsOneWidget);

    await tester.tap(find.text('Haritada kapsama'));
    await tester.pump();
    expect(c.read(showElevationCoverageProvider), isTrue);
  });

  testWidgets('bulunduğun kare yoksa hangi dosya gerektiği yazar', (
    tester,
  ) async {
    await pump(tester, const LatLng(41.01, 28.97));
    expect(
      find.textContaining('Bulunduğun kare (N41E028) yok'),
      findsOneWidget,
    );
  });
}
