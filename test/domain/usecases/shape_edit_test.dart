import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/geo_math.dart';
import 'package:kerteriz/domain/models/map_graphic.dart';
import 'package:kerteriz/domain/usecases/shape_edit.dart';
import 'package:latlong2/latlong.dart';

/// Kayıtlı çizimin şeklini düzenleme.
void main() {
  final t0 = DateTime.utc(2026, 11, 11);

  MapGraphic g(GraphicType type, List<LatLng> pts) => MapGraphic(
    id: 7,
    uid: 'g',
    name: 'ŞEKİL',
    type: type,
    points: pts,
    colorValue: 0xFFFF0000,
    createdAt: t0,
  );

  test('alan: köşeye dokun → seç, yeni yere dokun → taşı; geri al', () {
    const a = [LatLng(39, 32), LatLng(39, 33), LatLng(40, 33)];
    var s = ShapeEditState(g(GraphicType.area, a));
    expect(s.changed, isFalse);
    expect(s.canUndo, isFalse);
    // Seçim yokken taşıma bir şey yapmaz.
    expect(s.moveSelectedTo(const LatLng(0, 0)).points, a);
    s = s.select(2).moveSelectedTo(const LatLng(40, 32));
    expect(s.points, [a[0], a[1], const LatLng(40, 32)]);
    expect(s.selected, isNull);
    expect(s.changed, isTrue);
    expect(s.preview.points, s.points);
    expect(s.preview.name, 'ŞEKİL');
    s = s.undo();
    expect(s.points, a);
    expect(s.changed, isFalse);
  });

  test('kenar ortasına köşe ekle, sil; en az sayı korunur', () {
    const a = [LatLng(39, 32), LatLng(39, 33), LatLng(40, 33)];
    var s = ShapeEditState(g(GraphicType.area, a));
    // Alanda kapanan kenar da dahil 3 kenar.
    expect(s.midpoints, hasLength(3));
    expect(s.midpoints[2], const LatLng(39.5, 32.5));
    s = s.insertMidpoint(0);
    expect(s.points, hasLength(4));
    expect(s.points[1], const LatLng(39, 32.5));
    expect(s.selected, 1);
    expect(s.canRemoveSelected, isTrue);
    s = s.removeSelected();
    expect(s.points, a);
    expect(s.select(0).canRemoveSelected, isFalse); // 3 köşe kalmalı
    final line = ShapeEditState(g(GraphicType.line, a));
    expect(line.midpoints, hasLength(2));
    expect(line.select(1).removeSelected().points, [a[0], a[2]]);
    expect(
      ShapeEditState(
        g(GraphicType.line, [a[0], a[1]]),
      ).select(0).canRemoveSelected,
      isFalse,
    );
  });

  test('dikdörtgen: köşe taşınınca karşı köşe sabit, eksenli kalır', () {
    final corners = GeoMath.rectangleCorners(
      const LatLng(39, 32),
      const LatLng(40, 33),
    );
    var s = ShapeEditState(g(GraphicType.rectangle, corners));
    expect(s.midpoints, isEmpty);
    s = s.select(1).moveSelectedTo(const LatLng(38.5, 33.5));
    final p = s.points;
    expect(p[1], const LatLng(38.5, 33.5));
    expect(p[3], corners[3]); // karşı köşe
    // Komşu köşeler eksenli: kenarlar enlem / boylam boyunca.
    expect(p[0].longitude, p[3].longitude);
    expect(p[0].latitude, p[1].latitude);
    expect(p[2].longitude, p[1].longitude);
    expect(p[2].latitude, p[3].latitude);
  });

  test(
    'daire: merkez taşınınca yarıçap korunur, kenar yarıçapı değiştirir',
    () {
      const c = LatLng(39, 32);
      final edge = GeoMath.destination(c, 500, 0);
      var s = ShapeEditState(g(GraphicType.circle, [c, edge]));
      expect(s.center, c);
      s = s.select(0).moveSelectedTo(const LatLng(39.1, 32.1));
      expect(s.points[0], const LatLng(39.1, 32.1));
      expect(s.preview.radiusMeters, closeTo(500, 0.5));
      s = s.select(1).moveSelectedTo(GeoMath.destination(s.points[0], 800, 90));
      expect(s.preview.radiusMeters, closeTo(800, 0.5));
    },
  );

  test('bütün şekli taşı: boyut ve kerterizler korunur', () {
    const o = LatLng(39, 32);
    final a = [
      o,
      GeoMath.destination(o, 1000, 90),
      GeoMath.destination(o, 1000, 0),
    ];
    var s = ShapeEditState(g(GraphicType.area, a));
    final to = GeoMath.destination(s.center, 5000, 45);
    s = s.select(ShapeEditState.moveAll).moveSelectedTo(to);
    // Ağırlık merkezi enlem/boylam ortalaması: küre üstünde ~1 m sapar.
    expect(GeoMath.distance(s.center, to), lessThan(5));
    // Yuvarlamasız ölçüm (GeoMath tam metreye yuvarlar).
    const exact = Distance(roundResult: false);
    expect(
      exact.distance(s.points[0], s.points[1]),
      closeTo(exact.distance(a[0], a[1]), 0.05),
    );
    expect(
      exact.distance(s.points[0], s.points[2]),
      closeTo(exact.distance(a[0], a[2]), 0.05),
    );
    // Dikdörtgen kayınca eksenli kalır.
    final r = ShapeEditState(
      g(
        GraphicType.rectangle,
        GeoMath.rectangleCorners(const LatLng(39, 32), const LatLng(40, 33)),
      ),
    ).select(ShapeEditState.moveAll).moveSelectedTo(const LatLng(41.5, 35.5));
    expect(r.points[0], const LatLng(41, 35));
    expect(r.points[2], const LatLng(42, 36));
  });
}
