import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/bearing_format.dart';
import 'package:kerteriz/core/wmm.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final day = DateTime.utc(2026, 11, 6);
  const ankara = LatLng(39.93, 32.86); // UTM 36, merkez meridyen 33°
  const gaziantep = LatLng(37.06, 37.38); // UTM 37, merkez meridyen 39°

  group('NorthMath', () {
    test('toTrue fromTrue\'nun tersi (manyetik, grid, coğrafi)', () {
      const at = LatLng(39.9, 32.85);
      for (final ref in NorthRef.values) {
        for (final deg in [0.0, 45.0, 181.5, 359.0]) {
          final shown = NorthMath.fromTrue(deg, at, ref);
          expect(
            NorthMath.toTrue(shown, at, ref),
            closeTo(deg, 1e-9),
            reason: '$ref $deg',
          );
        }
      }
    });

    test('grid yakınsaması: merkez meridyende ~0', () {
      expect(
        NorthMath.gridConvergence(const LatLng(39.0, 33.0)),
        closeTo(0, 1e-9),
      );
    });

    test('grid yakınsaması: meridyenin batısında (−), doğusunda (+)', () {
      // Gaziantep 37.38°, meridyen 39° → batıda: γ ≈ −1.62 × sin(37°) ≈ −0.98°
      expect(NorthMath.gridConvergence(gaziantep), closeTo(-0.976, 0.01));
      // Ankara 32.86°, meridyen 33° → çok az batıda
      expect(NorthMath.gridConvergence(ankara), closeTo(-0.09, 0.01));
    });

    test('manyetik = coğrafi − sapma', () {
      final d = Wmm.declination(ankara.latitude, ankara.longitude, date: day);
      expect(
        NorthMath.fromTrue(90, ankara, NorthRef.magnetic, date: day),
        closeTo(90 - d, 1e-9),
      );
    });

    test('0–360 aralığına sarar', () {
      // Sapma doğuya ~6° → coğrafi 2° manyetikte ~356° olur.
      final v = NorthMath.fromTrue(2, ankara, NorthRef.magnetic, date: day);
      expect(v, inInclusiveRange(350, 360));
      expect(NorthMath.fromTrue(-10, ankara, NorthRef.trueNorth), 350);
    });
  });

  group('BearingFormatter', () {
    test('varsayılan: coğrafi + derece, 3 hane, ek harf yok', () {
      const f = BearingFormatter();
      expect(f.format(45, ankara), '045°');
      expect(f.format(359.6, ankara), '000°');
      expect(f.format(7.2, ankara), '007°');
    });

    test('manyetik derecede M eki', () {
      const f = BearingFormatter(ref: NorthRef.magnetic);
      final d = Wmm.declination(ankara.latitude, ankara.longitude, date: day);
      final expected = ((90 - d).round() % 360).toString().padLeft(3, '0');
      expect(f.format(90, ankara, date: day), '$expected°M');
    });

    test('mil: 6400 sistem, 4 hane', () {
      const f = BearingFormatter(unit: AngleUnit.mils);
      expect(f.format(90, ankara), '1600 mil');
      expect(f.format(180, ankara), '3200 mil');
      expect(f.format(359.99, ankara), '0000 mil');
      expect(f.format(45, ankara), '0800 mil');
    });

    test('grid + mil: G eki', () {
      const f = BearingFormatter(ref: NorthRef.grid, unit: AngleUnit.mils);
      expect(f.format(90, gaziantep), endsWith(' mil G'));
    });
  });

  test('enum adlarından geri okuma (kalıcı ayar)', () {
    expect(NorthRef.fromName('magnetic'), NorthRef.magnetic);
    expect(NorthRef.fromName(null), NorthRef.trueNorth);
    expect(AngleUnit.fromName('mils'), AngleUnit.mils);
    expect(AngleUnit.fromName('bozuk'), AngleUnit.degrees);
  });
}
