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
    this.pointNames = const [],
  });

  final int? id;

  @override
  final String uid;

  final String name;
  final List<LatLng> points;

  /// Noktaların kullanıcı verdiği adları ([points] ile aynı sırada; eksik
  /// ya da boşsa varsayılan ad, bkz. [nameOf]).
  final List<String?> pointNames;

  @override
  final DateTime createdAt;

  @override
  String get cotType => CotType.route;

  @override
  String get title => name;

  /// Toplam uzunluk (m).
  double get length => routeLength(points);

  /// Kullanıcının verdiği ad (yoksa null).
  String? customNameOf(int i) {
    final n = i < pointNames.length ? pointNames[i]?.trim() : null;
    return n == null || n.isEmpty ? null : n;
  }

  /// [i]. noktanın adı: verilmişse o, yoksa "BAŞLANGIÇ", "KN1", "KN2"…
  /// (kontrol noktası).
  String nameOf(int i) => customNameOf(i) ?? defaultPointName(i);

  static String defaultPointName(int i) => i == 0 ? 'BAŞLANGIÇ' : 'KN$i';

  /// Ters çevrilmiş rota (dönüş yolu): noktalar ve adları ters sırada.
  RoutePlan reversed() => RoutePlan(
    id: id,
    uid: uid,
    name: name,
    points: points.reversed.toList(),
    pointNames: [
      for (var i = points.length - 1; i >= 0; i--) customNameOf(i),
    ],
    createdAt: createdAt,
  );
}

/// Sıralı noktaların toplam uzunluğu (m).
double routeLength(List<LatLng> pts) {
  var sum = 0.0;
  for (var i = 0; i < pts.length - 1; i++) {
    sum += NavMath.distance(pts[i], pts[i + 1]);
  }
  return sum;
}
