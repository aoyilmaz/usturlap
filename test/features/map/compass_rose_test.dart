import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/geo_math.dart';
import 'package:usturlap/features/map/engine/map_types.dart';
import 'package:usturlap/features/map/widgets/compass_rose.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const c = LatLng(39.9, 32.85);

  test('çember + 36 çentik + 4 yön harfi; kuzey çentiği kırmızı', () {
    final o = compassRoseOverlays(c, 200);
    expect(o.whereType<MapCircle>(), hasLength(1));
    final ticks = o.whereType<MapLine>().toList();
    expect(ticks, hasLength(36));
    expect(o.whereType<MapMarker>().map((m) => m.id), [
      'rose:N',
      'rose:E',
      'rose:S',
      'rose:W',
    ]);
    // İlk çentik kuzeyde, kırmızı; dış ucu çember üstünde.
    expect(ticks.first.color, Colors.red);
    expect(GeoMath.distance(c, ticks.first.points.last), closeTo(200, 0.5));
    expect(GeoMath.bearing(c, ticks.first.points.last), closeTo(0, 0.01));
    // Ana yön çentiği daha uzun.
    final cardinal = GeoMath.distance(c, ticks[9].points.first); // 90°
    final minor = GeoMath.distance(c, ticks[1].points.first); // 10°
    expect(cardinal, lessThan(minor));
  });

  test('yarıçap: bir zoom kademesi yakınlaşınca yarıya iner', () {
    final r15 = roseRadiusMeters(15, 39.9);
    expect(roseRadiusMeters(16, 39.9), closeTo(r15 / 2, 1e-6));
    // z15, 40° enlem (512 px karo): ~1.83 m/px → 110 px ≈ 201 m.
    expect(r15, closeTo(201, 3));
  });
}
