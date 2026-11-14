import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/models/range_line.dart';
import 'package:usturlap/providers/tool_providers.dart';
import 'package:latlong2/latlong.dart';

/// E1: ölçüm noktaları dokunulan nesnenin bağını taşır.
void main() {
  late ProviderContainer c;
  late ToolNotifier n;
  setUp(() {
    c = ProviderContainer();
    n = c.read(toolProvider.notifier);
  });
  tearDown(() => c.dispose());

  const p1 = LatLng(1, 1), p2 = LatLng(2, 2), p3 = LatLng(3, 3);

  test('bağlar noktalarla aynı sırada; geri al ve temizle', () {
    n.setMode(ToolMode.distance);
    n.addPoint(p1, ref: RbEnd.selfRef);
    n.addPoint(p2);
    n.addPoint(p3, ref: 'wp:a');
    var s = c.read(toolProvider);
    expect(s.refs, [RbEnd.selfRef, null, 'wp:a']);
    n.undo();
    s = c.read(toolProvider);
    expect(s.points, [p1, p2]);
    expect(s.refs, [RbEnd.selfRef, null]);
    n.clearPoints();
    s = c.read(toolProvider);
    expect(s.refs, isEmpty);
    expect(s.refAt(0), isNull);
  });

  test('menzil halkası: merkezin bağı kalır, yarıçap noktası değişir', () {
    n.setMode(ToolMode.rangeRings);
    n.addPoint(p1, ref: 'wp:merkez');
    n.addPoint(p2, ref: 'wp:x');
    n.addPoint(p3);
    final s = c.read(toolProvider);
    expect(s.points, [p1, p3]);
    expect(s.refs, ['wp:merkez', null]);
  });

  test('yeni araç seçince bağlar sıfırlanır', () {
    n.setMode(ToolMode.distance);
    n.addPoint(p1, ref: RbEnd.selfRef);
    n.setMode(ToolMode.polygon);
    expect(c.read(toolProvider).refs, isEmpty);
  });

  test('daire / dikdörtgen: ilk nokta sabit, ikinci değişir', () {
    for (final mode in [ToolMode.circle, ToolMode.rectangle]) {
      n.setMode(mode);
      n.addPoint(p1);
      n.addPoint(p2);
      n.addPoint(p3);
      expect(c.read(toolProvider).points, [p1, p3], reason: mode.name);
      expect(mode.isDrawing, isTrue);
    }
    expect(ToolMode.polygon.isDrawing, isFalse);
  });

  test('serbest çizim: dokunuş eklenmez, iz bütünüyle verilir', () {
    n.setMode(ToolMode.freehand);
    n.addPoint(p1);
    expect(c.read(toolProvider).points, isEmpty);
    n.setPath([p1, p2, p3]);
    expect(c.read(toolProvider).points, [p1, p2, p3]);
    n.setPath([p3, p1]);
    expect(c.read(toolProvider).points, [p3, p1]);
    // Başka araçta iz verilemez.
    n.setMode(ToolMode.polyline);
    n.setPath([p1, p2]);
    expect(c.read(toolProvider).points, isEmpty);
  });
}
