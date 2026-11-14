import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';
import '../../domain/models/map_graphic.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/range_ring.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/models/track.dart';
import '../../domain/models/waypoint.dart';

/// Dışa aktarılacak nesneler.
class ExportSet {
  const ExportSet({
    this.waypoints = const [],
    this.graphics = const [],
    this.rangeLines = const [],
    this.rangeRings = const [],
    this.tracks = const [],
    this.routes = const [],
  });

  final List<Waypoint> waypoints;
  final List<MapGraphic> graphics;
  final List<RangeLine> rangeLines;
  final List<RangeRing> rangeRings;
  final List<TrackExport> tracks;
  final List<RoutePlan> routes;

  int get count =>
      waypoints.length +
      graphics.length +
      rangeLines.length +
      rangeRings.length +
      tracks.length +
      routes.length;

  bool get isEmpty => count == 0;
}

/// Noktalarıyla bir iz.
class TrackExport {
  const TrackExport(this.track, this.points);

  final Track track;
  final List<TrackPoint> points;
}

/// KMZ'ye konacak bir fotoğraf.
class KmzPhoto {
  const KmzPhoto(this.extension, this.bytes);

  /// Nokta dahil uzantı (".jpg").
  final String extension;
  final Uint8List bytes;
}

/// Dışa aktarma biçimleri.
enum ExportFormat {
  kmz('KMZ', 'kmz', 'Fotoğraflarla; Google Earth, TAK uyumlu uygulamalar'),
  package(
    'Veri paketi',
    'zip',
    'TAK uyumlu görev paketi (CoT + fotoğraflar)',
  ),
  kml('KML', 'kml', 'Google Earth, TAK uyumlu ve çoğu harita uygulaması'),
  gpx('GPX', 'gpx', 'Yalnız noktalar, izler ve rotalar; GPS cihazları'),
  geojson('GeoJSON', 'geojson', 'CBS yazılımları (QGIS vb.)');

  const ExportFormat(this.label, this.extension, this.hint);
  final String label;
  final String extension;
  final String hint;
}

/// Usturlap nesnelerini KML / KMZ / GPX / GeoJSON'a çevirir (saf Dart).
///
/// Başka uygulamalar standart geometrileri görür; Usturlap'ın kendi
/// ayrıntıları (daire, kalınlık, kesikli, 3B, geofence, sembol, kimlik)
/// KML'de `ExtendedData` içinde "kerteriz" verisi, GeoJSON'da "kerteriz"
/// özelliği olarak taşınır → Usturlap'tan Usturlap'a kayıpsız gidip gelir.
class GeoExporter {
  GeoExporter._();

  /// Usturlap verisinin anahtarı (eski adla "kerteriz"; eski dosyalar açılsın diye değişmez) (KML Data adı / GeoJSON özelliği).
  static const dataKey = 'kerteriz';

  // ------------------------------------------------------------------ KML

  /// [photos]: nokta uid'i → KMZ içindeki fotoğraf yolları (açıklamada
  /// resim olarak görünür).
  static String toKml(
    ExportSet s, {
    required String name,
    Map<String, List<String>> photos = const {},
  }) {
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2">')
      ..writeln('  <Document>')
      ..writeln('    <name>${_xml(name)}</name>');
    for (final w in s.waypoints) {
      final pics = photos[w.uid] ?? const <String>[];
      b.writeln('    <Placemark>');
      b.writeln('      <name>${_xml(w.name)}</name>');
      final note = w.note;
      final html = [
        if (note != null && note.isNotEmpty) note,
        for (final p in pics) '<img src="$p" width="480"/>',
      ].join('<br/>');
      if (html.isNotEmpty) {
        b.writeln('      <description>${_xml(html)}</description>');
      }
      _data(b, waypointData(w, photos: pics));
      b.writeln(
        '      <Point><coordinates>${_c(w.position)}</coordinates></Point>',
      );
      b.writeln('    </Placemark>');
    }
    for (final g in s.graphics) {
      _shape(
        b,
        g.name,
        g.outline,
        closed: g.closed,
        argb: g.colorValue,
        width: g.strokeWidth,
        data: graphicData(g),
      );
    }
    for (final l in s.rangeLines) {
      _shape(
        b,
        l.name,
        [l.start.point, l.end.point],
        closed: false,
        argb: l.colorValue,
        data: rangeLineData(l),
      );
    }
    for (final r in s.rangeRings) {
      if (r.radii.isEmpty) continue;
      _shape(
        b,
        r.name,
        GeoMath.circlePoints(r.center.point, r.radii.last),
        closed: true,
        argb: r.colorValue,
        data: rangeRingData(r),
      );
    }
    for (final t in s.tracks) {
      if (t.points.length < 2) continue;
      final coords = [
        for (final p in t.points)
          '${p.position.longitude},${p.position.latitude},${p.altitude ?? 0}',
      ].join(' ');
      b
        ..writeln('    <Placemark>')
        ..writeln('      <name>${_xml(t.track.name)}</name>')
        ..writeln(
          '      <Style><LineStyle><color>ff00a5ff</color><width>4</width>'
          '</LineStyle></Style>',
        );
      _data(b, {'kind': 'track', 'uid': t.track.uid});
      b
        ..writeln(
          '      <LineString><tessellate>1</tessellate><coordinates>'
          '$coords</coordinates></LineString>',
        )
        ..writeln('    </Placemark>');
    }
    for (final r in s.routes) {
      _shape(
        b,
        r.name,
        r.points,
        closed: false,
        argb: 0xFF7CFC00,
        width: 4,
        data: routeData(r),
      );
    }
    b
      ..writeln('  </Document>')
      ..writeln('</kml>');
    return b.toString();
  }

  static void _shape(
    StringBuffer b,
    String name,
    List<LatLng> pts, {
    required bool closed,
    required int argb,
    double width = 3,
    Map<String, Object?>? data,
  }) {
    if (pts.length < 2) return;
    final coords = [...pts, if (closed) pts.first].map(_c).join(' ');
    b
      ..writeln('    <Placemark>')
      ..writeln('      <name>${_xml(name)}</name>')
      ..writeln(
        '      <Style><LineStyle><color>${kmlColor(argb)}</color>'
        '<width>${_num(width)}</width></LineStyle>'
        '<PolyStyle><color>${kmlColor((argb & 0x00FFFFFF) | 0x40000000)}'
        '</color></PolyStyle></Style>',
      );
    if (data != null) _data(b, data);
    if (closed) {
      b.writeln(
        '      <Polygon><outerBoundaryIs><LinearRing><coordinates>'
        '$coords</coordinates></LinearRing></outerBoundaryIs></Polygon>',
      );
    } else {
      b.writeln(
        '      <LineString><tessellate>1</tessellate><coordinates>'
        '$coords</coordinates></LineString>',
      );
    }
    b.writeln('    </Placemark>');
  }

  static void _data(StringBuffer b, Map<String, Object?> data) {
    b.writeln(
      '      <ExtendedData><Data name="$dataKey"><value>'
      '${_xml(jsonEncode(data))}</value></Data></ExtendedData>',
    );
  }

  // ---------------------------------------------------------- Usturlap verisi

  static List<double> _ll(LatLng p) => [p.latitude, p.longitude];

  static Map<String, Object?> waypointData(
    Waypoint w, {
    List<String> photos = const [],
  }) => {
    'kind': 'waypoint',
    'uid': w.uid,
    if (w.note != null) 'note': w.note,
    'affiliation': w.affiliation.name,
    'echelon': w.echelon.name,
    'role': w.role.name,
    if (w.typeCode != null) 'cot': w.typeCode,
    if (w.hae != null) 'hae': w.hae,
    if (w.elevation != null) 'elevation': w.elevation,
    if (w.fov != null)
      'fov': {
        'azimuth': w.fov!.azimuth,
        'width': w.fov!.width,
        'range': w.fov!.range,
      },
    if (photos.isNotEmpty) 'photos': photos,
  };

  static Map<String, Object?> graphicData(MapGraphic g) => {
    'kind': 'graphic',
    'uid': g.uid,
    'type': g.type.name,
    'points': [for (final p in g.points) _ll(p)],
    'color': g.colorValue,
    'strokeWidth': g.strokeWidth,
    if (g.dashed) 'dashed': true,
    if (g.height != null) 'height': g.height,
    if (g.geofence != null) 'geofence': g.geofence!.name,
  };

  static Map<String, Object?> rangeLineData(RangeLine l) => {
    'kind': 'rangeLine',
    'uid': l.uid,
    'start': _ll(l.start.point),
    'end': _ll(l.end.point),
    'color': l.colorValue,
  };

  static Map<String, Object?> routeData(RoutePlan r) => {
    'kind': 'route',
    'uid': r.uid,
    'points': [for (final p in r.points) _ll(p)],
    if (r.pointNames.any((n) => n != null)) 'pointNames': r.pointNames,
  };

  static Map<String, Object?> rangeRingData(RangeRing r) => {
    'kind': 'rangeRing',
    'uid': r.uid,
    'center': _ll(r.center.point),
    'radii': r.radii,
    'color': r.colorValue,
  };

  // ------------------------------------------------------------------ KMZ

  /// KMZ: `doc.kml` + `files/<nokta>/<n>.jpg`. [photos]: nokta uid'i →
  /// fotoğrafları.
  static Uint8List toKmz(
    ExportSet s, {
    required String name,
    Map<String, List<KmzPhoto>> photos = const {},
  }) {
    final archive = Archive();
    final paths = <String, List<String>>{};
    var n = 0;
    for (final w in s.waypoints) {
      for (final p in photos[w.uid] ?? const <KmzPhoto>[]) {
        n++;
        final path = 'files/${_safe(w.uid)}/$n${_safeExt(p.extension)}';
        (paths[w.uid] ??= []).add(path);
        archive.addFile(ArchiveFile.bytes(path, p.bytes));
      }
    }
    final kml = utf8.encode(toKml(s, name: name, photos: paths));
    // Belge ilk dosya olsun (KMZ okuyucuların çoğu ilk KML'i açar).
    final out = Archive()..addFile(ArchiveFile.bytes('doc.kml', kml));
    for (final f in archive.files) {
      out.addFile(f);
    }
    return ZipEncoder().encodeBytes(out);
  }

  static String _safe(String s) {
    final r = s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return r.isEmpty || r == '.' || r == '..' ? '_' : r;
  }

  static String _safeExt(String ext) {
    final e = ext.toLowerCase();
    return const {'.jpg', '.jpeg', '.png', '.heic', '.gif'}.contains(e)
        ? e
        : '.jpg';
  }

  // ------------------------------------------------------------------ GPX

  /// GPX 1.1: noktalar (`wpt`), izler (`trk`) ve rotalar (`rte`). Çizimler
  /// ve ölçümler GPX'te yer almaz.
  static String toGpx(ExportSet s, {required String name}) {
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="Usturlap" '
        'xmlns="http://www.topografix.com/GPX/1/1">',
      )
      ..writeln('  <metadata><name>${_xml(name)}</name></metadata>');
    for (final w in s.waypoints) {
      b.writeln(
        '  <wpt lat="${w.position.latitude}" lon="${w.position.longitude}">',
      );
      final ele = w.elevation ?? w.hae;
      if (ele != null) b.writeln('    <ele>${_num(ele)}</ele>');
      b.writeln('    <name>${_xml(w.name)}</name>');
      final note = w.note;
      if (note != null && note.isNotEmpty) {
        b.writeln('    <desc>${_xml(note)}</desc>');
      }
      b.writeln('  </wpt>');
    }
    for (final t in s.tracks) {
      if (t.points.isEmpty) continue;
      b
        ..writeln('  <trk>')
        ..writeln('    <name>${_xml(t.track.name)}</name>')
        ..writeln('    <trkseg>');
      for (final p in t.points) {
        b.write(
          '      <trkpt lat="${p.position.latitude}" '
          'lon="${p.position.longitude}">',
        );
        if (p.altitude != null) b.write('<ele>${_num(p.altitude!)}</ele>');
        b.writeln(
          '<time>${p.timestamp.toUtc().toIso8601String()}</time></trkpt>',
        );
      }
      b
        ..writeln('    </trkseg>')
        ..writeln('  </trk>');
    }
    for (final r in s.routes) {
      b
        ..writeln('  <rte>')
        ..writeln('    <name>${_xml(r.name)}</name>');
      for (var i = 0; i < r.points.length; i++) {
        final p = r.points[i];
        b.writeln(
          '    <rtept lat="${p.latitude}" lon="${p.longitude}">'
          '<name>${_xml(r.nameOf(i))}</name></rtept>',
        );
      }
      b.writeln('  </rte>');
    }
    b.writeln('</gpx>');
    return b.toString();
  }

  // -------------------------------------------------------------- GeoJSON

  /// GeoJSON FeatureCollection. Renkler "simplestyle" özellikleriyle
  /// (stroke, stroke-width, fill) — QGIS, geojson.io vb. okur.
  static String toGeoJson(ExportSet s, {required String name}) {
    List<double> c(LatLng p) => [p.longitude, p.latitude];
    String hex(int argb) =>
        '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    Map<String, Object?> feature(
      Map<String, Object?> geometry,
      Map<String, Object?> props,
    ) => {'type': 'Feature', 'geometry': geometry, 'properties': props};
    Map<String, Object?> shape(List<LatLng> pts, bool closed) => closed
        ? {
            'type': 'Polygon',
            'coordinates': [
              [
                for (final p in [...pts, pts.first]) c(p),
              ],
            ],
          }
        : {
            'type': 'LineString',
            'coordinates': [for (final p in pts) c(p)],
          };

    final features = <Object>[
      for (final w in s.waypoints)
        feature(
          {'type': 'Point', 'coordinates': c(w.position)},
          {
            'name': w.name,
            if (w.note != null && w.note!.isNotEmpty) 'description': w.note,
            dataKey: waypointData(w),
          },
        ),
      for (final g in s.graphics)
        if (g.outline.length >= 2)
          feature(shape(g.outline, g.closed && g.outline.length >= 3), {
            'name': g.name,
            'stroke': hex(g.colorValue),
            'stroke-width': g.strokeWidth,
            if (g.closed) 'fill': hex(g.colorValue),
            if (g.closed) 'fill-opacity': 0.25,
            dataKey: graphicData(g),
          }),
      for (final l in s.rangeLines)
        feature(shape([l.start.point, l.end.point], false), {
          'name': l.name,
          'stroke': hex(l.colorValue),
          dataKey: rangeLineData(l),
        }),
      for (final r in s.rangeRings)
        if (r.radii.isNotEmpty)
          feature(
            shape(GeoMath.circlePoints(r.center.point, r.radii.last), true),
            {
              'name': r.name,
              'stroke': hex(r.colorValue),
              'fill-opacity': 0,
              dataKey: rangeRingData(r),
            },
          ),
      for (final t in s.tracks)
        if (t.points.length >= 2)
          feature(
            {
              'type': 'LineString',
              'coordinates': [
                for (final p in t.points)
                  [
                    p.position.longitude,
                    p.position.latitude,
                    if (p.altitude != null) p.altitude,
                  ],
              ],
            },
            {
              'name': t.track.name,
              'stroke': '#ffa500',
              dataKey: {'kind': 'track', 'uid': t.track.uid},
            },
          ),
      for (final r in s.routes)
        if (r.points.length >= 2)
          feature(shape(r.points, false), {
            'name': r.name,
            'stroke': '#7cfc00',
            dataKey: routeData(r),
          }),
    ];
    return const JsonEncoder.withIndent('  ').convert({
      'type': 'FeatureCollection',
      'name': name,
      'features': features,
    });
  }

  // ---------------------------------------------------------------- ortak

  /// ARGB → KML renk (aabbggrr, onaltılık).
  static String kmlColor(int argb) {
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    final a = (argb >> 24) & 0xFF, r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF, bl = argb & 0xFF;
    return '${h(a)}${h(bl)}${h(g)}${h(r)}';
  }

  static String _c(LatLng p) => '${p.longitude},${p.latitude},0';

  static String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  static String _xml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
