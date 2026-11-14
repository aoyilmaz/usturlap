import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/geo_math.dart';
import 'package:usturlap/domain/usecases/route_profile.dart';
import 'package:latlong2/latlong.dart';

/// E8: rota boyunca yükseklik profili.
void main() {
  const a = LatLng(37.0, 37.0);
  final b = GeoMath.destination(a, 1000, 0);
  final c = GeoMath.destination(b, 500, 90);

  test('örnekleme: köşeler dahil, aralıklı, artan mesafe', () {
    final s = RouteProfile.sampleAlong([a, b, c], 200);
    // 0, 200…800, 1000 (b), 1200, 1400, 1500 (c)
    expect(s.first.$1, 0);
    expect(s.last.$1, closeTo(1500, 1));
    expect(s.map((e) => e.$2), containsAll([a, b, c]));
    expect(s, hasLength(9));
    for (var i = 1; i < s.length; i++) {
      expect(s[i].$1, greaterThan(s[i - 1].$1));
    }
  });

  test('çıkış / iniş, en yüksek / en alçak; veri boşluğu atlanır', () async {
    // Kuzeye gidildikçe 0,1 m/m tırman, sonra doğuda sabit; bir boşluk.
    final p = await RouteProfile.build([a, b, c], (pt) async {
      final north = GeoMath.distance(a, LatLng(pt.latitude, a.longitude));
      if (north > 390 && north < 410) return null; // veri yok
      return 800 + (north.clamp(0, 1000) * 0.1);
    }, step: 100);
    expect(p.hasData, isTrue);
    expect(p.minElevation, closeTo(800, 0.5));
    expect(p.maxElevation, closeTo(900, 0.5));
    expect(p.ascent, closeTo(100, 1));
    expect(p.descent, closeTo(0, 1));
    expect(p.pointDistances, hasLength(3));
    expect(p.pointDistances[1], closeTo(1000, 1));
    expect(p.samples.where((s) => s.elevation == null), isNotEmpty);
  });

  test('eğimler: boşluk üstünden hesaplanmaz; en dik çıkış / iniş', () async {
    // 0–500 m %10 çık, 500–1000 m %30 in; 600–700 m arası veri yok.
    final p = await RouteProfile.build([a, b], (pt) async {
      final d = GeoMath.distance(a, pt);
      if (d > 590 && d < 710) return null;
      return d <= 500 ? 100 + d * 0.1 : 150 - (d - 500) * 0.3;
    }, step: 100);
    expect(p.maxClimb, closeTo(10, 0.5));
    expect(p.maxDescent, closeTo(-30, 0.5));
    // 500 → 600 tamam; 600 → 700 boşluk (çift yok).
    expect(p.grades.where((g) => g.$1 > 590 && g.$1 < 710), isEmpty);
  });

  test('veri yoksa hasData false', () async {
    final p = await RouteProfile.build([a, b], (_) async => null);
    expect(p.hasData, isFalse);
    expect(p.minElevation, isNull);
    expect(p.ascent, 0);
  });

  test('örnek aralığı uzunluğa göre, 20–500 m', () {
    expect(RouteProfile.defaultStep(1000), 20);
    expect(RouteProfile.defaultStep(40000), 200);
    expect(RouteProfile.defaultStep(500000), 500);
  });
}
