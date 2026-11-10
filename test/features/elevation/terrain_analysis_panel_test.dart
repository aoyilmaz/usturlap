import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/elevation/elevation_store.dart';
import 'package:kerteriz/data/elevation/hgt_parser.dart';
import 'package:kerteriz/features/elevation/terrain_analysis_panel.dart';
import 'package:kerteriz/providers/elevation_providers.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/terrain_analysis_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

import '../../data/elevation/dem_test_data.dart';

/// F4 / F5: Arazi analizi paneli.
void main() {
  late Directory dir;
  late AppDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('terrain_panel_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await ElevationStore(
      directory: () async => dir,
    ).importBytes(makeHgt(1201, (r, c) => r), 'N37E037.hgt');
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  testWidgets('eğriler çizilir, özet; eğim katmanı açıklamasıyla', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 5000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final panel = TerrainAnalysisPanel(
      mapCenter: () => const LatLng(37.5, 37.5),
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
    Future<void> waitIdle() async {
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        if (c.read(terrainAnalysisProvider)?.busy == false) break;
      }
      await tester.pump();
    }

    await tester.tap(find.text('Eğrileri çiz'));
    await tester.pump();
    await waitIdle();
    expect(find.textContaining('Aralık 5 m ·'), findsOneWidget);

    await tester.tap(find.text('Katmanı çiz'));
    await tester.pump();
    await waitIdle();
    expect(find.text('10–20°'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
