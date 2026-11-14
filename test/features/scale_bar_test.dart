import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/features/map/widgets/scale_bar.dart';

void main() {
  group('ScaleBarMath', () {
    test('ekvatorda zoom 0: ~78 km/piksel (512 px dünya)', () {
      expect(ScaleBarMath.metersPerPixel(0, 0), closeTo(78271.5, 0.1));
    });

    test('her zoom adımı yarıya indirir, enlemle cos oranında küçülür', () {
      final a = ScaleBarMath.metersPerPixel(15, 0);
      expect(ScaleBarMath.metersPerPixel(16, 0), closeTo(a / 2, 1e-9));
      expect(ScaleBarMath.metersPerPixel(15, 60), closeTo(a / 2, 1e-9));
    });

    test('seçilen mesafe 1/2/5 × 10ⁿ ve genişliğe sığar', () {
      for (var z = 3.0; z <= 22; z += 0.37) {
        final s = ScaleBarMath.pick(z, 39.9, maxPx: 110);
        expect(s.pixels, lessThanOrEqualTo(110.0001), reason: 'z=$z');
        // Bir üst yuvarlak değer sığmazdı → çubuk en az ~40 px.
        expect(s.pixels, greaterThan(40), reason: 'z=$z');
        var m = s.meters;
        while (m >= 10) {
          m /= 10;
        }
        while (m < 1) {
          m *= 10;
        }
        expect([1, 2, 5], contains(m.round()), reason: 'z=$z ${s.meters}');
      }
    });

    test('etiketler', () {
      expect(ScaleBarMath.label(500), '500 m');
      expect(ScaleBarMath.label(2000), '2 km');
      expect(ScaleBarMath.label(5000000), '5000 km');
      expect(ScaleBarMath.label(1), '1 m');
      expect(ScaleBarMath.label(0.5), '0.5 m');
    });
  });
}
