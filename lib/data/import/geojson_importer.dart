import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../../domain/models/map_graphic.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/range_ring.dart';
import '../../domain/models/route_plan.dart';
import 'gpx_kml_importer.dart';
import 'kerteriz_data.dart';

/// GeoJSON (RFC 7946) okuyucu: Point → nokta, LineString → iz, Polygon →
/// alan çizimi (dış halka); Multi* ve GeometryCollection açılır. Renk
/// "simplestyle" (stroke, stroke-width, fill) özelliklerinden; Pusula'dan
/// çıkmışsa "kerteriz" özelliğiyle ayrıntısı geri kurulur. Saf Dart.
class GeoJsonImporter {
  GeoJsonImporter._();

  /// Çok büyük dosyalarda telefon donmasın.
  static const maxFeatures = 20000;

  static ImportResult parse(String content) {
    final Object? root;
    try {
      root = jsonDecode(content);
    } on FormatException catch (e) {
      throw FormatException('GeoJSON okunamadı: ${e.message}');
    }
    if (root is! Map<String, dynamic>) {
      throw const FormatException('GeoJSON bekleniyor.');
    }
    final out = _Collector();
    switch (root['type']) {
      case 'FeatureCollection':
        final features = root['features'];
        if (features is! List) {
          throw const FormatException('GeoJSON: features listesi yok.');
        }
        if (features.length > maxFeatures) {
          throw const FormatException(
            'Dosyada çok fazla nesne var (en çok $maxFeatures).',
          );
        }
        for (final f in features) {
          if (f is Map<String, dynamic>) out.feature(f);
        }
      case 'Feature':
        out.feature(root);
      case String _:
        out.geometry(root, const {});
      default:
        throw const FormatException('GeoJSON bekleniyor.');
    }
    return out.result();
  }
}

class _Collector {
  final waypoints = <ImportedWaypoint>[];
  final tracks = <ImportedTrack>[];
  final graphics = <MapGraphic>[];
  final rangeLines = <RangeLine>[];
  final rangeRings = <RangeRing>[];
  final routes = <RoutePlan>[];

  ImportResult result() => ImportResult(
    waypoints,
    tracks,
    graphics: graphics,
    rangeLines: rangeLines,
    rangeRings: rangeRings,
    routes: routes,
  );

  void feature(Map<String, dynamic> f) {
    final props = f['properties'];
    final p = props is Map<String, dynamic> ? props : const <String, dynamic>{};
    final g = f['geometry'];
    if (g is Map<String, dynamic>) geometry(g, p);
  }

  String _name(Map<String, dynamic> p, String fallback) {
    for (final k in const ['name', 'title', 'Name', 'NAME', 'label']) {
      final v = p[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is num) return '$v';
    }
    return fallback;
  }

  String? _note(Map<String, dynamic> p) {
    for (final k in const ['description', 'desc', 'note', 'comment']) {
      final v = p[k];
      if (v is String && v.trim().isNotEmpty) {
        return GpxKmlImporter.htmlToNote(v);
      }
    }
    return null;
  }

  /// simplestyle rengi ("#rrggbb" ya da "#rgb") → opak ARGB.
  static int? _hex(Object? v) {
    if (v is! String) return null;
    var s = v.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
    if (s.length != 6) return null;
    final n = int.tryParse(s, radix: 16);
    return n == null ? null : 0xFF000000 | n;
  }

  static LatLng? _pos(Object? c) => c is List && c.length >= 2
      ? KerterizData.latLng(
          (c[1] is num) ? (c[1] as num).toDouble() : null,
          (c[0] is num) ? (c[0] as num).toDouble() : null,
        )
      : null;

  static List<LatLng> _line(Object? c) =>
      c is List ? [for (final p in c) ?_pos(p)] : const [];

  void geometry(Map<String, dynamic> g, Map<String, dynamic> p) {
    final data = p[KerterizData.key];
    final k = data is Map<String, dynamic> ? data : null;
    final c = g['coordinates'];
    switch (k?['kind']) {
      case 'graphic':
        final gr = KerterizData.graphic(k!, name: _name(p, 'ÇİZİM'));
        if (gr != null) return graphics.add(gr);
      case 'rangeLine':
        final l = KerterizData.rangeLine(k!, name: _name(p, 'R&B'));
        if (l != null) return rangeLines.add(l);
      case 'rangeRing':
        final r = KerterizData.rangeRing(k!, name: _name(p, 'HALKA'));
        if (r != null) return rangeRings.add(r);
      case 'route':
        final r = KerterizData.route(k!, name: _name(p, 'ROTA'));
        if (r != null) return routes.add(r);
    }
    switch (g['type']) {
      case 'Point':
        final pos = _pos(c);
        if (pos == null) return;
        waypoints.add(
          k?['kind'] == 'waypoint'
              ? KerterizData.waypoint(
                  k!,
                  name: _name(p, 'NOKTA'),
                  position: pos,
                  fallbackNote: _note(p),
                )
              : ImportedWaypoint(
                  name: _name(p, 'NOKTA'),
                  position: pos,
                  note: _note(p),
                  elevation: c is List && c.length > 2 && c[2] is num
                      ? (c[2] as num).toDouble()
                      : null,
                ),
        );
      case 'MultiPoint':
        if (c is! List) return;
        for (final pt in c) {
          final pos = _pos(pt);
          if (pos != null) {
            waypoints.add(
              ImportedWaypoint(
                name: _name(p, 'NOKTA'),
                position: pos,
                note: _note(p),
              ),
            );
          }
        }
      case 'LineString':
        _track(_line(c), p, k);
      case 'MultiLineString':
        if (c is! List) return;
        for (final l in c) {
          _track(_line(l), p, null);
        }
      case 'Polygon':
        _area(c, p);
      case 'MultiPolygon':
        if (c is! List) return;
        for (final poly in c) {
          _area(poly, p);
        }
      case 'GeometryCollection':
        final gs = g['geometries'];
        if (gs is! List) return;
        for (final sub in gs) {
          if (sub is Map<String, dynamic>) geometry(sub, p);
        }
    }
  }

  void _track(
    List<LatLng> pts,
    Map<String, dynamic> p,
    Map<String, dynamic>? k,
  ) {
    if (pts.length < 2) return;
    final uid = k?['kind'] == 'track' ? k!['uid'] : null;
    tracks.add(
      ImportedTrack(
        name: _name(p, 'İZ'),
        points: pts,
        uid: uid is String ? uid : null,
      ),
    );
  }

  void _area(Object? rings, Map<String, dynamic> p) {
    if (rings is! List || rings.isEmpty) return;
    var pts = _line(rings.first);
    if (pts.length >= 2 && pts.first == pts.last) {
      pts = pts.sublist(0, pts.length - 1);
    }
    if (pts.length < 3) return;
    final w = p['stroke-width'];
    graphics.add(
      KerterizData.newGraphic(
        name: _name(p, 'ALAN'),
        type: GraphicType.area,
        points: pts,
        colorValue:
            _hex(p['stroke']) ??
            _hex(p['fill']) ??
            GpxKmlImporter.defaultAreaColor,
        strokeWidth: w is num
            ? w.toDouble().clamp(1.0, 12.0)
            : MapGraphic.defaultStrokeWidth,
      ),
    );
  }
}
