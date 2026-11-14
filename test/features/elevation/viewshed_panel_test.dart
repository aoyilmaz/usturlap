import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/elevation/elevation_store.dart';
import 'package:usturlap/data/elevation/hgt_parser.dart';
import 'package:usturlap/features/elevation/viewshed_panel.dart';
import 'package:usturlap/providers/elevation_providers.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/viewshed_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

import '../../data/elevation/dem_test_data.dart';

/// F3: Görüş alanı paneli.
void main() {
  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vs_panel_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await ElevationStore(
      directory: () async => dir,
    ).importBytes(makeHgt(1201, (r, c) => 300), 'N37E037.hgt');
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  testWidgets('noktadan hesapla → özet; haritadan kaldır', (tester) async {
    tester.view.physicalSize = const Size(1170, 5000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final panel = ViewshedPanel(
      mapCenter: () => const LatLng(37.5, 37.5),
      onCenter: (_) {},
      observer: const LatLng(37.5, 37.5),
      observerName: 'OP-1',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          selfContactProvider.overrideWithValue(null),
          hgtParserProvider.overrideWithValue(
            HgtParser(directory: () async => dir, bundled: (_) async => null),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: panel)),
      ),
    );
    final c = ProviderScope.containerOf(tester.element(find.byWidget(panel)));
    expect(find.text('OP-1'), findsOneWidget);
    await tester.tap(find.text('1.00 km'));
    await tester.tap(find.text('Hesapla'));
    await tester.pump();
    expect(find.text('Hesaplanıyor…'), findsOneWidget);
    for (var i = 0; i < 100 && c.read(viewshedProvider)!.busy; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pump();
    expect(find.textContaining('Görünen: %100'), findsOneWidget);
    expect(find.textContaining('OP-1, 1.00 km'), findsOneWidget);

    await tester.tap(find.text('Haritadan kaldır'));
    await tester.pump();
    expect(c.read(viewshedProvider), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
