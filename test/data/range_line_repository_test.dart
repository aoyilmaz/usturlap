import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/range_line_repository.dart';
import 'package:usturlap/domain/models/range_line.dart';
import 'package:latlong2/latlong.dart';

void main() {
  late AppDatabase db;
  late RangeLineRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = RangeLineRepository(db);
  });
  tearDown(() async => db.close());

  test('ekle: uçlar, bağlar, renk ve uid korunur', () async {
    expect(await repo.watchAll().first, isEmpty);
    final id = await repo.add(
      name: 'R&B-1',
      start: const RbEnd(LatLng(37.06, 37.38), RbEnd.selfRef),
      end: RbEnd(const LatLng(37.1, 37.4), RbEnd.waypointRef('wp-uid')),
    );
    final l = (await repo.watchAll().first).single;
    expect(l.id, id);
    expect(l.name, 'R&B-1');
    expect(l.start.isSelf, isTrue);
    expect(l.start.point.latitude, closeTo(37.06, 1e-9));
    expect(l.end.waypointUid, 'wp-uid');
    expect(l.end.point.longitude, closeTo(37.4, 1e-9));
    expect(l.colorValue, RangeLine.defaultColor);
    expect(l.uid, hasLength(36)); // UUID v4
  });

  test('bağsız uç null bağla döner; yeniden adlandır ve sil', () async {
    final id = await repo.add(
      name: 'R&B-2',
      start: const RbEnd(LatLng(1, 2)),
      end: const RbEnd(LatLng(3, 4)),
    );
    expect((await repo.watchAll().first).single.start.ref, isNull);
    await repo.rename(id, 'HEDEF HATTI');
    expect((await repo.watchAll().first).single.name, 'HEDEF HATTI');
    await repo.delete(id);
    expect(await repo.watchAll().first, isEmpty);
  });

  test('acil silme R&B çizgilerini de siler', () async {
    await repo.add(
      name: 'R&B-3',
      start: const RbEnd(LatLng(1, 2)),
      end: const RbEnd(LatLng(3, 4)),
    );
    await db.wipeAll();
    expect(await repo.watchAll().first, isEmpty);
  });
}
