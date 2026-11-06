import 'package:latlong2/latlong.dart';

import '../../core/nav_math.dart';

/// Rota takibinin anlık durumu.
class RouteProgress {
  const RouteProgress({
    required this.targetIndex,
    required this.pointCount,
    required this.distToNext,
    required this.bearingToNext,
    required this.remaining,
    required this.crossTrack,
    required this.offRoute,
    required this.finished,
  });

  /// Gidilen nokta (0 = başlangıca gidiliyor, 1.. = ayak sonu).
  final int targetIndex;
  final int pointCount;

  /// Toplam ayak sayısı (nokta sayısı − 1).
  int get legCount => pointCount - 1;

  /// Hâlâ başlangıç noktasına mı gidiliyor (rotaya henüz girilmedi).
  bool get toStart => targetIndex == 0;

  /// Sıradaki noktaya mesafe (m) ve kerteriz (0..360).
  final double distToNext;
  final double bearingToNext;

  /// Rotanın sonuna kalan toplam mesafe (m).
  final double remaining;

  /// Etkin ayağa dik sapma (m): + sağ, − sol. Başlangıca gidilirken 0.
  final double crossTrack;
  final bool offRoute;
  final bool finished;
}

/// Bir rotayı adım adım takip eder (durum tutar: hangi noktaya gidiliyor).
///
/// - Sıradaki noktanın [arriveRadius] içine girilince bir sonrakine geçer.
/// - Nokta yarıçapa girilmeden **geçilirse** (ayak boyunca ilerleme ayak
///   uzunluğunu aştıysa) de geçer — "noktayı ıskaladım" durumu.
/// - Etkin ayaktan [offRouteThreshold]'dan fazla sapınca [RouteProgress.offRoute].
class RouteNavigator {
  RouteNavigator(
    this.points, {
    this.arriveRadius = 30,
    this.offRouteThreshold = 50,
  }) : assert(points.length >= 2, 'rota en az 2 nokta');

  final List<LatLng> points;
  final double arriveRadius;
  final double offRouteThreshold;

  int _target = 0;
  int get targetIndex => _target;

  RouteProgress update(LatLng pos) {
    while (_target < points.length) {
      final next = points[_target];
      if (NavMath.distance(pos, next) <= arriveRadius) {
        _target++;
        continue;
      }
      if (_target > 0) {
        final prev = points[_target - 1];
        final legLen = NavMath.distance(prev, next);
        final along = NavMath.alongTrack(prev, next, pos);
        final xt = NavMath.crossTrack(prev, next, pos).abs();
        // Noktayı yanından geçti (rotaya yakınken ayak sonunu aştı).
        if (along > legLen && xt <= offRouteThreshold * 2) {
          _target++;
          continue;
        }
      }
      break;
    }

    if (_target >= points.length) {
      return RouteProgress(
        targetIndex: points.length,
        pointCount: points.length,
        distToNext: 0,
        bearingToNext: 0,
        remaining: 0,
        crossTrack: 0,
        offRoute: false,
        finished: true,
      );
    }

    final next = points[_target];
    final distToNext = NavMath.distance(pos, next);
    var remaining = distToNext;
    for (var i = _target; i < points.length - 1; i++) {
      remaining += NavMath.distance(points[i], points[i + 1]);
    }
    final xt =
        _target == 0 ? 0.0 : NavMath.crossTrack(points[_target - 1], next, pos);
    return RouteProgress(
      targetIndex: _target,
      pointCount: points.length,
      distToNext: distToNext,
      bearingToNext: NavMath.bearing(pos, next),
      remaining: remaining,
      crossTrack: xt,
      offRoute: xt.abs() > offRouteThreshold,
      finished: false,
    );
  }

  /// Elle sonraki/önceki noktaya geç (ör. kullanıcı bir noktayı atlamak ister).
  void skip() {
    if (_target < points.length) _target++;
  }

  void back() {
    if (_target > 0) _target--;
  }
}
