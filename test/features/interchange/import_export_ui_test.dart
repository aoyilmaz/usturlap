import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/attachment_repository.dart';
import 'package:usturlap/data/db/map_graphic_repository.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';
import 'package:usturlap/data/export/geo_exporter.dart';
import 'package:usturlap/data/import/geo_import.dart';
import 'package:usturlap/data/package/data_package.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/domain/models/waypoint.dart';
import 'package:usturlap/features/export/export_sheet.dart';
import 'package:usturlap/features/import/import_action.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// G7: içe aktarma önizlemesi ve dışa aktar paneli.
void main() {
  late AppDatabase db;
  late Directory root;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('interchange_ui_');
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
  }

  Future<(WidgetRef, BuildContext)> pump(
    WidgetTester tester, [
    Widget? body,
  ]) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late WidgetRef wref;
    late BuildContext ctx;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          attachmentRepositoryProvider.overrideWithValue(
            AttachmentRepository(db, documentsDir: () async => root),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (c, r, _) {
                wref = r;
                ctx = c;
                return body ?? const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return (wref, ctx);
  }

  final t0 = DateTime.utc(2026, 11, 11);
  final kml = GeoExporter.toKml(
    ExportSet(
      waypoints: [
        Waypoint(
          uid: 'wp-1',
          name: 'OP-1',
          position: const LatLng(39, 32),
          createdAt: t0,
        ),
      ],
      graphics: [
        MapGraphic(
          uid: 'g-1',
          name: 'HAT-1',
          type: GraphicType.line,
          points: const [LatLng(39, 32), LatLng(39.1, 32)],
          colorValue: 0xFFE03131,
          createdAt: t0,
        ),
      ],
    ),
    name: 'Test',
  );

  testWidgets('önizleme: Vazgeç eklemez; İçe aktar ekler ve bildirir', (
    tester,
  ) async {
    final (r, ctx) = await pump(tester);
    final bundle = GeoImport.parse(Uint8List.fromList(utf8.encode(kml)));

    var done = importBundle(ctx, r, bundle, fileName: 'gorev.kml');
    await tester.pumpAndSettle();
    expect(find.text('İçe aktar'), findsOneWidget);
    expect(find.text('gorev.kml (KML)'), findsOneWidget);
    expect(find.text('Noktalar'), findsOneWidget);
    expect(find.text('Çizimler'), findsOneWidget);
    expect(find.text('İzler'), findsNothing); // sıfırsa satır yok
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(await done, isNull);

    done = importBundle(ctx, r, bundle, fileName: 'gorev.kml');
    await tester.pumpAndSettle();
    await tester.tap(find.text('İçe aktar (2)'));
    await settle(tester);
    final report = (await done)!;
    expect(report.summary, '1 nokta, 1 çizim');
    await tester.pump();
    expect(find.text('İçe aktarıldı: 1 nokta, 1 çizim.'), findsOneWidget);
    final wps = (await tester.runAsync(
      () => WaypointRepository(db).watchAll().first,
    ))!;
    expect(wps.single.uid, 'wp-1');
    final gs = (await tester.runAsync(
      () => MapGraphicRepository(db).watchAll().first,
    ))!;
    expect(gs.single.type, GraphicType.line);

    // Aynı dosya ikinci kez: kopya yok.
    done = importBundle(ctx, r, bundle, fileName: 'gorev.kml');
    await tester.pumpAndSettle();
    await tester.tap(find.text('İçe aktar (2)'));
    await settle(tester);
    await tester.pumpAndSettle();
    // Yeni sonuç önceki şeridin yerine geçer (sırada beklemez).
    expect(find.text('İçe aktarıldı: 1 nokta, 1 çizim.'), findsNothing);
    expect(find.text('Yeni nesne yok (2 tanesi zaten vardı).'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('veri paketi önizlemesi: ad, alınmayacaklar, güvenlik notu', (
    tester,
  ) async {
    final (r, ctx) = await pump(tester);
    final zip = DataPackage.build(
      ExportSet(
        waypoints: [
          Waypoint(
            uid: 'p-1',
            name: 'P-1',
            position: const LatLng(39, 32),
            createdAt: t0,
          ),
        ],
      ),
      name: 'Görev',
      creatorUid: 'USTURLAP-x',
      creatorCallsign: 'KURT',
    );
    final bundle = GeoImport.parse(zip);
    final withSkipped = ImportBundle(
      bundle.result,
      format: bundle.format,
      packageName: bundle.packageName,
      skipped: const [SkippedEntry('ayar.pref', 'ayar dosyası')],
    );
    final done = importBundle(ctx, r, withSkipped, fileName: 'gorev.zip');
    await tester.pumpAndSettle();
    expect(find.text('Veri paketi: Görev'), findsOneWidget);
    expect(find.text('Alınmayacak (1)'), findsOneWidget);
    expect(find.text('• ayar.pref: ayar dosyası'), findsOneWidget);
    expect(
      find.textContaining('ayarlar, uygulamalar ve komutlar'),
      findsOneWidget,
    );
    await tester.tap(find.text('İçe aktar (1)'));
    await settle(tester);
    expect((await done)!.waypoints, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('dışa aktar paneli: sayılar, GPX çizimleri dışarıda bırakır', (
    tester,
  ) async {
    await pump(
      tester,
      ExportPanel(
        title: 'Seçimi dışa aktar',
        preset: ExportSet(
          waypoints: [
            Waypoint(
              uid: 'a',
              name: 'A',
              position: const LatLng(39, 32),
              createdAt: t0,
            ),
            Waypoint(
              uid: 'b',
              name: 'B',
              position: const LatLng(39, 32),
              createdAt: t0,
            ),
          ],
          graphics: [
            MapGraphic(
              uid: 'g',
              name: 'G',
              type: GraphicType.area,
              points: const [LatLng(39, 32), LatLng(39, 33), LatLng(40, 33)],
              colorValue: 0xFFE03131,
              createdAt: t0,
            ),
          ],
        ),
      ),
    );
    expect(find.text('Seçimi dışa aktar'), findsOneWidget);
    expect(find.text('Noktalar (2)'), findsOneWidget);
    expect(find.text('Çizimler (1)'), findsOneWidget);
    expect(find.text('Paylaş (3 nesne, KMZ)'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Veri paketi'), findsOneWidget);
    expect(find.text('Rotalar (0)'), findsOneWidget);
    await tester.tap(find.text('Noktalar (2)'));
    await tester.pump();
    expect(find.text('Paylaş (1 nesne, KMZ)'), findsOneWidget);
    await tester.tap(find.text('Noktalar (2)'));
    await tester.tap(find.text('GPX'));
    await tester.pump();
    expect(find.text('GPX\'e girmez'), findsWidgets);
    expect(find.text('Paylaş (2 nesne, GPX)'), findsOneWidget);
    // Boş türler seçilemez.
    final tracks = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'İzler (0)'),
    );
    expect(tracks.onChanged, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
