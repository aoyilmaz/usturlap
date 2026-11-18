import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:usturlap/data/cot/cot_mapper.dart';
import 'package:usturlap/data/cot/cot_xml.dart';
import 'package:usturlap/data/import/geojson_importer.dart';
import 'package:usturlap/data/import/gpx_kml_importer.dart';
import 'package:usturlap/data/import/kerteriz_data.dart';
import 'package:usturlap/domain/models/route_plan.dart';

/// Denetim 2026-11-16: başkasından gelen dosyalar çöküş türü hata yerine
/// temiz hata ya da güvenli varsayılan vermeli.
void main() {
  test('kerteriz verisinde yanlış türde alanlar varsayılana düşer', () {
    final w = KerterizData.waypoint(
      {'affiliation': 5, 'echelon': true, 'role': 1.5},
      name: 'a',
      position: const LatLng(1, 1),
    );
    expect(w.name, 'a');
    final g = KerterizData.graphic({
      'kind': 'graphic',
      'type': 'area',
      'points': [
        [1, 1],
        [1, 2],
        [2, 2],
      ],
      'geofence': true,
    }, name: 'b');
    expect(g?.geofence, isNull);
  });

  test('KML iz kimliği metin değilse yok sayılır', () {
    const kml =
        '<kml><Document><Placemark><name>İZ</name>'
        '<ExtendedData><Data name="kerteriz"><value>'
        '{"kind":"track","uid":123}</value></Data></ExtendedData>'
        '<LineString><coordinates>32,39 32.1,39.1</coordinates></LineString>'
        '</Placemark></Document></kml>';
    final r = GpxKmlImporter.parse(kml);
    expect(r.tracks.single.uid, isNull);
  });

  test('çok derin iç içe GeoJSON yığın taşırmaz, temiz hata verir', () {
    const depth = 200000;
    final s =
        '${'{"type":"GeometryCollection","geometries":[' * depth}'
        '${']}' * depth}';
    final json =
        '{"type":"FeatureCollection","features":[{"type":"Feature",'
        '"properties":{},"geometry":$s}]}';
    expect(() => GeoJsonImporter.parse(json), throwsA(isA<FormatException>()));
  });

  test('KML/GPX: aşırı nesne sayısı temiz hatayla reddedilir', () {
    final n = GpxKmlImporter.maxObjects + 1;
    final b = StringBuffer('<gpx>');
    for (var i = 0; i < n; i++) {
      b.write('<wpt lat="39" lon="32"><name>W$i</name></wpt>');
    }
    b.write('</gpx>');
    expect(
      () => GpxKmlImporter.parse(b.toString()),
      throwsA(isA<FormatException>()),
    );
  });

  test('CoT çizgisinde NaN koordinat atlanır', () {
    const xml =
        '<event version="2.0" uid="r1" type="b-m-r" how="h-e" '
        'time="2026-11-16T00:00:00Z" start="2026-11-16T00:00:00Z" '
        'stale="2026-11-17T00:00:00Z"><point lat="39" lon="32" hae="0" '
        'ce="9999999" le="9999999"/><detail>'
        '<link uid="a" type="b-m-p-w" point="NaN,NaN" relation="c"/>'
        '<link uid="b" type="b-m-p-w" point="39.0,32.0" relation="c"/>'
        '<link uid="c" type="b-m-p-w" point="39.1,32.1" relation="c"/>'
        '<contact callsign="ROTA"/></detail></event>';
    final mapper = CotMapper(
      creatorUid: 'PUSULA-test',
      creatorCallsign: 'KURT-1',
      clock: () => DateTime.utc(2026, 11, 16),
    );
    final item = mapper.toItem(CotXml.decode(xml));
    expect(item, isA<RoutePlan>());
    final pts = (item! as RoutePlan).points;
    expect(
      pts.every((p) => p.latitude.isFinite && p.longitude.isFinite),
      isTrue,
    );
    expect(pts, hasLength(2));
  });
}
