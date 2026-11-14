import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/models/route_plan.dart';
import 'package:usturlap/domain/usecases/route_navigator.dart';
import 'package:usturlap/features/routes/route_alerts.dart';
import 'package:latlong2/latlong.dart';

/// E8: rota takibi uyarıları.
void main() {
  final route = RoutePlan(
    uid: 'r',
    name: 'DEVRİYE',
    points: const [LatLng(0, 0), LatLng(0, 0.01), LatLng(0, 0.02)],
    pointNames: const [null, 'KÖPRÜ'],
    createdAt: DateTime(2026),
  );

  RouteProgress p(
    int target, {
    bool off = false,
    bool finished = false,
    double xt = 0,
  }) => RouteProgress(
    targetIndex: target,
    pointCount: 3,
    distToNext: 1110,
    bearingToNext: 90,
    remaining: 2000,
    crossTrack: xt,
    offRoute: off,
    finished: finished,
  );

  String brg(double b) => '${b.round().toString().padLeft(3, '0')}°';

  test('ilk değer ve değişiklik yoksa uyarı yok', () {
    expect(routeAlert(null, p(1), route, bearing: brg), isNull);
    expect(routeAlert(p(1), p(1), route, bearing: brg), isNull);
  });

  test('rotaya giriş ve nokta geçişi: sıradaki nokta adıyla', () {
    final enter = routeAlert(p(0), p(1), route, bearing: brg)!;
    expect(enter.text, 'Rotaya girildi · sıradaki KÖPRÜ: 090° · 1.11 km');
    expect(enter.strong, isFalse);
    // Sesli: kısaltma ve simge yok.
    expect(enter.speech, 'Rotaya girildi. Sıradaki KÖPRÜ, 1,1 kilometre.');
    final pass = routeAlert(p(1), p(2), route, bearing: brg)!;
    expect(pass.text, startsWith('KÖPRÜ geçildi · sıradaki KN2'));
  });

  test('bitiş ve sapma güçlü uyarı', () {
    final done = routeAlert(p(2), p(3, finished: true), route, bearing: brg)!;
    expect(done.text, 'Rota bitti: KN2 — vardınız');
    expect(done.strong, isTrue);
    expect(done.speech, 'Rota bitti. KN2. Vardınız.');
    final off = routeAlert(
      p(1),
      p(1, off: true, xt: -62),
      route,
      bearing: brg,
    )!;
    expect(off.text, 'Rotadan saptınız: 62 m solunda');
    expect(off.speech, 'Rotadan saptınız. Rotanın 62 metre solundasınız.');
    expect(off.strong, isTrue);
    // Sapma sürerken tekrar uyarmaz.
    expect(
      routeAlert(p(1, off: true), p(1, off: true), route, bearing: brg),
      isNull,
    );
  });
}
