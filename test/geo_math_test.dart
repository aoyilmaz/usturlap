import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:pusula/core/geo_math.dart';

void main() {
  group('pathLength', () {
    test('ekvatorda 0.01° boylam ~1113 m', () {
      final d = GeoMath.pathLength(
          [const LatLng(0, 0), const LatLng(0, 0.01)]);
      expect(d, closeTo(1113, 40));
    });

    test('tek nokta 0', () {
      expect(GeoMath.pathLength([const LatLng(0, 0)]), 0);
    });
  });

  group('polygonArea', () {
    test('ekvatorda ~0.01° kare ~1.24 km²', () {
      final pts = [
        const LatLng(0, 0),
        const LatLng(0, 0.01),
        const LatLng(0.01, 0.01),
        const LatLng(0.01, 0),
      ];
      final area = GeoMath.polygonArea(pts);
      expect(area, greaterThan(1.0e6));
      expect(area, lessThan(1.4e6));
    });

    test('3\'ten az nokta 0', () {
      expect(GeoMath.polygonArea([const LatLng(0, 0), const LatLng(0, 1)]), 0);
    });
  });

  group('sectorPolygon', () {
    test('ilk nokta merkez, yay noktaları üretir', () {
      const center = LatLng(39.0, 32.0);
      final poly = GeoMath.sectorPolygon(center, 1000, 0, 90);
      expect(poly.first, center);
      expect(poly.length, greaterThan(10));
    });
  });

  group('biçimlendirme', () {
    test('mesafe m/km', () {
      expect(GeoMath.fmtDistance(500), '500 m');
      expect(GeoMath.fmtDistance(1500), '1.50 km');
    });
    test('alan m²/ha', () {
      expect(GeoMath.fmtArea(5000), '5000 m²');
      expect(GeoMath.fmtArea(50000), '5.00 ha');
    });
  });
}
