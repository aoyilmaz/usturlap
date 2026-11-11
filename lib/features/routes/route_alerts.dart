import '../../core/geo_math.dart';
import '../../domain/ports/alert_output.dart';
import '../../domain/models/route_plan.dart';
import '../../domain/usecases/route_navigator.dart';

/// Rota takibinde uyarı gerektiren değişiklik (E8): nokta geçildi, rota
/// bitti, rotadan sapıldı. [text] ekranda, [speech] sesli okunur (kısaltma
/// ve simge yok). [strong]: güçlü titreşim (bitti / saptı).
/// [bearing]: kerterizi kullanıcının kuzey/birimiyle yazar.
({String text, bool strong, String speech})? routeAlert(
  RouteProgress? prev,
  RouteProgress next,
  RoutePlan route, {
  required String Function(double trueBearing) bearing,
}) {
  if (prev == null) return null;
  if (!prev.finished && next.finished) {
    final last = route.nameOf(route.points.length - 1);
    return (
      text: 'Rota bitti: $last — vardınız',
      strong: true,
      speech: 'Rota bitti. ${spokenName(last)}. Vardınız.',
    );
  }
  if (next.finished) return null;
  if (next.targetIndex > prev.targetIndex) {
    final passed = next.targetIndex - 1;
    final entered = passed == 0 && prev.toStart;
    final passedName = route.nameOf(passed);
    final nextName = route.nameOf(next.targetIndex);
    final what = entered ? 'Rotaya girildi' : '$passedName geçildi';
    final spokenWhat = entered
        ? 'Rotaya girildi'
        : '${spokenName(passedName)} geçildi';
    return (
      text:
          '$what · sıradaki $nextName: '
          '${bearing(next.bearingToNext)} · '
          '${GeoMath.fmtDistance(next.distToNext)}',
      strong: false,
      speech:
          '$spokenWhat. Sıradaki ${spokenName(nextName)}, '
          '${spokenDistance(next.distToNext)}.',
    );
  }
  if (!prev.offRoute && next.offRoute) {
    final side = next.crossTrack > 0 ? 'sağında' : 'solunda';
    final m = next.crossTrack.abs().round();
    return (
      text: 'Rotadan saptınız: $m m $side',
      strong: true,
      speech: 'Rotadan saptınız. Rotanın $m metre ${side}sınız.',
    );
  }
  return null;
}
