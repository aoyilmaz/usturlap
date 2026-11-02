import 'dart:convert';

import 'package:flutter/painting.dart' show Color;
import 'package:latlong2/latlong.dart';

import 'map_types.dart';

/// Overlay listesini Mapbox GeoJSON kaynaklarına çevirir (saf Dart, test edilir).
///
/// Üç kaynak, sabit katman sırasıyla çizilir: alanlar (+daireler) < çizgiler <
/// işaretçiler. Aynı kaynak içinde liste sırası korunur (`order`).
class MapboxOverlayData {
  MapboxOverlayData._(this.areas, this.lines, this.markers, this.markerById);

  /// FeatureCollection JSON metinleri.
  final String areas;
  final String lines;
  final String markers;

  /// İşaretçi id → işaretçi (dokunma ve resim üretimi için).
  final Map<String, MapMarker> markerById;

  static const _emptyFc = '{"type":"FeatureCollection","features":[]}';

  factory MapboxOverlayData.from(List<MapOverlay> overlays) {
    final areas = <Map<String, Object?>>[];
    final lines = <Map<String, Object?>>[];
    final markers = <Map<String, Object?>>[];
    final byId = <String, MapMarker>{};

    for (var i = 0; i < overlays.length; i++) {
      switch (overlays[i]) {
        case MapArea a:
          if (a.points.length < 3) break;
          areas.add(_feature(
            {'type': 'Polygon', 'coordinates': [_ring(a.points)]},
            {
              'fill': mapboxColor(a.fillColor),
              'stroke': mapboxColor(a.strokeColor),
              'width': a.strokeWidth,
              'order': i,
            },
          ));
        case MapCircle c:
          areas.add(_feature(
            {
              'type': 'Polygon',
              'coordinates': [_ring(circlePolygon(c.center, c.radiusMeters))],
            },
            {
              'fill': mapboxColor(c.fillColor),
              'stroke': mapboxColor(c.strokeColor),
              'width': c.strokeWidth,
              'order': i,
            },
          ));
        case MapLine l:
          if (l.points.length < 2) break;
          lines.add(_feature(
            {'type': 'LineString', 'coordinates': _coords(l.points)},
            {'color': mapboxColor(l.color), 'width': l.width, 'order': i},
          ));
        case MapMarker m:
          byId[m.id] = m;
          markers.add(_feature(
            {
              'type': 'Point',
              'coordinates': [m.point.longitude, m.point.latitude],
            },
            {
              'id': m.id,
              'icon': m.imageKey,
              'rotate': m.rotationDeg ?? 0,
              'order': i,
            },
          ));
      }
    }
    String fc(List<Map<String, Object?>> f) => f.isEmpty
        ? _emptyFc
        : jsonEncode({'type': 'FeatureCollection', 'features': f});
    return MapboxOverlayData._(fc(areas), fc(lines), fc(markers), byId);
  }

  static Map<String, Object?> _feature(
          Map<String, Object?> geometry, Map<String, Object?> props) =>
      {'type': 'Feature', 'geometry': geometry, 'properties': props};

  static List<List<double>> _coords(List<LatLng> pts) =>
      [for (final p in pts) [p.longitude, p.latitude]];

  /// GeoJSON halkası kapalı olmalı (ilk nokta = son nokta).
  static List<List<double>> _ring(List<LatLng> pts) {
    final c = _coords(pts);
    if (c.first[0] != c.last[0] || c.first[1] != c.last[1]) c.add(c.first);
    return c;
  }
}

/// Flutter rengi → Mapbox stil rengi ("rgba(r, g, b, a)").
String mapboxColor(Color c) {
  int ch(double v) => (v * 255).round().clamp(0, 255);
  final a = double.parse(c.a.toStringAsFixed(3));
  return 'rgba(${ch(c.r)}, ${ch(c.g)}, ${ch(c.b)}, $a)';
}

/// Metre yarıçaplı daireyi jeodezik poligona çevirir ([segments] köşe).
List<LatLng> circlePolygon(LatLng center, double radiusMeters,
    {int segments = 72}) {
  const d = Distance();
  return [
    for (var i = 0; i < segments; i++)
      d.offset(center, radiusMeters, i * 360.0 / segments),
  ];
}
