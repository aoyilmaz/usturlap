import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/geo_math.dart';
import 'package:kerteriz/domain/usecases/viewshed.dart';
import 'package:latlong2/latlong.dart';

/// F3: görüş alanı.
void main() {
  const me = LatLng(37.0, 37.0);

  int cellAt(ViewshedGrid g, LatLng p) {
    final row = ((g.north - p.latitude) / (g.north - g.south) * g.size).floor();
    final col = ((p.longitude - g.west) / (g.east - g.west) * g.size).floor();
    return g.cells[row * g.size + col];
  }

  test('düz arazi: yarıçap içinde her yer görünür, dışı verisiz', () {
    final g = Viewshed.compute(
      const ViewshedParams(observer: me, radius: 1000),
      (lat, lon) => 100,
    )!;
    expect(g.observerGround, 100);
    for (final brg in <double>[0, 45, 90, 135, 180, 225, 270, 315]) {
      for (final d in <double>[100, 500, 950]) {
        expect(
          cellAt(g, GeoMath.destination(me, d, brg)),
          ViewshedCell.visible,
          reason: '$brg° $d m',
        );
      }
    }
    // Köşe (yarıçap dışı) verisiz → saydam.
    expect(g.cells.first, ViewshedCell.noData);
    expect(g.visibleFraction, 1);
    // π·1²  ≈ 3,14 km²
    expect(g.visibleKm2, closeTo(3.14, 0.15));
  });

  test('sırtın arkası görünmez, önü ve sırtın kendisi görünür', () {
    // 400–450 m doğuda 60 m yüksek sırt (kuzey-güney uzanır).
    double? terrain(double lat, double lon) {
      final east =
          GeoMath.distance(me, LatLng(me.latitude, lon)) *
          (lon >= me.longitude ? 1 : -1);
      return east >= 400 && east <= 450 ? 160 : 100;
    }

    final g = Viewshed.compute(
      const ViewshedParams(observer: me, radius: 1500),
      terrain,
    )!;
    expect(cellAt(g, GeoMath.destination(me, 300, 90)), ViewshedCell.visible);
    expect(cellAt(g, GeoMath.destination(me, 425, 90)), ViewshedCell.visible);
    expect(cellAt(g, GeoMath.destination(me, 800, 90)), ViewshedCell.hidden);
    expect(cellAt(g, GeoMath.destination(me, 1400, 90)), ViewshedCell.hidden);
    // Batı açık.
    expect(cellAt(g, GeoMath.destination(me, 800, 270)), ViewshedCell.visible);
    expect(g.visibleFraction, inExclusiveRange(0.5, 1));

    // Gözlemci 100 m'lik kuleye çıkınca sırtın arkasını görür.
    final tower = Viewshed.compute(
      const ViewshedParams(observer: me, radius: 1500, observerHeight: 100),
      terrain,
    )!;
    expect(
      cellAt(tower, GeoMath.destination(me, 1400, 90)),
      ViewshedCell.visible,
    );
  });

  test('dünya eğriliği: düzlükte uzak zemin görünmez', () {
    // Gözlemci 2 m, hedef zemin (0 m); ufuk ≈ 5 km (kırılmayla).
    final g = Viewshed.compute(
      const ViewshedParams(observer: me, radius: 10000, targetHeight: 0),
      (lat, lon) => 0,
    )!;
    expect(cellAt(g, GeoMath.destination(me, 3000, 0)), ViewshedCell.visible);
    expect(cellAt(g, GeoMath.destination(me, 9000, 0)), ViewshedCell.hidden);
    expect(g.cellMeters, closeTo(50, 0.1)); // 401 hücreye sığdırıldı
  });

  test('gözlemcinin yerinde veri yoksa hesaplanmaz', () {
    expect(
      Viewshed.compute(const ViewshedParams(observer: me), (lat, lon) => null),
      isNull,
    );
  });

  test('resim: hücre başına 4 bayt, verisiz saydam', () {
    final g = Viewshed.compute(
      const ViewshedParams(observer: me, radius: 300),
      (lat, lon) => 10,
    )!;
    final rgba = g.toRgba();
    expect(rgba.length, g.size * g.size * 4);
    expect(rgba[3], 0); // köşe saydam
    final mid = (g.size ~/ 2 * g.size + g.size ~/ 2) * 4;
    expect(rgba[mid + 3], greaterThan(0));
    expect(rgba[mid + 1], greaterThan(rgba[mid])); // yeşil
  });
}
