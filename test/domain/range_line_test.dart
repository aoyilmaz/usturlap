import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/domain/models/overlay_visibility.dart';
import 'package:usturlap/domain/models/range_line.dart';
import 'package:latlong2/latlong.dart';

/// E1: kalıcı R&B çizgisi — uç bağları ve ölçüm.
void main() {
  const a = LatLng(37.0, 37.0);
  const b = LatLng(37.01, 37.0); // ≈ 1,11 km kuzey
  const moved = LatLng(37.02, 37.02);

  group('RbEnd', () {
    test('bağsız uç sabit kalır', () {
      const e = RbEnd(a);
      expect(e.resolve(self: moved, waypoints: {'x': moved}), a);
      expect(e.isSelf, isFalse);
      expect(e.waypointUid, isNull);
    });

    test('kendi konumuma bağlı uç beni izler; GPS yoksa kurulduğu yerde', () {
      const e = RbEnd(a, RbEnd.selfRef);
      expect(e.isSelf, isTrue);
      expect(e.resolve(self: moved), moved);
      expect(e.resolve(), a);
    });

    test('noktaya bağlı uç noktayı izler; nokta silinirse yerinde kalır', () {
      final e = RbEnd(a, RbEnd.waypointRef('uid-1'));
      expect(e.waypointUid, 'uid-1');
      expect(e.resolve(waypoints: {'uid-1': moved}), moved);
      expect(e.resolve(waypoints: {'baska': moved}), a);
      // Kendi konumum noktaya bağlı ucu etkilemez.
      expect(e.resolve(self: b), a);
    });
  });

  group('RbMeasure', () {
    test('mesafe, kerteriz 0–360 ve ters kerteriz', () {
      final m = RbMeasure.between(a, b);
      expect(m.meters, closeTo(1109, 3));
      expect(m.bearing, closeTo(0, 0.01));
      expect(m.backBearing, closeTo(180, 0.01));
      // Batıya: -90 değil 270.
      final w = RbMeasure.between(a, const LatLng(37.0, 36.99));
      expect(w.bearing, closeTo(270, 0.05));
      expect(w.backBearing, closeTo(90, 0.05));
    });

    test('eğim: yükselme +, depresyon −; yükseklik yoksa null', () {
      final up = RbMeasure.between(a, b, elevationFrom: 800, elevationTo: 900);
      expect(up.rise, 100);
      // atan(100 / 1109) ≈ 5,15°
      expect(up.slopeDeg, closeTo(5.15, 0.05));
      final down = RbMeasure.between(
        a,
        b,
        elevationFrom: 900,
        elevationTo: 800,
      );
      expect(down.slopeDeg, closeTo(-5.15, 0.05));
      expect(RbMeasure.between(a, b, elevationFrom: 800).slopeDeg, isNull);
      expect(RbMeasure.between(a, b).rise, isNull);
    });

    test('üst üste uçlarda eğim anlamsız', () {
      final m = RbMeasure.between(a, a, elevationFrom: 1, elevationTo: 50);
      expect(m.meters, 0);
      expect(m.slopeDeg, isNull);
    });
  });

  test('Overlay yöneticisi: grup, tek çizgi ve #etiket süzgeci', () {
    final line = RangeLine(
      uid: 'rb1',
      name: 'R&B-1 #keşif',
      start: const RbEnd(a),
      end: const RbEnd(b),
      colorValue: RangeLine.defaultColor,
      createdAt: DateTime(2026),
    );
    const v = OverlayVisibility();
    expect(v.showsRangeLine(line), isTrue);
    expect(
      v.toggleGroup(OverlayVisibility.rangeLinesGroup).showsRangeLine(line),
      isFalse,
    );
    expect(v.toggleUid('rb1').showsRangeLine(line), isFalse);
    expect(v.withTag('keşif').showsRangeLine(line), isTrue);
    expect(v.withTag('su').showsRangeLine(line), isFalse);
    // R&B grubunu gizlemek çizimleri etkilemez.
    final g = MapGraphic(
      uid: 'g',
      name: 'Hat',
      type: GraphicType.line,
      points: const [a, b],
      colorValue: 0xFFFF0000,
      createdAt: DateTime(2026),
    );
    expect(
      v.toggleGroup(OverlayVisibility.rangeLinesGroup).showsGraphic(g),
      isTrue,
    );
  });
}
