import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/nav_math.dart';
import 'package:kerteriz/domain/usecases/route_navigator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const d = Distance();

  group('NavMath', () {
    test('göreli kerteriz −180..180', () {
      expect(NavMath.relativeBearing(90, 0), 90);
      expect(NavMath.relativeBearing(10, 350), 20);
      expect(NavMath.relativeBearing(350, 10), -20);
      expect(NavMath.fmtTurn(35), 'sağa 35°');
      expect(NavMath.fmtTurn(-120), 'sola 120°');
      expect(NavMath.fmtTurn(5), 'düz');
    });

    test('ETA: hız varsa hızla, yoksa yürüyüş hızıyla', () {
      expect(NavMath.eta(1000, 2.0), const Duration(seconds: 500));
      // duruyor → 4 km/s ≈ 1.111 m/s → 900 sn
      expect(NavMath.eta(1000, 0.1)!.inSeconds, closeTo(900, 1));
      expect(NavMath.eta(1000, null, fallbackMps: null), isNull);
      expect(NavMath.fmtDuration(const Duration(minutes: 65)), '1 sa 05 dk');
      expect(NavMath.fmtDuration(const Duration(minutes: 37)), '37 dk');
    });

    test('sapma: doğunun kuzeyine giderken güneyde = sağ (+)', () {
      const a = LatLng(39.0, 32.0), b = LatLng(39.0, 32.1); // doğuya
      final south = d.offset(const LatLng(39.0, 32.05), 100, 180);
      final north = d.offset(const LatLng(39.0, 32.05), 100, 0);
      // Büyük daire enlem boyunca değil, hafif kuzeye bükülür → ~101.6 m.
      expect(NavMath.crossTrack(a, b, south), closeTo(100, 3));
      expect(NavMath.crossTrack(a, b, north), closeTo(-100, 3));
      // ayak boyunca ilerleme
      final legLen = d(a, b);
      expect(NavMath.alongTrack(a, b, south), closeTo(legLen / 2, 2));
      expect(NavMath.alongTrack(a, b, d.offset(a, 200, 270)), lessThan(0));
    });
  });

  group('RouteNavigator', () {
    // Kuzeye 3 ayak, her biri ~1 km.
    const p0 = LatLng(39.0, 32.0);
    final p1 = d.offset(p0, 1000, 0);
    final p2 = d.offset(p1, 1000, 0);
    final p3 = d.offset(p2, 1000, 0);
    List<LatLng> route() => [p0, p1, p2, p3];

    test('başlangıçtan uzakta: önce başlangıca yönlendirir', () {
      final nav = RouteNavigator(route());
      final r = nav.update(d.offset(p0, 500, 270));
      expect(r.toStart, isTrue);
      expect(r.distToNext, closeTo(500, 2));
      expect(r.bearingToNext, closeTo(90, 1));
      expect(r.remaining, closeTo(3500, 5));
      expect(r.legCount, 3);
    });

    test('noktaya varınca sıradaki ayağa geçer', () {
      final nav = RouteNavigator(route());
      expect(nav.update(p0).targetIndex, 1); // başlangıçta → 1. ayak
      final mid = d.offset(p0, 500, 0);
      final r = nav.update(mid);
      expect(r.targetIndex, 1);
      expect(r.distToNext, closeTo(500, 2));
      expect(r.remaining, closeTo(2500, 5));
      expect(r.offRoute, isFalse);
      expect(nav.update(d.offset(p1, 10, 0)).targetIndex, 2);
    });

    test('noktayı ıskalayıp geçerse yine ilerler', () {
      final nav = RouteNavigator(route());
      nav.update(p0);
      // p1'in 40 m doğusundan (yarıçap dışı) kuzeye geçti.
      final passed = d.offset(d.offset(p1, 40, 90), 60, 0);
      expect(nav.update(passed).targetIndex, 2);
    });

    test('rotadan sapma işaretlenir (sağ +)', () {
      final nav = RouteNavigator(route());
      nav.update(p0);
      final east = d.offset(d.offset(p0, 500, 0), 120, 90);
      final r = nav.update(east);
      expect(r.offRoute, isTrue);
      expect(r.crossTrack, closeTo(120, 2)); // kuzeye giderken doğu = sağ
    });

    test('son noktaya varınca biter', () {
      final nav = RouteNavigator(route());
      for (final p in route()) {
        nav.update(p);
      }
      final r = nav.update(p3);
      expect(r.finished, isTrue);
      expect(r.remaining, 0);
    });

    test('elle atla / geri al', () {
      final nav = RouteNavigator(route());
      nav.update(p0);
      nav.skip();
      expect(nav.targetIndex, 2);
      nav.back();
      expect(nav.targetIndex, 1);
    });
  });
}
