import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/map_graphic_repository.dart';
import 'package:kerteriz/data/db/route_repository.dart';
import 'package:kerteriz/data/db/track_repository.dart';
import 'package:kerteriz/data/db/waypoint_repository.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:kerteriz/domain/models/waypoint.dart';
import 'package:latlong2/latlong.dart';

/// v7 → v8 yükseltmesi.
///
/// `test/fixtures/db_v7.sqlite`: telefonda drift'in oluşturduğu gerçek v7
/// şeması + örnek kayıtlar (3 nokta, v4 öncesinden sembolsüz 1 nokta,
/// 2 grafik, 1 rota, 2 noktalı 1 iz, ayarlar, içe aktarılan katman).
void main() {
  late Directory dir;
  late AppDatabase db;

  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('migration_v8_');
    final file = await File(
      'test/fixtures/db_v7.sqlite',
    ).copy('${dir.path}/pusula.sqlite');
    db = AppDatabase.forTesting(NativeDatabase(file));
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('şema güncel sürüme (9) yükselir', () async {
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 9);
  });

  test('noktalar korunur, sembolleri CoT tipine dönüşür, uid alır', () async {
    final wps = await WaypointRepository(db).watchAll().first;
    expect(wps.map((w) => w.name).toSet(), {
      'Kuyu',
      '1. Manga',
      'Tank',
      'Eski',
    });
    Waypoint byName(String n) => wps.firstWhere((w) => w.name == n);

    expect(byName('Kuyu').note, 'Temiz su');
    expect(byName('Kuyu').cotType, 'b-m-p-s-m');
    expect(byName('1. Manga').affiliation, Affiliation.friend);
    expect(byName('1. Manga').echelon, Echelon.squad);
    expect(byName('1. Manga').cotType, 'a-f-G-U-C-I');
    expect(byName('Tank').cotType, 'a-h-G-U-C-A');
    expect(byName('Tank').echelon, Echelon.company);
    // v4 öncesi kayıt: sembol alanları boş → sade nokta.
    expect(byName('Eski').cotType, 'b-m-p-s-m');
    expect(byName('Eski').typeCode, isNull);
    expect(byName('Eski').hae, isNull);

    for (final w in wps) {
      expect(w.uid, matches(uuid), reason: w.name);
    }
    expect(wps.map((w) => w.uid).toSet(), hasLength(4));
  });

  test('grafikler, rota ve iz korunur ve uid alır', () async {
    final graphics = await MapGraphicRepository(db).watchAll().first;
    expect(graphics, hasLength(2));
    final area = graphics.firstWhere((g) => g.type == GraphicType.area);
    expect(area.name, 'Bölge A');
    expect(area.points, hasLength(3));

    final routes = await RouteRepository(db).watchAll().first;
    expect(routes.single.name, 'Devriye');
    expect(routes.single.points, hasLength(3));

    final tracks = await TrackRepository(db).watchTracks().first;
    expect(tracks.single.name, 'KURT İZ-1');
    expect(tracks.single.pointCount, 2);

    final uids = [
      ...graphics.map((g) => g.uid),
      routes.single.uid,
      tracks.single.uid,
    ];
    for (final u in uids) {
      expect(u, matches(uuid));
    }
    expect(uids.toSet(), hasLength(4));
  });

  test('ayarlar ve içe aktarılan katman kaydı korunur', () async {
    final s = await db.select(db.settings).get();
    expect(
      {for (final r in s) r.key: r.value},
      {'callsign': 'KURT-1', 'north_ref': 'magnetic'},
    );
    expect(await db.select(db.importedLayers).get(), hasLength(1));
  });

  test('uid benzersizliği indeksle korunur', () async {
    final wps = await WaypointRepository(db).watchAll().first;
    final taken = wps.first.uid;
    await expectLater(
      db.customStatement('UPDATE waypoints SET uid = ? WHERE id <> ?', [
        taken,
        wps.first.id,
      ]),
      throwsA(isA<SqliteException>()),
    );
  });

  test(
    'yeni kayıtlar uid ile eklenir; backfill tekrar çağrılınca değişmez',
    () async {
      final repo = WaypointRepository(db);
      final id = await repo.add(name: 'Yeni', position: const LatLng(37, 37));
      final before = (await repo.watchAll().first).map((w) => w.uid).toList();
      await db.backfillUids();
      final after = (await repo.watchAll().first).map((w) => w.uid).toList();
      expect(after, before);
      final nulls = await db
          .customSelect('SELECT count(*) AS c FROM waypoints WHERE uid IS NULL')
          .getSingle();
      expect(nulls.read<int>('c'), 0);
      expect(id, greaterThan(4));
    },
  );

  test('sembol değişince dışarıdan gelen ham tip bırakılır', () async {
    final repo = WaypointRepository(db);
    final id = await repo.add(
      name: 'ATAK hedefi',
      position: const LatLng(37, 37),
      affiliation: Affiliation.hostile,
      role: SymbolRole.armor,
      cotType: 'a-h-G-U-C-A-W',
    );
    Future<Waypoint> get() async =>
        (await repo.watchAll().first).firstWhere((w) => w.id == id);

    // Yalnızca ad değişti → ham tip korunur.
    await repo.updateDetails(
      id,
      name: 'Hedef 1',
      affiliation: Affiliation.hostile,
      role: SymbolRole.armor,
    );
    expect((await get()).cotType, 'a-h-G-U-C-A-W');

    // Sadakat değişti → sembolden türetilir.
    await repo.updateDetails(
      id,
      name: 'Hedef 1',
      affiliation: Affiliation.neutral,
      role: SymbolRole.armor,
    );
    expect((await get()).cotType, 'a-n-G-U-C-A');
  });

  test('ikinci açılış yükseltmeyi tekrarlamaz', () async {
    final first = (await WaypointRepository(
      db,
    ).watchAll().first).map((w) => w.uid).toSet();
    await db.close();
    db = AppDatabase.forTesting(
      NativeDatabase(File('${dir.path}/pusula.sqlite')),
    );
    final second = (await WaypointRepository(
      db,
    ).watchAll().first).map((w) => w.uid).toSet();
    expect(second, first);
  });
}
