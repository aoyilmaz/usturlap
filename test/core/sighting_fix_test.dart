import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/geo_math.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('bilinen noktayı 090° yönde 1 km uzakta görüyorsam batısındayım', () {
    const tower = LatLng(39.9, 32.85);
    final me = GeoMath.positionFromSighting(tower, 90, 1000);
    expect(GeoMath.distance(me, tower), closeTo(1000, 0.5));
    expect(GeoMath.bearing(me, tower), closeTo(90, 0.1));
    expect(me.longitude, lessThan(tower.longitude));
  });
}
