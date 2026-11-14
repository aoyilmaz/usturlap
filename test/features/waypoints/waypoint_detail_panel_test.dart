import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/attachment_repository.dart';
import 'package:usturlap/domain/models/waypoint.dart';
import 'package:usturlap/features/waypoints/edit_waypoint_dialog.dart';
import 'package:usturlap/providers/bullseye_providers.dart';
import 'package:usturlap/features/waypoints/waypoint_detail_panel.dart';
import 'package:usturlap/providers/elevation_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// D3e: nokta detayı — yükseklik ve fotoğraflar.
void main() {
  late Directory root;
  late AppDatabase db;
  late Waypoint wp;
  late WidgetRef widgetRef;

  /// Sahte seçici ne döndürsün: dosya yolu, null (vazgeçti) ya da hata.
  late Future<String?> Function() picker;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('detail_test_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  /// Gerçek dosya / drift işleri gerçek zamanda biter.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  /// Sahte zaman ↔ gerçek zaman (seçici → dosya kopyası → drift →
  /// akış) zinciri bitene kadar dön.
  Future<void> pumpUntil(WidgetTester tester, Finder f) async {
    for (var i = 0; i < 20 && f.evaluate().isEmpty; i++) {
      await settle(tester);
    }
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    double? elevation,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repoWp = await tester.runAsync(() async {
      final id = await db
          .into(db.waypoints)
          .insert(
            WaypointsCompanion.insert(
              name: 'OP-1',
              lat: 37.06,
              lon: 37.38,
              createdAt: DateTime(2026),
            ),
          );
      await db.customStatement(
        "UPDATE waypoints SET uid = 'uid-op1', elevation = ? WHERE id = ?",
        [elevation, id],
      );
      return id;
    });
    wp = Waypoint(
      id: repoWp,
      uid: 'uid-op1',
      name: 'OP-1',
      position: const LatLng(37.06, 37.38),
      createdAt: DateTime(2026),
      elevation: elevation,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          attachmentRepositoryProvider.overrideWithValue(
            AttachmentRepository(db, documentsDir: () async => root),
          ),
          terrainElevationProvider.overrideWith((ref, p) async => 884),
          pickPhotoProvider.overrideWithValue((source) => picker()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                widgetRef = ref;
                return WaypointDetailPanel(
                  initial: wp,
                  onCenter: (_) {},
                  onGo: (_) {},
                  onEdit: (_) {},
                  onShare: (_) {},
                  onDelete: (_) {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return ProviderScope.containerOf(
      tester.element(find.byType(WaypointDetailPanel)),
    );
  }

  testWidgets('yükseklik girilmemişse arazi verisinden okunur', (tester) async {
    await pump(tester);
    expect(find.text('Yükseklik: ≈ 884 m MSL (arazi verisi)'), findsOneWidget);
    expect(find.text('Henüz fotoğraf yok.'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('Bullseye yap: nokta bullseye olur, kendi çağrısı gizlenir', (
    tester,
  ) async {
    final c = await pump(tester);
    expect(find.textContaining('BE '), findsNothing);
    await tester.ensureVisible(find.text('Bullseye yap'));
    await tester.tap(find.text('Bullseye yap'));
    await tester.pump();
    final b = c.read(bullseyeProvider)!;
    expect(b.name, 'OP-1');
    expect(b.center.waypointUid, 'uid-op1');
    expect(find.text('OP-1 bullseye yapıldı.'), findsOneWidget);
    // Bullseye'ın kendisi için "BE 000° / 0 m" yazılmaz.
    expect(find.textContaining('BE '), findsNothing);
    await dispose(tester);
  });

  testWidgets('elle girilen yükseklik "(elle)" gösterilir', (tester) async {
    await pump(tester, elevation: 1203.4);
    expect(find.text('Yükseklik: 1203 m MSL (elle)'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('arşivden fotoğraf eklenir; vazgeçince bir şey olmaz', (
    tester,
  ) async {
    final src = File('${root.path}/secilen.jpg');
    await tester.runAsync(() => src.writeAsBytes([1, 2, 3]));
    picker = () async => src.path;
    final c = await pump(tester);

    await tester.tap(find.byTooltip('Arşivden ekle'));
    await pumpUntil(tester, find.text('Fotoğraflar (1)'));
    expect(find.text('Fotoğraflar (1)'), findsOneWidget);
    final saved = await tester.runAsync(
      () => c.read(attachmentRepositoryProvider).watchFor('uid-op1').first,
    );
    expect(saved, hasLength(1));
    expect(saved!.single.path, startsWith('attachments/uid-op1/'));

    picker = () async => null;
    await tester.tap(find.byTooltip('Fotoğraf çek'));
    await settle(tester);
    expect(find.text('Fotoğraflar (1)'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('kamera hatası (ör. izin yok) uyarı olarak gösterilir', (
    tester,
  ) async {
    picker = () async => throw Exception('kamera izni yok');
    await pump(tester);
    await tester.tap(find.byTooltip('Fotoğraf çek'));
    await pumpUntil(tester, find.textContaining('Fotoğraf eklenemedi'));
    expect(find.textContaining('Fotoğraf eklenemedi'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('düzenle: yükseklik kaydedilir, geçersiz giriş uyarır', (
    tester,
  ) async {
    await pump(tester);
    final ctx = tester.element(find.byType(WaypointDetailPanel));
    showEditWaypointDialog(ctx, widgetRef, wp);
    await tester.pumpAndSettle();
    final field = find.widgetWithText(TextField, 'Yükseklik (m, MSL)');

    await tester.enterText(field, 'abc');
    await tester.tap(find.text('Kaydet'));
    await tester.pump();
    expect(find.text('-500 ile 9000 arasında bir sayı girin'), findsOneWidget);

    await tester.enterText(field, '1250');
    await tester.tap(find.text('Kaydet'));
    await pumpUntil(tester, find.text('Yükseklik: 1250 m MSL (elle)'));
    expect(find.text('Yükseklik: 1250 m MSL (elle)'), findsOneWidget);
    await dispose(tester);
  });
}
