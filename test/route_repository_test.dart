import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/route_repository.dart';
import 'package:kerteriz/providers/route_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('rota ekle → sıra/noktalar korunur; yeniden adlandır; sil', () async {
    final repo = RouteRepository(db);
    const pts = [LatLng(39.0, 32.0), LatLng(39.01, 32.0), LatLng(39.02, 32.01)];
    final saved = await repo.add(name: 'KEŞİF-1', points: pts);
    final id = saved.id!;

    var all = await repo.watchAll().first;
    expect(all.single.name, 'KEŞİF-1');
    expect(all.single.points, pts);
    expect(all.single.length, greaterThan(2000));
    // Kaydedilen rota ile okunan aynı kalıcı kimliği taşır.
    expect(all.single.uid, saved.uid);
    expect(saved.uid, matches(RegExp(r'^[0-9a-f-]{36}$')));

    await repo.rename(id, 'KEŞİF-2');
    all = await repo.watchAll().first;
    expect(all.single.name, 'KEŞİF-2');

    await repo.delete(id);
    expect(await repo.watchAll().first, isEmpty);
  });

  test('nokta adları: kaydet, ters çevir, eski (adsız) kayıt okunur', () async {
    final repo = RouteRepository(db);
    const pts = [LatLng(39.0, 32.0), LatLng(39.01, 32.0), LatLng(39.02, 32.01)];
    final saved = await repo.add(
      name: 'DEVRİYE',
      points: pts,
      pointNames: const ['KARAKOL', null, '  '],
    );
    var r = (await repo.watchAll().first).single;
    expect(r.pointNames, ['KARAKOL', null, null]);
    expect(r.nameOf(0), 'KARAKOL');
    expect(r.nameOf(1), 'KN1');
    expect(r.nameOf(2), 'KN2');

    final rev = r.reversed();
    await repo.setPoints(saved.id!, rev.points, rev.pointNames);
    r = (await repo.watchAll().first).single;
    expect(r.points, pts.reversed.toList());
    expect(r.nameOf(0), 'BAŞLANGIÇ');
    expect(r.nameOf(2), 'KARAKOL');

    // Eski biçim: yalnız [lat, lon].
    await db.customUpdate(
      "UPDATE route_plans SET points_json = '[[1.0,2.0],[3.0,4.0]]'",
      updates: {db.routePlans},
    );
    r = (await repo.watchAll().first).single;
    expect(r.points, const [LatLng(1, 2), LatLng(3, 4)]);
    expect(r.pointNames, [null, null]);
  });

  test('planlama: ekle/geri al/temizle; 2 noktadan azsa kaydetmez', () async {
    final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    final n = c.read(routePlanningProvider.notifier);

    n.start();
    expect(c.read(routePlanningProvider).active, isTrue);
    n.addPoint(const LatLng(39.0, 32.0));
    expect(await n.save('tek nokta'), isNull); // < 2 nokta

    n.addPoint(const LatLng(39.01, 32.0));
    n.addPoint(const LatLng(39.02, 32.0));
    n.undo();
    expect(c.read(routePlanningProvider).points, hasLength(2));

    final id = await n.save('R1');
    expect(id, isNotNull);
    expect(c.read(routePlanningProvider).active, isFalse); // kaydedince kapanır
    expect((await RouteRepository(db).watchAll().first).single.name, 'R1');

    n.start();
    n.addPoint(const LatLng(39.0, 32.0));
    n.clear();
    expect(c.read(routePlanningProvider).points, isEmpty);
    n.cancel();
    expect(c.read(routePlanningProvider).active, isFalse);
  });
}
