import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/data/wipe/content_wiper.dart';

void main() {
  group('AppDatabase.wipeAll', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> seed() async {
      await db
          .into(db.waypoints)
          .insert(
            WaypointsCompanion.insert(
              name: 'OP-1',
              lat: 39.9,
              lon: 32.8,
              createdAt: DateTime(2026),
            ),
          );
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: 'callsign', value: 'KURT-1'));
      await db
          .into(db.importedLayers)
          .insert(
            ImportedLayersCompanion.insert(
              id: 'imp-1',
              label: 'Gaziantep',
              fileName: 'gaziantep.pmtiles',
              sourceType: 'vectorPmtiles',
              createdAt: DateTime(2026),
              minZoom: const Value(0),
            ),
          );
    }

    test('bütün tablolar boşalır', () async {
      await seed();
      await db.wipeAll();
      expect(await db.select(db.waypoints).get(), isEmpty);
      expect(await db.select(db.settings).get(), isEmpty);
      expect(await db.select(db.importedLayers).get(), isEmpty);
    });

    test('haritalar korunurken içe aktarılan katman kayıtları kalır', () async {
      await seed();
      await db.wipeAll(keepImportedLayers: true);
      expect(await db.select(db.waypoints).get(), isEmpty);
      expect(await db.select(db.settings).get(), isEmpty);
      expect(await db.select(db.importedLayers).get(), hasLength(1));
    });

    test('kimlik sayaçları sıfırlanır (silinen kayıt sayısı sızmaz)', () async {
      await seed();
      await db.wipeAll();
      final id = await db.into(db.waypoints).insert(WaypointsCompanion.insert(
          name: 'Yeni', lat: 0, lon: 0, createdAt: DateTime(2026)));
      expect(id, 1);
    });

    test('silmeden sonra veritabanı kullanılabilir', () async {
      await seed();
      await db.wipeAll();
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: 'night_mode', value: 'true'));
      expect(await db.select(db.settings).get(), hasLength(1));
    });
  });

  group('ContentWiper.wipeFiles', () {
    late Directory root, docs, temp;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('wipe_test_');
      docs = await Directory('${root.path}/Documents').create();
      temp = await Directory('${root.path}/tmp').create();
      for (final f in [
        'pusula.sqlite',
        'pusula.sqlite-wal',
        'gaziantep.pmtiles',
        'eski.MBTILES',
        'Inbox/rota.gpx',
        'tiles_external/N37E037.hgt',
        // Nokta fotoğrafları (D3e): her iki kipte de silinmeli.
        'attachments/uid-1/foto.jpg',
      ]) {
        await File('${docs.path}/$f').create(recursive: true);
      }
      await File('${temp.path}/iz-1.kml').create();
    });

    tearDown(() => root.delete(recursive: true));

    List<String> names(Directory d) =>
        [for (final e in d.listSync()) e.path.substring(d.path.length + 1)]
          ..sort();

    test('her şey silinir, açık veritabanı dosyaları kalır', () async {
      await ContentWiper.wipeFiles(docs, [temp], includeMaps: true);
      expect(names(docs), ['pusula.sqlite', 'pusula.sqlite-wal']);
      expect(names(temp), isEmpty);
    });

    test('haritalar korunur, diğer her şey silinir', () async {
      await ContentWiper.wipeFiles(docs, [temp], includeMaps: false);
      expect(names(docs), [
        'eski.MBTILES',
        'gaziantep.pmtiles',
        'pusula.sqlite',
        'pusula.sqlite-wal',
        'tiles_external',
      ]);
      expect(names(temp), isEmpty);
    });

    test('olmayan klasörler hata vermez', () async {
      await ContentWiper.wipeFiles(Directory('${root.path}/yok'), [
        Directory('${root.path}/yok2'),
      ], includeMaps: true);
    });
  });
}
