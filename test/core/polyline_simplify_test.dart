import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/polyline_simplify.dart';

/// G1: serbest çizim sadeleştirme.
void main() {
  test('düz çizgi uçlarına iner; köşe kalır', () {
    final straight = [for (var i = 0; i <= 100; i++) (i.toDouble(), 0.0)];
    expect(simplifyPolyline(straight, 1), [(0.0, 0.0), (100.0, 0.0)]);
    final corner = [
      for (var i = 0; i <= 50; i++) (i.toDouble(), 0.0),
      for (var i = 1; i <= 50; i++) (50.0, i.toDouble()),
    ];
    expect(simplifyPolyline(corner, 1), [
      (0.0, 0.0),
      (50.0, 0.0),
      (50.0, 50.0),
    ]);
  });

  test('tolerans içindeki titreme atılır, dışındaki kalır', () {
    final jitter = [(0.0, 0.0), (10.0, 0.8), (20.0, -0.6), (30.0, 0.0)];
    expect(simplifyPolyline(jitter, 1), hasLength(2));
    expect(simplifyPolyline(jitter, 0.5), hasLength(4));
  });

  test('kısa girdiler olduğu gibi; uzun çizgide taşma yok', () {
    expect(simplifyPolyline([(1.0, 1.0)], 1), [(1.0, 1.0)]);
    final zigzag = [
      for (var i = 0; i < 20000; i++) (i.toDouble(), i.isEven ? 0.0 : 5.0),
    ];
    expect(simplifyPolyline(zigzag, 1).length, 20000);
  });
}
