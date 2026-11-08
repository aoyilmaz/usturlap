import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/range_ring_repository.dart';
import 'package:kerteriz/domain/models/range_line.dart';
import 'package:kerteriz/domain/models/range_ring.dart';
import 'package:latlong2/latlong.dart';

void main() {
  late AppDatabase db;
  late RangeRingRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = RangeRingRepository(db);
  });
  tearDown(() async => db.close());

  test('ekle: merkez bağı, sıralı tekrarsız mesafeler, renk', () async {
    final id = await repo.add(
      name: 'HALKA-1',
      center: RbEnd(const LatLng(37.06, 37.38), RbEnd.waypointRef('d1')),
      radii: const [1500, 500, 1000, 500],
      colorValue: RangeRing.threatColor,
    );
    final r = (await repo.watchAll().first).single;
    expect(r.id, id);
    expect(r.center.waypointUid, 'd1');
    expect(r.center.point.latitude, closeTo(37.06, 1e-9));
    expect(r.radii, [500, 1000, 1500]);
    expect(r.colorValue, RangeRing.threatColor);
    expect(r.uid, hasLength(36));
  });

  test('mesafeleri değiştir, yeniden adlandır, sil', () async {
    final id = await repo.add(
      name: 'HALKA-2',
      center: const RbEnd(LatLng(1, 2)),
      radii: const [100],
      colorValue: RangeLine.defaultColor,
    );
    await repo.setRadii(id, const [300, 200]);
    await repo.rename(id, 'HAVAN');
    final r = (await repo.watchAll().first).single;
    expect(r.radii, [200, 300]);
    expect(r.name, 'HAVAN');
    expect(r.center.ref, isNull);
    await repo.delete(id);
    expect(await repo.watchAll().first, isEmpty);
  });

  test('bozuk mesafe kaydı halkasız okunur (silinebilsin)', () async {
    final id = await repo.add(
      name: 'BOZUK',
      center: const RbEnd(LatLng(1, 2)),
      radii: const [100],
      colorValue: RangeLine.defaultColor,
    );
    await db.customStatement(
      "UPDATE range_rings SET radii_json = 'bozuk' WHERE id = ?",
      [id],
    );
    expect((await repo.watchAll().first).single.radii, isEmpty);
  });
}
