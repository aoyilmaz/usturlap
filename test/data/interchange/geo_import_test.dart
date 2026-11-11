import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/import/geo_import.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:latlong2/latlong.dart';

Uint8List _b(String s) => Uint8List.fromList(utf8.encode(s));

/// G7: başka uygulamalardan gelen KML / KMZ / GeoJSON ve güvenlik.
void main() {
  test('KML: stil (StyleMap), alan, MultiGeometry, gx:Track, HTML not', () {
    const kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
<Document>
  <Style id="kirmizi"><LineStyle><color>ff0000ff</color><width>4.5</width></LineStyle></Style>
  <StyleMap id="harita"><Pair><key>normal</key><styleUrl>#kirmizi</styleUrl></Pair>
    <Pair><key>highlight</key><styleUrl>#yok</styleUrl></Pair></StyleMap>
  <Folder>
    <Placemark><name>BÖLGE</name><styleUrl>#harita</styleUrl>
      <Polygon><outerBoundaryIs><LinearRing><coordinates>
        32,39,0 33,39,0 33,40,0 32,39,0
      </coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark>
    <Placemark><name>ÇOKLU</name><description><![CDATA[<b>Not</b><br/>ikinci<img src="x.png"/>]]></description>
      <MultiGeometry>
        <Point><coordinates>32.5,39.5</coordinates></Point>
        <Point><coordinates>32.6,39.6</coordinates></Point>
      </MultiGeometry></Placemark>
    <Placemark><name>İZ</name><gx:Track>
      <when>2026-11-11T08:00:00Z</when><gx:coord>32 39 900</gx:coord>
      <when>2026-11-11T08:01:00Z</when><gx:coord>32.01 39.01 901</gx:coord>
    </gx:Track></Placemark>
    <Placemark><name>BOZUK</name><Point><coordinates>200,95</coordinates></Point></Placemark>
  </Folder>
</Document></kml>''';
    final r = GeoImport.parse(_b(kml)).result;
    final area = r.graphics.single;
    expect(area.name, 'BÖLGE');
    expect(area.type, GraphicType.area);
    expect(area.points, hasLength(3)); // kapanış noktası atılır
    expect(area.colorValue, 0xFFFF0000); // ff0000ff = kırmızı
    expect(area.strokeWidth, 4.5);
    expect(r.waypoints, hasLength(2)); // geçersiz koordinat atlanır
    expect(r.waypoints.first.note, 'Not\nikinci');
    expect(r.waypoints.first.photos, ['x.png']);
    expect(r.tracks.single.points.last, const LatLng(39.01, 32.01));
  });

  test('GeoJSON: Feature, MultiPolygon, simplestyle, bozuk koordinat', () {
    const j = '''{"type":"FeatureCollection","features":[
      {"type":"Feature","properties":{"title":"KUYU","desc":"su"},
       "geometry":{"type":"Point","coordinates":[32.5,39.5,812]}},
      {"type":"Feature","properties":{"name":"PARSEL","stroke":"#0f0","stroke-width":2},
       "geometry":{"type":"MultiPolygon","coordinates":[
         [[[32,39],[33,39],[33,40],[32,39]]],
         [[[34,39],[35,39],[35,40],[34,39]]]]}},
      {"type":"Feature","properties":{},"geometry":{"type":"LineString","coordinates":[[32,39],[32.1,39.1]]}},
      {"type":"Feature","properties":{},"geometry":{"type":"Point","coordinates":["a",1]}}
    ]}''';
    final r = GeoImport.parse(_b(j)).result;
    expect(r.waypoints.single.name, 'KUYU');
    expect(r.waypoints.single.note, 'su');
    expect(r.waypoints.single.elevation, 812);
    expect(r.graphics, hasLength(2));
    expect(r.graphics.first.colorValue, 0xFF00FF00);
    expect(r.graphics.first.strokeWidth, 2);
    expect(r.tracks.single.name, 'İZ');
  });

  test('bozuk / tanınmayan dosyalar Türkçe hatayla reddedilir', () {
    expect(() => GeoImport.parse(_b('<foo/>')), throwsFormatException);
    expect(() => GeoImport.parse(_b('{"type":5}')), throwsFormatException);
    expect(() => GeoImport.parse(_b('{bozuk')), throwsFormatException);
    expect(
      () => GeoImport.parse(Uint8List.fromList([0x50, 0x4B, 3, 4, 0, 0])),
      throwsFormatException,
    );
  });

  test('KMZ güvenliği: KML yoksa, klasör dışı yol, büyük girdi', () {
    Uint8List zip(Map<String, List<int>> files) {
      final a = Archive();
      files.forEach((k, v) => a.addFile(ArchiveFile.bytes(k, v)));
      return ZipEncoder().encodeBytes(a);
    }

    expect(
      () => GeoImport.parse(
        zip({
          'a.txt': [1],
        }),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'mesaj',
          contains('KML'),
        ),
      ),
    );
    // Klasör dışına çıkan girdiler yok sayılır (ana belge seçilmez).
    expect(GeoImport.safePath('../doc.kml'), isFalse);
    expect(GeoImport.safePath('/etc/doc.kml'), isFalse);
    expect(GeoImport.safePath('a/../../b.kml'), isFalse);
    expect(GeoImport.safePath('C:x.kml'), isFalse);
    expect(GeoImport.safePath('files/a.jpg'), isTrue);
    const kml =
        '<kml><Document><Placemark><name>A</name><description>'
        '&lt;img src="../evil.jpg"&gt;&lt;img src="./files/ok.jpg"&gt;'
        '</description><Point><coordinates>32,39</coordinates></Point>'
        '</Placemark></Document></kml>';
    final b = GeoImport.parse(
      zip({
        '../doc.kml': utf8.encode('<kml/>'),
        'doc.kml': utf8.encode(kml),
        '../evil.jpg': [1],
        'files/ok.jpg': [2],
      }),
    );
    expect(b.result.waypoints.single.name, 'A');
    expect(b.files.keys, ['files/ok.jpg']);

    // Bildirilen açılmış boyut sınırı aşılırsa açılmadan reddedilir.
    final big = Uint8List(GeoImport.maxEntryBytes + 1);
    expect(
      () => GeoImport.parse(zip({'doc.kml': utf8.encode(kml), 'b.jpg': big})),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'mesaj',
          contains('çok büyük'),
        ),
      ),
    );
  });
}
