import 'package:latlong2/latlong.dart';

import '../../core/uuid.dart';
import '../../domain/models/map_graphic.dart';
import '../../domain/models/range_line.dart';
import '../../domain/models/range_ring.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/models/sensor_fov.dart';
import '../../domain/models/waypoint.dart';
import 'gpx_kml_importer.dart';

/// Pusula'nın dışa aktardığı "kerteriz" verisinden (KML ExtendedData,
/// GeoJSON özelliği; bkz. GeoExporter) nesneleri geri kurar. Dışarıdan
/// gelen veri: her alan tür ve aralık denetiminden geçer; bozuksa null
/// (çağıran düz geometriye döner).
class KerterizData {
  KerterizData._();

  static const key = 'kerteriz';

  /// Geçerli enlem / boylam ise nokta.
  static LatLng? latLng(double? lat, double? lon) {
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) {
      return null;
    }
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return LatLng(lat, lon);
  }

  static double? _num(Object? v) =>
      v is num && v.isFinite ? v.toDouble() : null;

  static LatLng? _ll(Object? v) =>
      v is List && v.length >= 2 ? latLng(_num(v[0]), _num(v[1])) : null;

  static String? _uid(Object? v) =>
      v is String && v.isNotEmpty && v.length <= 128 ? v : null;

  static int? _color(Object? v) =>
      v is int ? (v & 0xFFFFFFFF) | 0xFF000000 : null;

  /// Yeni (kimliksiz) çizim: içe aktarılan dış veriler için.
  static MapGraphic newGraphic({
    required String name,
    required GraphicType type,
    required List<LatLng> points,
    required int colorValue,
    double strokeWidth = MapGraphic.defaultStrokeWidth,
    String? uid,
  }) => MapGraphic(
    uid: uid ?? newUuidV4(),
    name: name,
    type: type,
    points: points,
    colorValue: colorValue,
    createdAt: DateTime.now(),
    strokeWidth: strokeWidth,
  );

  static MapGraphic? graphic(Map<String, dynamic> d, {required String name}) {
    final raw = d['points'];
    if (raw is! List) return null;
    final pts = [for (final p in raw) ?_ll(p)];
    final type = GraphicType.values.asNameMap()[d['type']];
    if (type == null || pts.length != raw.length) return null;
    final min = switch (type) {
      GraphicType.line || GraphicType.circle => 2,
      GraphicType.area => 3,
      GraphicType.rectangle => 4,
    };
    if (pts.length < min) return null;
    final h = _num(d['height']);
    return MapGraphic(
      uid: _uid(d['uid']) ?? newUuidV4(),
      name: name,
      type: type,
      points: pts,
      colorValue: _color(d['color']) ?? GpxKmlImporter.defaultAreaColor,
      createdAt: DateTime.now(),
      strokeWidth: (_num(d['strokeWidth']) ?? MapGraphic.defaultStrokeWidth)
          .clamp(1.0, 12.0),
      dashed: d['dashed'] == true,
      height: type == GraphicType.line || h == null ? null : h.clamp(1, 1000),
      geofence: type == GraphicType.line
          ? null
          : GeofenceTrigger.fromName(d['geofence'] as String?),
    );
  }

  static RangeLine? rangeLine(Map<String, dynamic> d, {required String name}) {
    final a = _ll(d['start']), b = _ll(d['end']);
    if (a == null || b == null) return null;
    return RangeLine(
      uid: _uid(d['uid']) ?? newUuidV4(),
      name: name,
      start: RbEnd(a),
      end: RbEnd(b),
      colorValue: _color(d['color']) ?? RangeLine.defaultColor,
      createdAt: DateTime.now(),
    );
  }

  static RangeRing? rangeRing(Map<String, dynamic> d, {required String name}) {
    final c = _ll(d['center']);
    final raw = d['radii'];
    if (c == null || raw is! List) return null;
    final radii = [
      for (final r in raw)
        if (_num(r) case final v? when v > 0 && v <= 1e7) v,
    ];
    if (radii.isEmpty) return null;
    return RangeRing(
      uid: _uid(d['uid']) ?? newUuidV4(),
      name: name,
      center: RbEnd(c),
      radii: radii,
      colorValue: _color(d['color']) ?? 0xFFFFFFFF,
      createdAt: DateTime.now(),
    );
  }

  static RoutePlan? route(Map<String, dynamic> d, {required String name}) {
    final raw = d['points'];
    if (raw is! List) return null;
    final pts = [for (final p in raw) ?_ll(p)];
    if (pts.length < 2 || pts.length != raw.length) return null;
    final names = d['pointNames'];
    return RoutePlan(
      uid: _uid(d['uid']) ?? newUuidV4(),
      name: name,
      points: pts,
      pointNames: names is List && names.length == pts.length
          ? [
              for (final n in names)
                n is String && n.trim().isNotEmpty && n.length <= 40 ? n : null,
            ]
          : const [],
      createdAt: DateTime.now(),
    );
  }

  static ImportedWaypoint waypoint(
    Map<String, dynamic> d, {
    required String name,
    required LatLng position,
    String? fallbackNote,
  }) {
    final fov = d['fov'];
    SensorFov? sensor;
    if (fov is Map) {
      final az = _num(fov['azimuth']), w = _num(fov['width']);
      final r = _num(fov['range']);
      if (az != null && w != null && r != null && w > 0 && r > 0) {
        sensor = SensorFov(azimuth: az % 360, width: w.clamp(1, 360), range: r);
      }
    }
    final photos = d['photos'];
    final note = d['note'];
    final cot = d['cot'];
    return ImportedWaypoint(
      name: name,
      position: position,
      note: note is String ? note : fallbackNote,
      uid: _uid(d['uid']),
      affiliation: Affiliation.fromName(d['affiliation'] as String?),
      echelon: Echelon.fromName(d['echelon'] as String?),
      role: SymbolRole.fromName(d['role'] as String?),
      cotType: cot is String && cot.length <= 64 ? cot : null,
      hae: _num(d['hae']),
      elevation: _num(d['elevation']),
      fov: sensor,
      photos: [
        if (photos is List)
          for (final p in photos)
            if (p is String) p,
      ],
    );
  }
}
