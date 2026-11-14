import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';

void main() {
  late AppDatabase db;
  late WaypointRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = WaypointRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('ekle → listele → sil akışı çalışır', () async {
    expect((await repo.watchAll().first), isEmpty);

    final id = await repo.add(
      name: 'ALFA',
      position: const LatLng(39.925, 32.866),
      note: 'köprü',
    );

    final list = await repo.watchAll().first;
    expect(list.length, 1);
    expect(list.first.name, 'ALFA');
    expect(list.first.note, 'köprü');
    expect(list.first.position.latitude, closeTo(39.925, 1e-9));

    await repo.delete(id);
    expect((await repo.watchAll().first), isEmpty);
  });

  test('en yeni waypoint listede üstte gelir', () async {
    await repo.add(name: 'ESKI', position: const LatLng(1, 1));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.add(name: 'YENI', position: const LatLng(2, 2));

    final list = await repo.watchAll().first;
    expect(list.first.name, 'YENI');
  });
}
