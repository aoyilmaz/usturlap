import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/db/imported_layer_repository.dart';
import 'package:kerteriz/domain/models/imported_layer.dart';

void main() {
  late AppDatabase db;
  late ImportedLayerRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ImportedLayerRepository(db);
  });
  tearDown(() async => db.close());

  test('ekle → listele → sil', () async {
    expect(await repo.watchAll().first, isEmpty);

    await repo.upsert(const ImportedLayer(
      id: 'turkey.pmtiles',
      label: 'turkey',
      fileName: 'turkey.pmtiles',
      sourceType: 'pmtiles',
      stylePath: 'assets/style/protomaps_light.json',
      minZoom: 0,
      maxZoom: 14,
      centerLat: 39.0,
      centerLon: 35.0,
    ));

    final list = await repo.watchAll().first;
    expect(list, hasLength(1));
    final l = list.single;
    expect(l.label, 'turkey');
    expect(l.isVector, isTrue);
    expect(l.maxZoom, 14);
    expect(l.centerLat, closeTo(39.0, 1e-9));
    expect(l.stylePath, 'assets/style/protomaps_light.json');

    await repo.delete('turkey.pmtiles');
    expect(await repo.watchAll().first, isEmpty);
  });

  test('aynı id upsert → üzerine yazar (çift kayıt olmaz)', () async {
    await repo.upsert(const ImportedLayer(
      id: 'a.mbtiles',
      label: 'eski',
      fileName: 'a.mbtiles',
      sourceType: 'mbtiles',
    ));
    await repo.upsert(const ImportedLayer(
      id: 'a.mbtiles',
      label: 'yeni',
      fileName: 'a.mbtiles',
      sourceType: 'mbtiles',
      maxZoom: 16,
    ));
    final list = await repo.watchAll().first;
    expect(list, hasLength(1));
    expect(list.single.label, 'yeni');
    expect(list.single.isVector, isFalse);
    expect(list.single.maxZoom, 16);
  });
}
