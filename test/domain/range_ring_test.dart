import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/models/overlay_visibility.dart';
import 'package:usturlap/domain/models/range_line.dart';
import 'package:usturlap/domain/models/range_ring.dart';
import 'package:latlong2/latlong.dart';

/// E2: kalıcı menzil / tehdit halkaları.
void main() {
  RangeRing ring(List<double> radii, {String name = 'HALKA-1'}) => RangeRing(
    uid: 'rr1',
    name: name,
    center: const RbEnd(LatLng(37, 37)),
    radii: radii,
    colorValue: RangeRing.threatColor,
    createdAt: DateTime(2026),
  );

  test('eşit aralıklı halkalar', () {
    expect(RangeRing.evenRadii(500), [500, 1000, 1500]);
    expect(RangeRing.evenRadii(200, 2), [200, 400]);
  });

  group('parseRadii', () {
    test('metre, km eki, ayraçlar; sıralı ve tekrarsız', () {
      expect(RangeRing.parseRadii('500 1000 1.5km'), [500, 1000, 1500]);
      expect(RangeRing.parseRadii('500, 1000, 1500'), [500, 1000, 1500]);
      expect(RangeRing.parseRadii('2KM;300m 300'), [300, 2000]);
      expect(RangeRing.parseRadii('  750  '), [750]);
    });

    test('Türkçe ondalık virgül', () {
      expect(RangeRing.parseRadii('1,5km 2,25km'), [1500, 2250]);
      expect(RangeRing.parseRadii('1,5km, 3km'), [1500, 3000]);
    });

    test('geçersiz girişler null', () {
      for (final t in [
        '',
        '   ',
        'abc',
        '500, x',
        '0', // en az 1 m
        '250km', // en çok 200 km
        '-5',
      ]) {
        expect(RangeRing.parseRadii(t), isNull, reason: t);
      }
      // En çok 6 halka.
      expect(RangeRing.parseRadii('1 2 3 4 5 6'), hasLength(6));
      expect(RangeRing.parseRadii('1 2 3 4 5 6 7'), isNull);
    });

    test('formatRadii ile gidiş-dönüş', () {
      const radii = [500.0, 1000.0, 1500.5];
      final text = RangeRing.formatRadii(radii);
      expect(text, '500 1000 1500.5');
      expect(RangeRing.parseRadii(text), radii);
    });
  });

  test('ringIndexAt: içteki halkadan dışa; dışarıdaysa null', () {
    final r = ring([500, 1000, 1500]);
    expect(r.ringIndexAt(0), 0);
    expect(r.ringIndexAt(500), 0);
    expect(r.ringIndexAt(501), 1);
    expect(r.ringIndexAt(1499), 2);
    expect(r.ringIndexAt(1501), isNull);
    expect(ring(const []).ringIndexAt(10), isNull);
  });

  test('Overlay yöneticisi: grup, tek halka, #etiket', () {
    final r = ring([500], name: 'HAVAN #tehdit');
    const v = OverlayVisibility();
    expect(v.showsRangeRing(r), isTrue);
    expect(
      v.toggleGroup(OverlayVisibility.rangeRingsGroup).showsRangeRing(r),
      isFalse,
    );
    expect(v.toggleUid('rr1').showsRangeRing(r), isFalse);
    expect(v.withTag('tehdit').showsRangeRing(r), isTrue);
    expect(v.withTag('su').showsRangeRing(r), isFalse);
  });
}
