import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/data/db/attachment_repository.dart';
import 'package:usturlap/data/db/map_graphic_repository.dart';
import 'package:usturlap/data/db/range_line_repository.dart';
import 'package:usturlap/data/db/range_ring_repository.dart';
import 'package:usturlap/data/db/route_repository.dart';
import 'package:usturlap/data/db/settings_repository.dart';
import 'package:usturlap/data/db/track_repository.dart';
import 'package:usturlap/data/db/waypoint_repository.dart';
import 'package:usturlap/data/export/geo_exporter.dart';
import 'package:usturlap/data/import/geo_import.dart';
import 'package:usturlap/data/import/import_writer.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/data/import/gpx_kml_importer.dart';
import 'package:usturlap/domain/models/track.dart';
import 'package:usturlap/domain/models/route_plan.dart';
import 'package:usturlap/domain/models/sensor_fov.dart';
import 'package:usturlap/domain/models/waypoint.dart';
import 'package:latlong2/latlong.dart';

/// G7: içe aktarılanı veritabanına yazma.
void main() {
  late AppDatabase db;
  late Directory root;
  late ImportWriter writer;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('import_writer_');
    writer = ImportWriter(
      waypoints: WaypointRepository(db),
      graphics: MapGraphicRepository(db),
      tracks: TrackRepository(db),
      rangeLines: RangeLineRepository(db),
      rangeRings: RangeRingRepository(db),
      attachments: AttachmentRepository(db, documentsDir: () async => root),
      routes: RouteRepository(db),
      tempDir: root,
    );
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test(
    'KMZ: nokta (ayrıntı + fotoğraf), çizim; ikinci kez kopya olmaz',
    () async {
      final t0 = DateTime.utc(2026, 11, 11);
      final kmz = GeoExporter.toKmz(
        ExportSet(
          waypoints: [
            Waypoint(
              uid: 'wp-1',
              name: 'OP-1',
              position: const LatLng(39, 32),
              createdAt: t0,
              affiliation: Affiliation.hostile,
              elevation: 900,
              fov: const SensorFov(azimuth: 10, width: 40, range: 500),
            ),
          ],
          graphics: [
            MapGraphic(
              uid: 'g-1',
              name: 'ALAN-1',
              type: GraphicType.rectangle,
              points: const [
                LatLng(39, 32),
                LatLng(39, 33),
                LatLng(40, 33),
                LatLng(40, 32),
              ],
              colorValue: 0xFF2FB344,
              createdAt: t0,
              geofence: GeofenceTrigger.exit,
            ),
          ],
        ),
        name: 'Test',
        photos: {
          'wp-1': [
            KmzPhoto('.jpg', Uint8List.fromList([1, 2, 3])),
          ],
        },
      );
      final bundle = GeoImport.parse(kmz);
      final first = await writer.write(bundle);
      expect(first.waypoints, 1);
      expect(first.graphics, 1);
      expect(first.photos, 1);
      expect(first.skipped, 0);
      expect(first.summary, '1 nokta, 1 çizim, 1 fotoğraf');

      final w = (await WaypointRepository(db).watchAll().first).single;
      expect(w.uid, 'wp-1');
      expect(w.affiliation, Affiliation.hostile);
      expect(w.elevation, 900);
      expect(w.fov!.range, 500);
      final pics = await AttachmentRepository(
        db,
        documentsDir: () async => root,
      ).watchFor('wp-1').first;
      expect(pics, hasLength(1));
      expect(await File(pics.single.filePath).readAsBytes(), [1, 2, 3]);
      final g = (await MapGraphicRepository(db).watchAll().first).single;
      expect(g.type, GraphicType.rectangle);
      expect(g.geofence, GeofenceTrigger.exit);
      // Geçici dosyalar silindi (yalnız ekler klasörü kaldı).
      expect(
        root.listSync().map(
          (e) => e.uri.pathSegments.lastWhere((s) => s != ''),
        ),
        ['attachments'],
      );

      final second = await writer.write(bundle);
      expect(second.added, 0);
      expect(second.skipped, 2);
      expect(await WaypointRepository(db).watchAll().first, hasLength(1));
    },
  );

  test('rotalar: nokta adlarıyla; aynı kimlik atlanır', () async {
    final kml = GeoExporter.toKml(
      ExportSet(
        routes: [
          RoutePlan(
            uid: 'r-1',
            name: 'DEVRİYE',
            points: const [LatLng(39, 32), LatLng(39.1, 32)],
            pointNames: const [null, 'KÖPRÜ'],
            createdAt: DateTime.utc(2026, 11, 11),
          ),
        ],
      ),
      name: 'T',
    );
    final b = GeoImport.parse(Uint8List.fromList(utf8.encode(kml)));
    expect((await writer.write(b)).summary, '1 rota');
    final r = (await RouteRepository(db).watchAll().first).single;
    expect(r.uid, 'r-1');
    expect(r.nameOf(1), 'KÖPRÜ');
    expect((await writer.write(b)).skipped, 1);
  });

  test('cihaz kimliği bir kez üretilir, sonra aynı', () async {
    final s = SettingsRepository(db);
    final a = await s.deviceUid();
    expect(a, startsWith('USTURLAP-'));
    expect(await s.deviceUid(), a);
  });

  test('kimliksiz dış veri her seferinde yeni eklenir', () async {
    final gpx = GeoImport.parse(
      Uint8List.fromList(
        '<gpx><wpt lat="39" lon="32"><name>K</name></wpt>'
                '<trk><trkseg><trkpt lat="39" lon="32"/><trkpt lat="39.1" lon="32"/>'
                '</trkseg></trk></gpx>'
            .codeUnits,
      ),
    );
    final r = await writer.write(gpx);
    expect(r.summary, '1 nokta, 1 iz');
    await writer.write(gpx);
    expect(await WaypointRepository(db).watchAll().first, hasLength(2));
  });

  group('denetim 2026-11-16', () {
    Uint8List b(String text) => Uint8List.fromList(utf8.encode(text));
    String pm(String name, int i) =>
        '<Placemark><name>$name</name><Point><coordinates>'
        '32.$i,39.$i</coordinates></Point></Placemark>';

    test(
      '80 karakterden uzun ad kırpılır, içe aktarma yarıda kalmaz',
      () async {
        final kml =
            '<kml><Document>${pm('BİR', 1)}${pm('x' * 120, 2)}'
            '${pm('ÜÇ', 3)}</Document></kml>';
        final report = await writer.write(GeoImport.parse(b(kml)));
        expect(report.waypoints, 3);
        final names = (await db.select(db.waypoints).get()).map((w) => w.name);
        expect(names, contains('x' * 80));
      },
    );

    test(
      'ortada hata olursa hiçbir nesne yazılmaz (ya hepsi ya hiçbiri)',
      () async {
        final atomic = ImportWriter(
          waypoints: WaypointRepository(db),
          graphics: MapGraphicRepository(db),
          tracks: TrackRepository(db),
          rangeLines: RangeLineRepository(db),
          rangeRings: RangeRingRepository(db),
          attachments: AttachmentRepository(db, documentsDir: () async => root),
          routes: RouteRepository(db),
          tempDir: root,
          db: db,
        );
        // İki nokta + tek noktalı (geçersiz) çizgi değil; yazımı bozmak için
        // aynı dosyada 2 noktadan sonra bozuk bir çizim (boş nokta listesi).
        final bundle = GeoImport.parse(
          b('<kml><Document>${pm('A', 1)}${pm('B', 2)}</Document></kml>'),
        );
        final bad = ImportBundle(
          ImportResult(
            bundle.result.waypoints,
            const [],
            graphics: [
              MapGraphic(
                uid: 'g-bozuk',
                name: 'BOZUK',
                type: GraphicType.line,
                // NaN koordinat: kaydederken jsonEncode hata verir.
                points: const [LatLng(double.nan, 0), LatLng(1, 1)],
                colorValue: 0xFFFF0000,
                createdAt: DateTime.utc(2026),
              ),
            ],
          ),
        );
        await expectLater(atomic.write(bad), throwsA(anything));
        expect(await db.select(db.waypoints).get(), isEmpty);
        expect(await db.select(db.mapGraphics).get(), isEmpty);

        // Düzgün dosya sonradan sorunsuz gelir (kimlikler "zaten var" sayılmaz).
        final ok = await atomic.write(bundle);
        expect(ok.waypoints, 2);
        expect(ok.skipped, 0);
      },
    );

    test(
      'dışa aktarılan iz geri alınınca zaman, yükseklik ve hız korunur',
      () async {
        final t0 = DateTime.utc(2026, 11, 10, 8, 30);
        final pts = [
          for (var i = 0; i < 4; i++)
            TrackPoint(
              position: LatLng(39 + i * 0.001, 32),
              timestamp: t0.add(Duration(minutes: i * 5)),
              altitude: 1000.0 + i * 10,
              speedMps: 1.25 + i,
            ),
        ];
        final track = Track(
          id: 1,
          uid: 'iz-1',
          name: 'SABAH',
          startedAt: t0,
          endedAt: t0.add(const Duration(minutes: 15)),
        );
        final set = ExportSet(tracks: [TrackExport(track, pts)]);
        for (final format in ['kml', 'geojson', 'gpx']) {
          final text = switch (format) {
            'kml' => GeoExporter.toKml(set, name: 't'),
            'gpx' => GeoExporter.toGpx(set, name: 't'),
            _ => GeoExporter.toGeoJson(set, name: 't'),
          };
          final fresh = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(fresh.close);
          final w = ImportWriter(
            waypoints: WaypointRepository(fresh),
            graphics: MapGraphicRepository(fresh),
            tracks: TrackRepository(fresh),
            rangeLines: RangeLineRepository(fresh),
            rangeRings: RangeRingRepository(fresh),
            attachments: AttachmentRepository(
              fresh,
              documentsDir: () async => root,
            ),
            tempDir: root,
          );
          await w.write(GeoImport.parse(b(text)));
          final row = (await fresh.select(fresh.tracks).get()).single;
          final got = await TrackRepository(fresh).pointsOf(row.id);
          expect(row.startedAt.toUtc(), t0, reason: format);
          expect(
            row.endedAt!.toUtc(),
            t0.add(const Duration(minutes: 15)),
            reason: format,
          );
          expect(
            [for (final p in got) p.timestamp.toUtc()],
            [for (final p in pts) p.timestamp],
            reason: format,
          );
          expect(
            [for (final p in got) p.altitude],
            [1000.0, 1010.0, 1020.0, 1030.0],
            reason: format,
          );
          if (format != 'gpx') {
            // GPX'te hız alanı yok.
            expect(
              [for (final p in got) p.speedMps],
              [1.25, 2.25, 3.25, 4.25],
              reason: format,
            );
          }
        }
      },
    );
  });
}
