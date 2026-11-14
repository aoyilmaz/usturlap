import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/map_graphic_repository.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/domain/models/waypoint.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('MapGraphicRepository', () {
    test('çizgi ekle → noktalar/renk/tip korunur', () async {
      final repo = MapGraphicRepository(db);
      expect(await repo.watchAll().first, isEmpty);

      final pts = const [LatLng(39.0, 32.0), LatLng(39.1, 32.2)];
      final id = await repo.add(
        name: 'EKSEN-1',
        type: GraphicType.line,
        points: pts,
        colorValue: 0xFFE03131,
      );
      expect(id, greaterThan(0));

      final list = await repo.watchAll().first;
      expect(list, hasLength(1));
      final g = list.single;
      expect(g.name, 'EKSEN-1');
      expect(g.type, GraphicType.line);
      expect(g.colorValue, 0xFFE03131);
      expect(g.points, hasLength(2));
      expect(g.points.first.latitude, closeTo(39.0, 1e-9));
      expect(g.points.last.longitude, closeTo(32.2, 1e-9));
    });

    test('alan ekle ve sil', () async {
      final repo = MapGraphicRepository(db);
      final id = await repo.add(
        name: 'BÖLGE',
        type: GraphicType.area,
        points: const [
          LatLng(0, 0),
          LatLng(0, 1),
          LatLng(1, 1),
        ],
        colorValue: 0xFF2FB344,
      );
      var list = await repo.watchAll().first;
      expect(list.single.type, GraphicType.area);
      expect(list.single.points, hasLength(3));

      await repo.delete(id);
      expect(await repo.watchAll().first, isEmpty);
    });
  });

  group('Waypoint echelon/role (APP-6 v2)', () {
    test('echelon + rol kalıcı (round-trip)', () async {
      final repo = WaypointRepository(db);
      await repo.add(
        name: 'BÖLÜK',
        position: const LatLng(40, 30),
        affiliation: Affiliation.hostile,
        echelon: Echelon.company,
        role: SymbolRole.armor,
      );
      final wp = (await repo.watchAll().first).single;
      expect(wp.affiliation, Affiliation.hostile);
      expect(wp.echelon, Echelon.company);
      expect(wp.role, SymbolRole.armor);
    });

    test('varsayılan: echelon/role none', () async {
      final repo = WaypointRepository(db);
      await repo.add(name: 'WP', position: const LatLng(1, 1));
      final wp = (await repo.watchAll().first).single;
      expect(wp.echelon, Echelon.none);
      expect(wp.role, SymbolRole.none);
    });

    test('düzenle: echelon/role güncellenir', () async {
      final repo = WaypointRepository(db);
      final id = await repo.add(
        name: 'WP',
        position: const LatLng(1, 1),
        affiliation: Affiliation.friend,
      );
      await repo.updateDetails(
        id,
        name: 'WP2',
        affiliation: Affiliation.friend,
        echelon: Echelon.battalion,
        role: SymbolRole.artillery,
      );
      final wp = (await repo.watchAll().first).single;
      expect(wp.name, 'WP2');
      expect(wp.echelon, Echelon.battalion);
      expect(wp.role, SymbolRole.artillery);
    });
  });
}
