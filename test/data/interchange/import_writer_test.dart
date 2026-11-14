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
}
