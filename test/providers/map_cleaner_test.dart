import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/attachment_repository.dart';
import 'package:kerteriz/domain/models/bullseye.dart';
import 'package:kerteriz/domain/models/clear_item.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:kerteriz/domain/models/range_line.dart';
import 'package:kerteriz/domain/models/sensor_fov.dart';
import 'package:kerteriz/providers/bloodhound_providers.dart';
import 'package:kerteriz/providers/bullseye_providers.dart';
import 'package:kerteriz/providers/graphic_providers.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/map_cleaner.dart';
import 'package:kerteriz/providers/nav_providers.dart';
import 'package:kerteriz/providers/overlay_providers.dart';
import 'package:kerteriz/providers/range_line_providers.dart';
import 'package:kerteriz/providers/tool_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

/// D4b: haritayı temizle — sil, gizle, geri al.
void main() {
  late AppDatabase db;
  late Directory root;
  late ProviderContainer c;
  const p1 = LatLng(37.0, 37.0), p2 = LatLng(37.01, 37.0);

  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 30));

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('cleaner_');
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        // Rota takibi kendi konumumu dinler; testte GPS yok.
        selfContactProvider.overrideWithValue(null),
        attachmentRepositoryProvider.overrideWithValue(
          AttachmentRepository(db, documentsDir: () async => root),
        ),
      ],
    );
    c.listen(mapClearTargetsProvider, (_, _) {});

    // Kalıcı veri.
    final wps = c.read(waypointRepositoryProvider);
    final id = await wps.add(name: 'SN-1', position: p1, uid: 'sn1');
    await wps.setElevation(id, 912);
    await wps.setFov(id, const SensorFov(azimuth: 45, width: 60, range: 900));
    final src = File('${root.path}/foto.jpg')..writeAsBytesSync([1, 2, 3]);
    await c.read(attachmentRepositoryProvider).addFile('sn1', src);
    await c
        .read(mapGraphicRepositoryProvider)
        .add(
          name: 'HAT',
          type: GraphicType.line,
          points: const [p1, p2],
          colorValue: 0xFFFF0000,
          uid: 'g1',
        );
    // Ölçümler ve geçici.
    await c
        .read(rangeLineRepositoryProvider)
        .add(
          name: 'R&B-1',
          start: const RbEnd(p1),
          end: const RbEnd(p2),
          uid: 'rb1',
        );
    c.read(bullseyeProvider.notifier).set(const Bullseye(center: RbEnd(p1)));
    c
        .read(bloodhoundsProvider.notifier)
        .add(
          const RbEnd(p1, RbEnd.selfRef),
          RbEnd(p2, RbEnd.waypointRef('sn1')),
        );
    final at = DateTime(2026, 11, 8, 15);
    c.read(navTargetProvider.notifier)
      ..set(p2, 'SN-1')
      ..setArriveBy(at);
    c.read(toolProvider.notifier)
      ..setMode(ToolMode.distance)
      ..addPoint(p1)
      ..addPoint(p2);
    await tick();
  });

  tearDown(() async {
    c.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  MapClearTargets targets() => c.read(mapClearTargetsProvider);

  test('sayılar: haritada görünenler', () {
    final t = targets();
    expect(t.count(ClearItem.waypoints), 1);
    expect(t.count(ClearItem.graphics), 1);
    expect(t.count(ClearItem.rangeLines), 1);
    expect(t.count(ClearItem.bullseye), 1);
    expect(t.count(ClearItem.bloodhounds), 1);
    expect(t.count(ClearItem.navTarget), 1);
    expect(t.count(ClearItem.measurement), 1);
    expect(t.count(ClearItem.rangeRings), 0);
  });

  test(
    'varsayılan seçim: geçiciler gider, kalıcı veri kalır; geri al',
    () async {
      final cleaner = c.read(mapCleanerProvider);
      final s = await cleaner.clear({
        for (final i in ClearItem.values)
          if (i.selectedByDefault) i,
      });
      await tick();
      var t = targets();
      expect(t.count(ClearItem.rangeLines), 0);
      expect(t.bullseye, isNull);
      expect(t.bloodhounds, isEmpty);
      expect(t.navTarget, isNull);
      expect(t.tool.points, isEmpty);
      expect(t.count(ClearItem.waypoints), 1);
      expect(t.count(ClearItem.graphics), 1);

      await cleaner.undo(s);
      await tick();
      t = targets();
      expect(t.rangeLines.single.uid, 'rb1');
      expect(t.bullseye, isNotNull);
      expect(t.bloodhounds.single.to.waypointUid, 'sn1');
      expect(t.navTarget!.arriveBy, DateTime(2026, 11, 8, 15));
      expect(t.tool.points, hasLength(2));
    },
  );

  test('kalıcı veri silinir, aynı uid ve ayrıntıyla geri gelir; foto süre '
      'dolunca silinir', () async {
    final cleaner = c.read(mapCleanerProvider);
    final s = await cleaner.clear({ClearItem.waypoints, ClearItem.graphics});
    await tick();
    expect(targets().waypoints, isEmpty);
    expect(targets().graphics, isEmpty);
    // Geri alma süresinde foto duruyor.
    final photos = c.read(attachmentRepositoryProvider);
    expect(await photos.watchFor('sn1').first, hasLength(1));

    await cleaner.undo(s);
    await tick();
    final w = targets().waypoints.single;
    expect(w.uid, 'sn1');
    expect(w.elevation, 912);
    expect(w.fov, const SensorFov(azimuth: 45, width: 60, range: 900));
    expect(targets().graphics.single.uid, 'g1');
    expect(await photos.watchFor('sn1').first, hasLength(1));

    // Yeniden sil, bu sefer geri alma yok → foto da gider.
    final s2 = await cleaner.clear({ClearItem.waypoints});
    await cleaner.finalize(s2);
    expect(await photos.watchFor('sn1').first, isEmpty);
  });

  test('yalnız gizle: veri kalır, gruplar gizlenir; geri al görünürlüğü '
      'geri yükler', () async {
    final cleaner = c.read(mapCleanerProvider);
    final s = await cleaner.clear({
      ClearItem.waypoints,
      ClearItem.rangeLines,
      ClearItem.bullseye,
    }, hideOnly: true);
    await tick();
    expect(targets().waypoints, isEmpty); // görünmüyor
    expect(targets().rangeLines, isEmpty);
    expect(targets().bullseye, isNull); // gizlenemez → temizlendi
    expect(
      (await c.read(waypointRepositoryProvider).watchAll().first),
      hasLength(1),
    );
    expect(c.read(rangeLinesProvider).value, hasLength(1));

    await cleaner.undo(s);
    await tick();
    expect(c.read(overlayVisibilityProvider).isDefault, isTrue);
    expect(targets().waypoints, hasLength(1));
    expect(targets().bullseye, isNotNull);
    // Gizleme silme değil: foto hiç silinmez.
    await cleaner.finalize(s);
    expect(
      await c.read(attachmentRepositoryProvider).watchFor('sn1').first,
      hasLength(1),
    );
  });

  test('Overlay yöneticisinde gizlenmiş nokta temizlenmez', () async {
    c
        .read(overlayVisibilityProvider.notifier)
        .update((v) => v.toggleUid('sn1'));
    await tick();
    expect(targets().count(ClearItem.waypoints), 0);
    await c.read(mapCleanerProvider).clear({ClearItem.waypoints});
    await tick();
    expect(
      await c.read(waypointRepositoryProvider).watchAll().first,
      hasLength(1),
    );
  });
}
