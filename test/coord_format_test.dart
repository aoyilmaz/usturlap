import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

import 'package:kerteriz/core/coord_format.dart';

void main() {
  group('CoordFormat.mgrs', () {
    test('Ankara için 36S grid zone\'unda gruplu MGRS üretir', () {
      const ankara = LatLng(39.925, 32.866);
      final mgrs = CoordFormat.mgrs(ankara);
      // "36S VK ##### #####" biçimi (GZD SQ easting northing)
      final parts = mgrs.split(' ');
      expect(parts.length, 4);
      expect(parts[0], '36S');
      expect(parts[2].length, 5);
      expect(parts[3].length, 5);
    });

    test('MGRS round-trip orijinal noktaya yakın (~birkaç metre)', () {
      const p = LatLng(39.925, 32.866);
      final raw = Mgrs.forward([p.longitude, p.latitude], 5);
      final point = Mgrs.toPoint(raw); // [lon, lat]
      expect((point[1] - p.latitude).abs() < 0.001, true);
      expect((point[0] - p.longitude).abs() < 0.001, true);
    });

    test('geçersiz (kutup) için — döner', () {
      const south = LatLng(-89.0, 0.0);
      expect(CoordFormat.mgrs(south), '—');
    });
  });

  group('CoordFormat.utm', () {
    test('Ankara için 36S zone\'unda easting/northing üretir', () {
      const ankara = LatLng(39.925, 32.866);
      final utm = CoordFormat.utm(ankara);
      // "36S #####E #####N" biçimi
      expect(utm.startsWith('36S '), true);
      expect(utm.endsWith('N'), true);
      expect(utm.contains('E '), true);
    });
  });

  group('CoordFormat.format dispatch', () {
    const p = LatLng(39.925, 32.866);
    test('seçilen biçime göre doğru üreticiye yönlenir', () {
      expect(CoordFormat.format(p, CoordFormatType.mgrs),
          CoordFormat.mgrs(p));
      expect(CoordFormat.format(p, CoordFormatType.utm), CoordFormat.utm(p));
      expect(CoordFormat.format(p, CoordFormatType.wgs84),
          CoordFormat.wgs84(p));
    });

    test('next MGRS→UTM→WGS84→MGRS döngüsü', () {
      expect(CoordFormatType.mgrs.next, CoordFormatType.utm);
      expect(CoordFormatType.utm.next, CoordFormatType.wgs84);
      expect(CoordFormatType.wgs84.next, CoordFormatType.mgrs);
    });
  });

  group('CoordFormat.wgs84', () {
    test('yarımküre harflerini doğru verir', () {
      expect(CoordFormat.wgs84(const LatLng(39.925, 32.866)),
          '39.92500°N, 32.86600°E');
      expect(CoordFormat.wgs84(const LatLng(-1.5, -2.5)),
          '1.50000°S, 2.50000°W');
    });
  });
}
