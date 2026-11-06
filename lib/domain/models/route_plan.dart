import 'package:latlong2/latlong.dart';

import '../../core/nav_math.dart';
import 'cot_type.dart';
import 'map_item.dart';

/// Kaydedilmiş bir rota: sıralı kontrol noktaları.
class RoutePlan implements MapItem {
  const RoutePlan({
    this.id,
    required this.uid,
    required this.name,
    required this.points,
    required this.createdAt,
  });

  final int? id;

  @override
  final String uid;

  final String name;
  final List<LatLng> points;

  @override
  final DateTime createdAt;

  @override
  String get cotType => CotType.route;

  @override
  String get title => name;

  /// Toplam uzunluk (m).
  double get length => routeLength(points);
}

/// Sıralı noktaların toplam uzunluğu (m).
double routeLength(List<LatLng> pts) {
  var sum = 0.0;
  for (var i = 0; i < pts.length - 1; i++) {
    sum += NavMath.distance(pts[i], pts[i + 1]);
  }
  return sum;
}
