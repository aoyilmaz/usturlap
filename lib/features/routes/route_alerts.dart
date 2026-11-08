import '../../core/geo_math.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/usecases/route_navigator.dart';

/// Rota takibinde uyarı gerektiren değişiklik (E8; ATAK'taki sesli
/// bildirimlerin yerine titreşim + ekran uyarısı): nokta geçildi, rota
/// bitti, rotadan sapıldı. [strong]: güçlü titreşim (bitti / saptı).
/// [bearing]: kerterizi kullanıcının kuzey/birimiyle yazar.
({String text, bool strong})? routeAlert(
  RouteProgress? prev,
  RouteProgress next,
  RoutePlan route, {
  required String Function(double trueBearing) bearing,
}) {
  if (prev == null) return null;
  if (!prev.finished && next.finished) {
    return (
      text: 'Rota bitti: ${route.nameOf(route.points.length - 1)} — vardınız',
      strong: true,
    );
  }
  if (next.finished) return null;
  if (next.targetIndex > prev.targetIndex) {
    final passed = next.targetIndex - 1;
    final what = passed == 0 && prev.toStart
        ? 'Rotaya girildi'
        : '${route.nameOf(passed)} geçildi';
    return (
      text:
          '$what · sıradaki ${route.nameOf(next.targetIndex)}: '
          '${bearing(next.bearingToNext)} · '
          '${GeoMath.fmtDistance(next.distToNext)}',
      strong: false,
    );
  }
  if (!prev.offRoute && next.offRoute) {
    final side = next.crossTrack > 0 ? 'sağında' : 'solunda';
    return (
      text: 'Rotadan saptınız: ${next.crossTrack.abs().round()} m $side',
      strong: true,
    );
  }
  return null;
}
