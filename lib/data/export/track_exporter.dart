import 'dart:convert';

import '../../domain/models/track.dart';

/// Rota izlerini KML / GeoJSON metnine çeviren saf yardımcılar.
/// (Saf Dart → kolay test edilir; paylaşım katmanı ayrı.)
class TrackExporter {
  TrackExporter._();

  /// GeoJSON FeatureCollection (tek LineString).
  static String toGeoJson(Track track, List<TrackPoint> points) {
    final coords = points
        .map((p) => [
              p.position.longitude,
              p.position.latitude,
              if (p.altitude != null) p.altitude,
            ])
        .toList();

    final feature = {
      'type': 'Feature',
      'properties': {
        'name': track.name,
        'startedAt': track.startedAt.toUtc().toIso8601String(),
        if (track.endedAt != null)
          'endedAt': track.endedAt!.toUtc().toIso8601String(),
        'pointCount': points.length,
      },
      'geometry': {
        'type': 'LineString',
        'coordinates': coords,
      },
    };

    final fc = {
      'type': 'FeatureCollection',
      'features': [feature],
    };
    return const JsonEncoder.withIndent('  ').convert(fc);
  }

  /// KML (tek LineString placemark). Google Earth vb. açar.
  static String toKml(Track track, List<TrackPoint> points) {
    final coordsText = points
        .map((p) =>
            '${p.position.longitude},${p.position.latitude},${p.altitude ?? 0}')
        .join('\n          ');

    final name = _xml(track.name);
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>$name</name>
    <Placemark>
      <name>$name</name>
      <LineString>
        <tessellate>1</tessellate>
        <coordinates>
          $coordsText
        </coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>
''';
  }

  static String _xml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
