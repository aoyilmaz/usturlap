import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/attachment_repository.dart';
import 'package:kerteriz/data/db/waypoint_repository.dart';
import 'package:kerteriz/domain/models/contact.dart';
import 'package:kerteriz/features/gallery/gallery_panel.dart';
import 'package:kerteriz/features/waypoints/waypoint_detail_panel.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// G5: hızlı fotoğraf ve galeri.
void main() {
  late AppDatabase db;
  late Directory root;
  late File photo;
  const me = LatLng(37.06, 37.38);
  const center = LatLng(39.9, 32.8);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('gallery_');
    photo = File('${root.path}/kamera.jpg')..writeAsBytesSync([1, 2, 3]);
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

  /// [picked]: kameranın döndürdüğü yol (null = vazgeçti).
  Future<(WidgetRef, BuildContext)> pump(
    WidgetTester tester, {
    LatLng? self,
    String? Function()? picked,
    List<LatLng>? centered,
  }) async {
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
          pickPhotoProvider.overrideWithValue(
            (_) async => (picked ?? () => photo.path)(),
          ),
          selfContactProvider.overrideWithValue(
            self == null
                ? null
                : Contact(
                    callsign: 'KURT-1',
                    position: self,
                    timestamp: DateTime.utc(2026, 11, 10),
                    isSelf: true,
                  ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (c, r, _) {
                wref = r;
                ctx = c;
                return GalleryPanel(onCenter: (p) => centered?.add(p));
              },
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return (wref, ctx);
  }

  testWidgets('hızlı fotoğraf: konumumda FOTO-1 + fotoğraf; galeride', (
    tester,
  ) async {
    final centered = <LatLng>[];
    final (r, ctx) = await pump(tester, self: me, centered: centered);
    expect(find.textContaining('Henüz fotoğraf yok'), findsOneWidget);
    // Drift akışı dinlenirken yazma runAsync içinde başlatılmaz (kilitlenir).
    unawaited(quickPic(ctx, r, fallback: () => center));
    await settle(tester);
    final wps = (await tester.runAsync(
      () => WaypointRepository(db).watchAll().first,
    ))!;
    final w = wps.single;
    expect(w.name, 'FOTO-1');
    expect(w.position, me);
    expect(w.note, startsWith('Hızlı fotoğraf'));
    expect(find.text('Galeri (1)'), findsOneWidget);
    expect(find.text('FOTO-1'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Fotoğraf: FOTO-1'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsOneWidget);
    await tester.tap(find.byTooltip('Haritada göster'));
    await tester.pumpAndSettle();
    expect(centered, [me]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('konum yoksa harita ortası; vazgeçince bir şey olmaz', (
    tester,
  ) async {
    String? next = photo.path;
    final (r, ctx) = await pump(tester, picked: () => next);
    next = null;
    unawaited(quickPic(ctx, r, fallback: () => center));
    await settle(tester);
    expect(
      await tester.runAsync(() => WaypointRepository(db).watchAll().first),
      isEmpty,
    );
    next = photo.path;
    unawaited(quickPic(ctx, r, fallback: () => center));
    await settle(tester);
    final w = (await tester.runAsync(
      () => WaypointRepository(db).watchAll().first,
    ))!.single;
    expect(w.position, center);
    expect(w.note, contains('harita ortası'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
