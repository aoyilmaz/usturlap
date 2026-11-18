import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/attachment_repository.dart';
import 'package:usturlap/data/db/map_graphic_repository.dart';
import 'package:usturlap/data/db/track_repository.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';
import 'package:usturlap/data/position/stub_position_source.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/features/tools/graphic_list_sheet.dart';
import 'package:usturlap/features/tracks/track_list_sheet.dart';
import 'package:usturlap/features/waypoints/add_waypoint_dialog.dart';
import 'package:usturlap/features/waypoints/waypoint_list_sheet.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/track_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';

/// Denetim 2026-11-16: listelerde tek dokunuşla onaysız silme vardı;
/// kaydedilen iz de silinebiliyordu. "Kaydet"e çift dokunuş çift kayıt açıyordu.
void main() {
  late AppDatabase db;
  late Directory root;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('lists_');
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      // Süreli pump: alttan sayfa / pencere animasyonları da ilerlesin.
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// drift akışlarının zamanlayıcıları test bitmeden kapansın.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  /// [open] düğmesine basınca ilgili listeyi / pencereyi açan sayfa.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    void Function(BuildContext, WidgetRef) open,
  ) async {
    tester.view.physicalSize = const Size(1800, 3600); // test yazı tipi geniş
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late ProviderContainer c;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          positionSourceProvider.overrideWithValue(StubPositionSource()),
          attachmentRepositoryProvider.overrideWithValue(
            AttachmentRepository(db, documentsDir: () async => root),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                c = ProviderScope.containerOf(context);
                return TextButton(
                  onPressed: () => open(context, ref),
                  child: const Text('AÇ'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('AÇ'));
    await settle(tester);
    return c;
  }

  testWidgets('nokta listesi: silme onay ister', (tester) async {
    await tester.runAsync(
      () => WaypointRepository(
        db,
      ).add(name: 'OP-1', position: const LatLng(39, 32)),
    );
    await pump(
      tester,
      (context, ref) =>
          showWaypointListSheet(context, ref, onTapWaypoint: (_) {}),
    );
    expect(find.text('OP-1'), findsOneWidget);

    await tester.tap(find.byTooltip('Sil'));
    await settle(tester);
    expect(find.text('OP-1 silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await settle(tester);
    expect(
      await tester.runAsync(() => db.select(db.waypoints).get()),
      hasLength(1),
    );

    await tester.tap(find.byTooltip('Sil'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await settle(tester);
    expect(await tester.runAsync(() => db.select(db.waypoints).get()), isEmpty);
    await dispose(tester);
  });

  testWidgets('çizim listesi: silme onay ister', (tester) async {
    await tester.runAsync(
      () => MapGraphicRepository(db).add(
        name: 'HAT-1',
        type: GraphicType.line,
        points: const [LatLng(39, 32), LatLng(39.01, 32)],
        colorValue: 0xFFFF0000,
      ),
    );
    await pump(tester, showGraphicListSheet);
    await tester.tap(find.byTooltip('Sil'));
    await settle(tester);
    expect(find.text('HAT-1 silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await settle(tester);
    expect(
      await tester.runAsync(() => db.select(db.mapGraphics).get()),
      hasLength(1),
    );
    await dispose(tester);
  });

  testWidgets('iz listesi: kaydedilen iz silinemez, bitmiş iz onayla silinir', (
    tester,
  ) async {
    final repo = TrackRepository(db);
    await tester.runAsync(() async {
      final old = await repo.startTrack('ESKİ İZ');
      await repo.endTrack(old);
    });
    final c = await pump(tester, showTrackListSheet);
    await tester.runAsync(() => c.read(recordingProvider.notifier).start());
    await settle(tester);
    final live = c.read(recordingProvider).trackId!;
    expect(find.textContaining('kaydediliyor'), findsOneWidget);

    // Kaydedilen iz: silme düğmesi uyarır, iz durur.
    final liveTile = find.ancestor(
      of: find.textContaining('kaydediliyor'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: liveTile, matching: find.byTooltip('Sil')),
    );
    await settle(tester);
    expect(find.textContaining('önce kaydı durdur'), findsOneWidget);
    expect(find.textContaining('silinsin mi?'), findsNothing);
    final tracks = await tester.runAsync(() => db.select(db.tracks).get());
    expect(tracks!.map((t) => t.id), contains(live));

    // Bitmiş iz: onayla silinir.
    final oldTile = find.ancestor(
      of: find.text('ESKİ İZ'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: oldTile, matching: find.byTooltip('Sil')),
    );
    await settle(tester);
    expect(find.text('ESKİ İZ silinsin mi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await settle(tester);
    final left = await tester.runAsync(() => db.select(db.tracks).get());
    expect(left!.map((t) => t.id), [live]);
    await dispose(tester);
  });

  testWidgets('İşaret ekle: "Kaydet"e çift dokunuş tek nokta ekler', (
    tester,
  ) async {
    await pump(
      tester,
      (context, ref) =>
          showAddWaypointDialog(context, ref, const LatLng(39, 32)),
    );
    final save = find.widgetWithText(FilledButton, 'Kaydet');
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await settle(tester);
    expect(
      await tester.runAsync(() => db.select(db.waypoints).get()),
      hasLength(1),
    );
    await dispose(tester);
  });
}
