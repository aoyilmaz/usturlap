import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:kerteriz/data/export/track_exporter.dart';
import 'package:kerteriz/domain/models/track.dart';

void main() {
  final track = Track(
    id: 1,
    uid: '00000000-0000-4000-8000-000000000001',
    name: 'TEST İZ',
    startedAt: DateTime.utc(2026, 1, 1, 10),
    endedAt: DateTime.utc(2026, 1, 1, 10, 30),
    pointCount: 2,
  );
  final points = [
    TrackPoint(
        position: const LatLng(39.0, 32.0),
        timestamp: DateTime.utc(2026, 1, 1, 10),
        altitude: 900),
    TrackPoint(
        position: const LatLng(39.001, 32.001),
        timestamp: DateTime.utc(2026, 1, 1, 10, 1),
        altitude: 905),
  ];

  test('GeoJSON geçerli ve LineString içerir', () {
    final geo = TrackExporter.toGeoJson(track, points);
    final parsed = jsonDecode(geo) as Map<String, dynamic>;
    expect(parsed['type'], 'FeatureCollection');
    final feature = (parsed['features'] as List).first as Map<String, dynamic>;
    expect(feature['geometry']['type'], 'LineString');
    final coords = feature['geometry']['coordinates'] as List;
    expect(coords.length, 2);
    // [lon, lat, alt] sırası
    expect(coords.first[0], 32.0);
    expect(coords.first[1], 39.0);
    expect(coords.first[2], 900);
    expect(feature['properties']['name'], 'TEST İZ');
  });

  test('KML LineString ve coordinates içerir', () {
    final kml = TrackExporter.toKml(track, points);
    expect(kml.contains('<LineString>'), true);
    expect(kml.contains('<coordinates>'), true);
    expect(kml.contains('32.0,39.0,900'), true);
  });
}
