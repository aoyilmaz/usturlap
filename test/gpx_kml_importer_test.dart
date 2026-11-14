import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/import/gpx_kml_importer.dart';

void main() {
  group('GpxKmlImporter — GPX', () {
    test('wpt → waypoint (ad + not)', () {
      const gpx = '''
<?xml version="1.0"?>
<gpx version="1.1" creator="test">
  <wpt lat="39.92077" lon="32.85411">
    <name>ANKARA</name>
    <desc>başkent</desc>
  </wpt>
</gpx>''';
      final r = GpxKmlImporter.parse(gpx);
      expect(r.waypoints, hasLength(1));
      expect(r.tracks, isEmpty);
      final w = r.waypoints.single;
      expect(w.name, 'ANKARA');
      expect(w.note, 'başkent');
      expect(w.position.latitude, closeTo(39.92077, 1e-6));
      expect(w.position.longitude, closeTo(32.85411, 1e-6));
    });

    test('trk/trkseg/trkpt → iz', () {
      const gpx = '''
<gpx version="1.1">
  <trk>
    <name>SABAH YÜRÜYÜŞÜ</name>
    <trkseg>
      <trkpt lat="39.0" lon="32.0"></trkpt>
      <trkpt lat="39.1" lon="32.1"></trkpt>
      <trkpt lat="39.2" lon="32.2"></trkpt>
    </trkseg>
  </trk>
</gpx>''';
      final r = GpxKmlImporter.parse(gpx);
      expect(r.waypoints, isEmpty);
      expect(r.tracks, hasLength(1));
      expect(r.tracks.single.name, 'SABAH YÜRÜYÜŞÜ');
      expect(r.tracks.single.points, hasLength(3));
      expect(r.tracks.single.points.first.latitude, closeTo(39.0, 1e-9));
      expect(r.tracks.single.points.last.longitude, closeTo(32.2, 1e-9));
    });

    test('rte/rtept → iz (rota)', () {
      const gpx = '''
<gpx><rte><name>R1</name>
  <rtept lat="40.0" lon="29.0"/>
  <rtept lat="40.5" lon="29.5"/>
</rte></gpx>''';
      final r = GpxKmlImporter.parse(gpx);
      expect(r.tracks, hasLength(1));
      expect(r.tracks.single.points, hasLength(2));
    });

    test('isimsiz wpt varsayılan ad alır', () {
      const gpx = '<gpx><wpt lat="1" lon="2"/></gpx>';
      final r = GpxKmlImporter.parse(gpx);
      expect(r.waypoints.single.name, 'WPT');
      expect(r.waypoints.single.note, isNull);
    });
  });

  group('GpxKmlImporter — KML', () {
    test('Placemark/Point → waypoint', () {
      const kml = '''
<?xml version="1.0"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>HEDEF</name>
      <description>not</description>
      <Point><coordinates>32.85411,39.92077,0</coordinates></Point>
    </Placemark>
  </Document>
</kml>''';
      final r = GpxKmlImporter.parse(kml);
      expect(r.waypoints, hasLength(1));
      final w = r.waypoints.single;
      expect(w.name, 'HEDEF');
      expect(w.note, 'not');
      // KML lon,lat sırası → LatLng'e doğru çevrilmeli
      expect(w.position.latitude, closeTo(39.92077, 1e-6));
      expect(w.position.longitude, closeTo(32.85411, 1e-6));
    });

    test('Placemark/LineString → iz (çok noktalı)', () {
      const kml = '''
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Placemark>
    <name>YOL</name>
    <LineString>
      <coordinates>
        29.0,40.0,0
        29.5,40.5,0
        30.0,41.0,0
      </coordinates>
    </LineString>
  </Placemark>
</kml>''';
      final r = GpxKmlImporter.parse(kml);
      expect(r.tracks, hasLength(1));
      expect(r.tracks.single.name, 'YOL');
      expect(r.tracks.single.points, hasLength(3));
      expect(r.tracks.single.points.first.latitude, closeTo(40.0, 1e-9));
      expect(r.tracks.single.points.first.longitude, closeTo(29.0, 1e-9));
    });
  });

  group('GpxKmlImporter — hata/sınır', () {
    test('desteklenmeyen kök → FormatException', () {
      expect(() => GpxKmlImporter.parse('<foo/>'),
          throwsA(isA<FormatException>()));
    });

    test('geçersiz XML → FormatException', () {
      expect(() => GpxKmlImporter.parse('not xml at all'),
          throwsA(isA<FormatException>()));
    });

    test('boş gpx → boş sonuç', () {
      final r = GpxKmlImporter.parse('<gpx></gpx>');
      expect(r.isEmpty, isTrue);
      expect(r.total, 0);
    });
  });
}
