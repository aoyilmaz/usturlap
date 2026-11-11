import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/export/geo_exporter.dart';
import 'package:kerteriz/data/import/geo_import.dart';
import 'package:kerteriz/data/package/data_package.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:kerteriz/domain/models/range_line.dart';
import 'package:kerteriz/domain/models/route_plan.dart';
import 'package:kerteriz/domain/models/sensor_fov.dart';
import 'package:kerteriz/domain/models/waypoint.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

Uint8List _zip(
  Map<String, String> text, [
  Map<String, List<int>> bin = const {},
]) {
  final a = Archive();
  text.forEach((k, v) => a.addFile(ArchiveFile.bytes(k, utf8.encode(v))));
  bin.forEach((k, v) => a.addFile(ArchiveFile.bytes(k, v)));
  return ZipEncoder().encodeBytes(a);
}

String _cot(
  String uid,
  String type, {
  String callsign = 'X',
  String extra = '',
}) =>
    '''<?xml version='1.0' encoding='UTF-8' standalone='yes'?>
<event version="2.0" uid="$uid" type="$type" time="2026-11-11T08:00:00.000Z"
  start="2026-11-11T08:00:00.000Z" stale="2027-11-11T08:00:00.000Z" how="h-g-i-g-o">
  <point lat="39.5" lon="32.5" hae="9999999.0" ce="9999999.0" le="9999999.0"/>
  <detail><contact callsign="$callsign"/><remarks>not</remarks>$extra</detail>
</event>''';

/// G8: ATAK uyumlu veri paketi.
void main() {
  final t0 = DateTime.utc(2026, 11, 11);
  final set = ExportSet(
    waypoints: [
      Waypoint(
        uid: 'wp-1',
        name: 'OP-1',
        position: const LatLng(39.1, 32.2),
        createdAt: t0,
        note: 'gözetleme',
        affiliation: Affiliation.hostile,
        elevation: 912,
        fov: const SensorFov(azimuth: 30, width: 60, range: 800),
      ),
    ],
    graphics: [
      MapGraphic(
        uid: 'g-1',
        name: 'DAİRE-1',
        type: GraphicType.circle,
        points: const [LatLng(39, 32), LatLng(39.01, 32)],
        colorValue: 0xFF2E7DFF,
        createdAt: t0,
        dashed: true,
        geofence: GeofenceTrigger.entry,
      ),
    ],
    routes: [
      RoutePlan(
        uid: 'r-1',
        name: 'DEVRİYE',
        points: const [LatLng(39, 32), LatLng(39.1, 32.1), LatLng(39.2, 32)],
        pointNames: const [null, 'KÖPRÜ', null],
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
  );
  final jpg = Uint8List.fromList([0xFF, 0xD8, 9, 9]);

  test('yapı: manifest v2, <uid>/<uid>.cot, ek uid ile bağlı, ekler KML', () {
    final zip = DataPackage.build(
      set,
      name: 'Görev <1>',
      creatorUid: 'KERTERIZ-test',
      creatorCallsign: 'KURT-1',
      photos: {
        'wp-1': [KmzPhoto('.jpg', jpg)],
      },
      packageUid: 'pkg-1',
    );
    final a = ZipDecoder().decodeBytes(zip);
    final names = a.files.map((f) => f.name).toList();
    expect(names.first, 'MANIFEST/manifest.xml');
    expect(
      names,
      containsAll([
        'wp-1/wp-1.cot',
        'wp-1/foto_1.jpg',
        'g-1/g-1.cot',
        'r-1/r-1.cot',
        DataPackage.extrasPath,
      ]),
    );
    final m = XmlDocument.parse(utf8.decode(a.files.first.readBytes()!));
    final root = m.rootElement;
    expect(root.name.local, 'MissionPackageManifest');
    expect(root.getAttribute('version'), '2');
    String? conf(String n) => root
        .findAllElements('Parameter')
        .firstWhere((p) => p.getAttribute('name') == n)
        .getAttribute('value');
    expect(conf('uid'), 'pkg-1');
    expect(conf('name'), 'Görev <1>');
    final photo = root
        .findAllElements('Content')
        .firstWhere((c) => c.getAttribute('zipEntry') == 'wp-1/foto_1.jpg');
    expect(
      photo
          .findElements('Parameter')
          .firstWhere((p) => p.getAttribute('name') == 'uid')
          .getAttribute('value'),
      'wp-1',
    );
    final cot = utf8.decode(
      a.files.firstWhere((f) => f.name == 'wp-1/wp-1.cot').readBytes()!,
    );
    expect(cot, contains('type="a-h-G"'));
    expect(cot, contains('KERTERIZ-test'));
    expect(cot, contains('<${DataPackage.kerterizTag}>'));
  });

  test('Pusula → paket → Pusula kayıpsız', () {
    final zip = DataPackage.build(
      set,
      name: 'Görev',
      creatorUid: 'KERTERIZ-test',
      creatorCallsign: 'KURT-1',
      photos: {
        'wp-1': [KmzPhoto('.jpg', jpg)],
      },
    );
    final b = GeoImport.parse(zip);
    expect(b.format, 'Veri paketi');
    expect(b.packageName, 'Görev');
    expect(b.skipped, isEmpty);
    final r = b.result;
    final w = r.waypoints.single;
    expect(w.uid, 'wp-1');
    expect(w.affiliation, Affiliation.hostile);
    expect(w.note, 'gözetleme');
    expect(w.elevation, 912);
    expect(w.fov!.width, 60);
    expect(w.photos, ['wp-1/foto_1.jpg']);
    expect(GeoImport.photoFor(b, w.photos.single), jpg);
    final g = r.graphics.single;
    expect(g.type, GraphicType.circle);
    expect(g.dashed, isTrue);
    expect(g.geofence, GeofenceTrigger.entry);
    final route = r.routes.single;
    expect(route.uid, 'r-1');
    expect(route.nameOf(1), 'KÖPRÜ');
    expect(r.rangeLines.single.uid, 'rb-1');
  });

  test('dış paket: CoT + ek; ayar, uygulama, tanınmayan, yok say atlanır', () {
    const manifest = '''<MissionPackageManifest version="2">
  <Configuration>
    <Parameter name="uid" value="p"/>
    <Parameter name="name" value="ATAK paketi"/>
    <Parameter name="onReceiveAction" value="com.atakmap.android.EVIL"/>
  </Configuration>
  <Contents>
    <Content ignore="false" zipEntry="a1/a1.cot"><Parameter name="uid" value="a1"/></Content>
    <Content ignore="false" zipEntry="ekler/foto.jpg"><Parameter name="uid" value="a1"/></Content>
    <Content ignore="false" zipEntry="c1/c1.cot"><Parameter name="uid" value="c1"/></Content>
    <Content ignore="false" zipEntry="ayar.pref"/>
    <Content ignore="false" zipEntry="eklenti.apk"/>
    <Content ignore="true" zipEntry="eski/eski.cot"/>
    <Content ignore="false" zipEntry="notlar.txt"/>
  </Contents>
</MissionPackageManifest>''';
    final b = GeoImport.parse(
      _zip(
        {
          'MANIFEST/manifest.xml': manifest,
          'a1/a1.cot': _cot('a1', 'a-h-G-U-C', callsign: 'DÜŞMAN'),
          'c1/c1.cot': _cot('c1', 'u-d-c-c'),
          'eski/eski.cot': _cot('eski', 'a-f-G'),
          'ayar.pref': '<preferences/>',
          'notlar.txt': 'x',
        },
        {
          'ekler/foto.jpg': [1, 2],
          'eklenti.apk': [3],
        },
      ),
    );
    expect(b.packageName, 'ATAK paketi');
    final w = b.result.waypoints.single;
    expect(w.uid, 'a1');
    expect(w.name, 'DÜŞMAN');
    expect(w.affiliation, Affiliation.hostile);
    expect(w.photos, ['ekler/foto.jpg']);
    final reasons = {for (final s in b.skipped) s.name: s.reason};
    expect(reasons['c1.cot'], contains('u-d-c-c'));
    expect(reasons['ayar.pref'], contains('ayar'));
    expect(reasons['eklenti.apk'], contains('uygulama'));
    expect(reasons['eski.cot'], contains('yok say'));
    expect(reasons['notlar.txt'], 'tanınmayan dosya');
  });

  test('manifestsiz paket: resim .cot ile aynı klasördeyse ona eklenir', () {
    final b = GeoImport.parse(
      _zip(
        {'n1/n1.cot': _cot('n1', 'b-m-p-s-m')},
        {
          'n1/resim.png': [7],
          'yalniz.jpg': [8],
        },
      ),
    );
    expect(b.format, 'Veri paketi');
    expect(b.result.waypoints.single.photos, ['n1/resim.png']);
    expect(
      {for (final s in b.skipped) s.name: s.reason}['yalniz.jpg'],
      contains('bağlı olmayan'),
    );
  });

  test('pakette güvensiz yol ve iç KML', () {
    const kml =
        '<kml><Document><Placemark><name>K</name>'
        '<Point><coordinates>32,39</coordinates></Point></Placemark>'
        '</Document></kml>';
    final b = GeoImport.parse(
      _zip({
        'x1/x1.cot': _cot('x1', 'a-u-G'),
        '../kacak.cot': _cot('k', 'a-u-G'),
        'katman/harita.kml': kml,
      }),
    );
    expect(b.result.waypoints.map((w) => w.name), containsAll(['X', 'K']));
    expect(
      {for (final s in b.skipped) s.name: s.reason}['../kacak.cot'],
      contains('güvensiz'),
    );
  });
}
