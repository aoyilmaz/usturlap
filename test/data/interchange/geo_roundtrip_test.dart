import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/export/geo_exporter.dart';
import 'package:kerteriz/data/import/geo_import.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:kerteriz/domain/models/range_line.dart';
import 'package:kerteriz/domain/models/range_ring.dart';
import 'package:kerteriz/domain/models/sensor_fov.dart';
import 'package:kerteriz/domain/models/track.dart';
import 'package:kerteriz/domain/models/waypoint.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

/// G7: Pusula → dosya → Pusula kayıpsız; GPX dışa aktarma.
void main() {
  final t0 = DateTime.utc(2026, 11, 11, 8);
  final set = ExportSet(
    waypoints: [
      Waypoint(
        uid: 'wp-1',
        name: 'OP-1',
        position: const LatLng(39.1, 32.2),
        createdAt: t0,
        note: 'gözetleme <ön> & dinleme',
        affiliation: Affiliation.hostile,
        echelon: Echelon.squad,
        role: SymbolRole.values[1],
        typeCode: 'a-h-G-U-C-I',
        elevation: 912.5,
        fov: const SensorFov(azimuth: 45, width: 60, range: 900),
      ),
    ],
    graphics: [
      MapGraphic(
        uid: 'g-circle',
        name: 'DAİRE-1',
        type: GraphicType.circle,
        points: const [LatLng(39, 32), LatLng(39.01, 32)],
        colorValue: 0xFF2E7DFF,
        createdAt: t0,
        strokeWidth: 5,
        dashed: true,
        height: 25,
        geofence: GeofenceTrigger.both,
      ),
      MapGraphic(
        uid: 'g-line',
        name: 'HAT-1',
        type: GraphicType.line,
        points: const [LatLng(39, 32), LatLng(39.2, 32.3), LatLng(39.3, 32)],
        colorValue: 0xFFE03131,
        createdAt: t0,
      ),
    ],
    rangeLines: [
      RangeLine(
        uid: 'rb-1',
        name: 'R&B-1',
        start: const RbEnd(LatLng(39, 32)),
        end: const RbEnd(LatLng(39.1, 32)),
        colorValue: RangeLine.defaultColor,
        createdAt: t0,
      ),
    ],
    rangeRings: [
      RangeRing(
        uid: 'rr-1',
        name: 'HALKA-1',
        center: const RbEnd(LatLng(39, 32)),
        radii: const [500, 1000],
        colorValue: 0xFFFFFFFF,
        createdAt: t0,
      ),
    ],
    tracks: [
      TrackExport(
        Track(uid: 'tr-1', name: 'SABAH', startedAt: t0, pointCount: 3),
        [
          for (var i = 0; i < 3; i++)
            TrackPoint(
              position: LatLng(39 + i / 100, 32),
              timestamp: t0.add(Duration(minutes: i)),
              altitude: 900.0 + i,
            ),
        ],
      ),
    ],
  );

  void expectSame(ImportBundle b) {
    final r = b.result;
    final w = r.waypoints.single;
    expect(w.uid, 'wp-1');
    expect(w.name, 'OP-1');
    expect(w.position, const LatLng(39.1, 32.2));
    expect(w.note, 'gözetleme <ön> & dinleme');
    expect(w.affiliation, Affiliation.hostile);
    expect(w.echelon, Echelon.squad);
    expect(w.role, SymbolRole.values[1]);
    expect(w.cotType, 'a-h-G-U-C-I');
    expect(w.elevation, 912.5);
    expect(w.fov!.azimuth, 45);
    expect(w.fov!.range, 900);

    final c = r.graphics.firstWhere((g) => g.uid == 'g-circle');
    expect(c.type, GraphicType.circle);
    expect(c.points, const [LatLng(39, 32), LatLng(39.01, 32)]);
    expect(c.colorValue, 0xFF2E7DFF);
    expect(c.strokeWidth, 5);
    expect(c.dashed, isTrue);
    expect(c.height, 25);
    expect(c.geofence, GeofenceTrigger.both);
    final l = r.graphics.firstWhere((g) => g.uid == 'g-line');
    expect(l.type, GraphicType.line);
    expect(l.points, hasLength(3));
    // Çizgi çizim olarak döner (iz değil).
    expect(r.tracks.single.uid, 'tr-1');
    expect(r.tracks.single.points, hasLength(3));
    expect(r.rangeLines.single.uid, 'rb-1');
    expect(r.rangeLines.single.end.point, const LatLng(39.1, 32));
    expect(r.rangeRings.single.radii, [500, 1000]);
  }

  test('KML: kayıpsız gidip gelir; başka uygulama düz geometri görür', () {
    final kml = GeoExporter.toKml(set, name: 'Pusula');
    final doc = XmlDocument.parse(kml);
    // Daire başka uygulamalarda çokgen.
    expect(doc.findAllElements('Polygon'), hasLength(2)); // daire + halka
    expect(doc.findAllElements('Point'), hasLength(1));
    expectSame(GeoImport.parse(Uint8List.fromList(utf8.encode(kml))));
  });

  test('KMZ: belge + fotoğraflar; fotoğraf noktasına bağlı döner', () {
    final jpg = Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]);
    final kmz = GeoExporter.toKmz(
      set,
      name: 'Pusula',
      photos: {
        'wp-1': [KmzPhoto('.JPG', jpg)],
      },
    );
    final zip = ZipDecoder().decodeBytes(kmz);
    expect(zip.files.first.name, 'doc.kml');
    expect(zip.files.map((f) => f.name), contains('files/wp-1/1.jpg'));
    final b = GeoImport.parse(kmz);
    expect(b.format, 'KMZ');
    expectSame(b);
    final w = b.result.waypoints.single;
    expect(w.photos, ['files/wp-1/1.jpg']);
    expect(GeoImport.photoFor(b, w.photos.single), jpg);
    expect(b.result.photoCount, 1);
    // Açıklamada resim; not olarak yalnız metin döner.
    final kml = utf8.decode(zip.files.first.readBytes()!);
    expect(kml, contains('&lt;img src=&quot;files/wp-1/1.jpg&quot;'));
  });

  test('GeoJSON: simplestyle + kayıpsız gidip gelir', () {
    final text = GeoExporter.toGeoJson(set, name: 'Pusula');
    final j = jsonDecode(text) as Map<String, dynamic>;
    final features = j['features'] as List;
    expect(features, hasLength(6));
    final circle = features.firstWhere(
      (f) => f['properties']['name'] == 'DAİRE-1',
    );
    expect(circle['geometry']['type'], 'Polygon');
    expect(circle['properties']['stroke'], '#2e7dff');
    final b = GeoImport.parse(Uint8List.fromList(utf8.encode(text)));
    expect(b.format, 'GeoJSON');
    expectSame(b);
  });

  test('GPX: noktalar ve izler (yükseklik, zaman)', () {
    final gpx = GeoExporter.toGpx(set, name: 'Pusula');
    final doc = XmlDocument.parse(gpx);
    final wpt = doc.findAllElements('wpt').single;
    expect(wpt.getAttribute('lat'), '39.1');
    expect(wpt.getElement('ele')!.innerText, '912.5');
    expect(wpt.getElement('desc')!.innerText, 'gözetleme <ön> & dinleme');
    final pts = doc.findAllElements('trkpt').toList();
    expect(pts, hasLength(3));
    expect(pts.first.getElement('time')!.innerText, '2026-11-11T08:00:00.000Z');
    // Çizimler GPX'e girmez.
    expect(doc.findAllElements('rte'), isEmpty);
    final back = GeoImport.parse(Uint8List.fromList(utf8.encode(gpx)));
    expect(back.format, 'GPX');
    expect(back.result.waypoints.single.elevation, 912.5);
    expect(back.result.tracks.single.points, hasLength(3));
  });
}
