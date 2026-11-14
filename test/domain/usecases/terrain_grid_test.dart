import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/geo_math.dart';
import 'package:usturlap/domain/usecases/terrain_grid.dart';
import 'package:latlong2/latlong.dart';

/// F4 / F5: arazi ızgarası, eş yükselti eğrileri, eğim / yükseklik katmanı.
void main() {
  const c = LatLng(37.0, 37.0);

  /// Kuzeye doğru metre başına [grade] yükselen düzlem (taban 1000 m).
  double? plane(double lat, double lon, {double grade = 0.1}) {
    final north = (lat - c.latitude) * 111195;
    return 1000 + north * grade;
  }

  test('örnekleme: kare ızgara, hücre ≥ 30 m, sınırlar', () {
    final g = TerrainGrid.sample(c, 1500, plane);
    expect(g.rows, 100);
    expect(g.cellX, closeTo(30, 1e-9));
    expect(g.north, greaterThan(c.latitude));
    final r = g.range!;
    expect(r.$1, closeTo(850, 3));
    expect(r.$2, closeTo(1150, 3));
    // Büyük alan 300 hücreye sığar.
    expect(TerrainGrid.sample(c, 10000, plane).rows, TerrainGrid.maxCells);
  });

  test('eğik düzlem: eğriler doğu-batı uzanır, her seviye tek çizgi', () {
    final g = TerrainGrid.sample(c, 1000, plane);
    final lines = g.contours(50);
    final levels = lines.map((l) => l.level).toSet();
    expect(levels, containsAll(<double>[950, 1000, 1050]));
    final at1000 = lines.where((l) => l.level == 1000).toList();
    expect(at1000, hasLength(1));
    final pts = at1000.single.points;
    // Enlem neredeyse sabit (seviye çizgisi), boylamda alanı boydan boya.
    for (final p in pts) {
      expect(p.latitude, closeTo(c.latitude, 0.0003));
    }
    final span = GeoMath.distance(pts.first, pts.last);
    expect(span, greaterThan(1800));
  });

  test('tepe: kapalı halka, yarıçap tutarlı', () {
    final g = TerrainGrid.sample(c, 1000, (lat, lon) {
      return 1200 - GeoMath.distance(c, LatLng(lat, lon)) * 0.2;
    });
    final ring = g.contours(100).where((l) => l.level == 1100).single;
    // 1200 − 0,2·d = 1100 → d = 500 m
    for (final p in ring.points) {
      expect(GeoMath.distance(c, p), closeTo(500, 25));
    }
    expect(GeoMath.distance(ring.points.first, ring.points.last), lessThan(40));
  });

  test('veri boşluğunda eğri yok; hepsi boşsa hasData false', () {
    final g = TerrainGrid.sample(
      c,
      600,
      (lat, lon) => lon > c.longitude ? null : plane(lat, lon),
    );
    for (final l in g.contours(20)) {
      for (final p in l.points) {
        expect(p.longitude, lessThanOrEqualTo(c.longitude + 0.0005));
      }
    }
    expect(TerrainGrid.sample(c, 300, (lat, lon) => null).hasData, isFalse);
  });

  test('eğim: %10 düzlem ≈ 5,7°, düzlük 0; renk eşikleri', () {
    final g = TerrainGrid.sample(c, 600, plane);
    final s = g.slopes();
    final mid = (g.rows ~/ 2) * g.cols + g.cols ~/ 2;
    expect(s[mid], closeTo(5.71, 0.05));
    expect(s[0].isNaN, isTrue); // kenar
    final flat = TerrainGrid.sample(c, 300, (lat, lon) => 50).slopes();
    expect(flat[(5) * 20 + 5], closeTo(0, 1e-9));
    expect(TerrainGrid.slopeColor(5), (60, 200, 70));
    expect(TerrainGrid.slopeColor(25), (245, 140, 30));
    expect(TerrainGrid.slopeColor(40), (220, 40, 40));
  });

  test('renkli katmanlar: hücre başına 4 bayt, verisiz saydam', () {
    final g = TerrainGrid.sample(c, 600, plane);
    final slope = g.slopeRgba();
    expect(slope.length, g.rows * g.cols * 4);
    expect(slope[3], 0); // köşe (kenar eğimi yok)
    final elev = g.elevationRgba();
    expect(elev[3], greaterThan(0));
    expect(TerrainGrid.elevationColor(0), (40, 140, 60));
    expect(TerrainGrid.elevationColor(1), (245, 245, 245));
  });
}
