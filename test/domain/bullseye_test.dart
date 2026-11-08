import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/bearing_format.dart';
import 'package:kerteriz/domain/models/bullseye.dart';
import 'package:kerteriz/domain/models/range_line.dart';
import 'package:latlong2/latlong.dart';

/// E3: Bullseye.
void main() {
  const c = LatLng(37.0, 37.0);
  const north = LatLng(37.01, 37.0); // ≈ 1,11 km kuzey
  const east = LatLng(37.0, 37.01);

  test('halkalar ve en dış yarıçap', () {
    const b = Bullseye(center: RbEnd(c), ringSpacing: 500, ringCount: 4);
    expect(b.radii, [500, 1000, 1500, 2000]);
    expect(b.outerRadius, 2000);
  });

  test('çağrı: kerteriz / mesafe, seçili kuzey ve birimle', () {
    const trueDeg = BearingFormatter();
    expect(Bullseye.call(c, north, trueDeg), '000° / 1.11 km');
    expect(Bullseye.call(c, east, trueDeg), startsWith('090° / '));
    const mils = BearingFormatter(unit: AngleUnit.mils);
    expect(Bullseye.call(c, east, mils), startsWith('1600 mil / '));
  });

  test('ışınlar: coğrafide 0, 30, 60…; manyetikte sapma kadar döner', () {
    final t = Bullseye.radialBearings(c, NorthRef.trueNorth);
    expect(t, hasLength(12));
    expect(t[1], closeTo(30, 1e-9));
    final m = Bullseye.radialBearings(c, NorthRef.magnetic);
    final decl = NorthMath.toTrue(0, c, NorthRef.magnetic);
    expect(m[0], closeTo(decl, 1e-9));
    // Manyetik ışının etiketi tam 030°M olur.
    const fmt = BearingFormatter(ref: NorthRef.magnetic);
    expect(fmt.format(m[1], c), '030°M');
  });

  group('JSON', () {
    test('gidiş-dönüş (bağlı merkez dahil)', () {
      final b = Bullseye(
        center: RbEnd(c, RbEnd.waypointRef('op1')),
        name: 'OP-1',
        ringSpacing: 250,
        ringCount: 6,
      );
      final back = Bullseye.fromJson(b.toJson())!;
      expect(back.center, b.center);
      expect(back.name, 'OP-1');
      expect(back.ringSpacing, 250);
      expect(back.ringCount, 6);
    });

    test('bozuk kayıt null; halka sayısı sınırlanır; boş ad varsayılan', () {
      expect(Bullseye.fromJson(null), isNull);
      expect(Bullseye.fromJson('x'), isNull);
      expect(Bullseye.fromJson({'lat': 95, 'lon': 0}), isNull);
      expect(
        Bullseye.fromJson({'lat': 1, 'lon': 2, 'spacing': 0, 'rings': 3}),
        isNull,
      );
      final b = Bullseye.fromJson({
        'lat': 1,
        'lon': 2,
        'spacing': 100,
        'rings': 99,
        'name': '  ',
      })!;
      expect(b.ringCount, Bullseye.maxRings);
      expect(b.name, 'BULLSEYE');
      expect(b.center.ref, isNull);
    });
  });
}
