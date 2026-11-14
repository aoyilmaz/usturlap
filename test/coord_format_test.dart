import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart';

import 'package:usturlap/core/coord_format.dart';
import 'package:usturlap/core/coord_parse.dart';

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

    test('next MGRS→UTM→WGS84→DM→DMS→MGRS döngüsü', () {
      expect(CoordFormatType.mgrs.next, CoordFormatType.utm);
      expect(CoordFormatType.utm.next, CoordFormatType.wgs84);
      expect(CoordFormatType.wgs84.next, CoordFormatType.dm);
      expect(CoordFormatType.dm.next, CoordFormatType.dms);
      expect(CoordFormatType.dms.next, CoordFormatType.mgrs);
    });

    test('DM ve DMS dispatch', () {
      expect(CoordFormat.format(p, CoordFormatType.dm), CoordFormat.dm(p));
      expect(CoordFormat.format(p, CoordFormatType.dms), CoordFormat.dms(p));
    });
  });

  group('CoordFormat.dm / dms', () {
    test('DM: 39.925 → 39°55.500\'N', () {
      expect(CoordFormat.dm(const LatLng(39.925, 32.866)),
          "39°55.500'N 32°51.960'E");
    });

    test('DMS: tam değer', () {
      expect(CoordFormat.dms(const LatLng(39.925, 32.866)),
          '39°55\'30.0"N 32°51\'57.6"E');
    });

    test('güney/batı yarımküre', () {
      expect(CoordFormat.dms(const LatLng(-33.5, -70.25)),
          '33°30\'00.0"S 70°15\'00.0"W');
      expect(CoordFormat.dm(const LatLng(-33.5, -70.25)),
          "33°30.000'S 70°15.000'W");
    });

    test('yuvarlama taşması: 59.99" → bir sonraki dakika', () {
      // 39° 59' 59.99" = 39.99999722°
      expect(CoordFormat.dms(const LatLng(39.99999722, 0)),
          startsWith('40°00\'00.0"N'));
      // 39° 59.9999' → 40°00.000'
      expect(CoordFormat.dm(const LatLng(39.9999983, 0)),
          startsWith("40°00.000'N"));
    });

    test('DMS çıktısı ayrıştırıcıyla geri okunur (≤ 3 m)', () {
      const pts = [
        LatLng(39.92512, 32.86603),
        LatLng(37.06621, 37.38321),
        LatLng(41.00824, 28.97836),
      ];
      for (final pt in pts) {
        final back = CoordParse.parse(CoordFormat.dms(pt));
        expect(back, isNotNull, reason: CoordFormat.dms(pt));
        expect(const Distance()(pt, back!), lessThan(3));
      }
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
