import 'package:latlong2/latlong.dart';

import '../../core/geo_math.dart';
import '../../domain/models/map_graphic.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/range_ring.dart';
import '../../domain/models/waypoint.dart';

/// Seçilen nesneleri tek KML belgesine çevirir (Google Earth, ATAK ve çoğu
/// harita uygulaması açar). Saf Dart; paylaşım katmanı ayrı.
class SelectionExporter {
  SelectionExporter._();

  static String toKml({
    required String name,
    List<Waypoint> waypoints = const [],
    List<MapGraphic> graphics = const [],
    List<RangeLine> rangeLines = const [],
    List<RangeRing> rangeRings = const [],
  }) {
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2">')
      ..writeln('  <Document>')
      ..writeln('    <name>${_xml(name)}</name>');
    for (final w in waypoints) {
      b.writeln('    <Placemark>');
      b.writeln('      <name>${_xml(w.name)}</name>');
      final note = w.note;
      if (note != null && note.isNotEmpty) {
        b.writeln('      <description>${_xml(note)}</description>');
      }
      b.writeln(
        '      <Point><coordinates>${_c(w.position)}</coordinates></Point>',
      );
      b.writeln('    </Placemark>');
    }
    for (final g in graphics) {
      _shape(b, g.name, g.outline, closed: g.closed, argb: g.colorValue);
    }
    for (final l in rangeLines) {
      _shape(
        b,
        l.name,
        [l.start.point, l.end.point],
        closed: false,
        argb: l.colorValue,
      );
    }
    for (final r in rangeRings) {
      if (r.radii.isEmpty) continue;
      _shape(
        b,
        r.name,
        GeoMath.circlePoints(r.center.point, r.radii.last),
        closed: true,
        argb: r.colorValue,
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
  }) {
    if (pts.length < 2) return;
    final coords = [...pts, if (closed) pts.first].map(_c).join(' ');
    b
      ..writeln('    <Placemark>')
      ..writeln('      <name>${_xml(name)}</name>')
      ..writeln(
        '      <Style><LineStyle><color>${kmlColor(argb)}</color>'
        '<width>3</width></LineStyle>'
        '<PolyStyle><color>${kmlColor((argb & 0x00FFFFFF) | 0x40000000)}'
        '</color></PolyStyle></Style>',
      );
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

  /// ARGB → KML renk (aabbggrr, onaltılık).
  static String kmlColor(int argb) {
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    final a = (argb >> 24) & 0xFF, r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF, bl = argb & 0xFF;
    return '${h(a)}${h(bl)}${h(g)}${h(r)}';
  }

  static String _c(LatLng p) => '${p.longitude},${p.latitude},0';

  static String _xml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
