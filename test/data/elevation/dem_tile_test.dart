import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/elevation/dem_tile.dart';

import 'dem_test_data.dart';

/// F1: HGT ve DTED kareleri.
void main() {
  group('HGT', () {
    // 1201 (3″): yükseklik = 100·r + c (güneyden kuzeye satır).
    final bytes = makeHgt(1201, (r, c) => r == 600 && c == 600 ? null : r + c);
    final t = DemTile.parse(bytes, south: 37, west: 37);

    test('boyut, çözünürlük, köşe', () {
      expect(t.format, DemFormat.hgt);
      expect((t.rows, t.cols), (1201, 1201));
      expect(t.resolutionArcSec, 3);
      expect((t.south, t.west), (37, 37));
    });

    test('yön: güneybatı 0, kuzeydoğu en yüksek', () {
      expect(t.valueAt(0, 0), 0);
      expect(t.valueAt(1200, 1200), 2400);
      expect(t.nearest(37.0, 37.0), 0);
      expect(t.nearest(37.999999, 37.999999), 2400);
      // Kuzey kenar batı: satır 1200, sütun 0.
      expect(t.nearest(38.0, 37.0), 1200);
    });

    test('çift doğrusal: ızgara arasında ara değer', () {
      // r = 0,5 ve c = 0,5 ızgara aralığı → 0,5 + 0,5 = 1
      const step = 1 / 1200;
      expect(t.sample(37 + step / 2, 37 + step / 2), closeTo(1.0, 1e-6));
      expect(t.sample(37.5, 37.25), closeTo(600 + 300, 1e-6));
    });

    test('boşluk: en yakın nokta da boşsa null; komşusu varsa onu', () {
      expect(t.valueAt(600, 600), isNull);
      expect(t.nearest(37.5, 37.5), isNull);
      // Boşluğun yanındaki aralık: en yakın nokta dolu.
      const step = 1 / 1200;
      expect(t.sample(37.5 + step * 0.8, 37.5 + step * 0.2), 1201);
    });

    test('bozuk boyut ve adsız HGT hatası', () {
      expect(
        () => DemTile.parse(bytes.sublist(0, 1000), south: 1, west: 1),
        throwsFormatException,
      );
      expect(() => DemTile.parse(bytes), throwsFormatException);
    });
  });

  group('DTED', () {
    final bytes = makeDted(
      south: 43,
      west: -80,
      rows: 121,
      cols: 121,
      value: (r, c) => r == 5 && c == 5
          ? null
          : r == 0 && c == 1
          ? -12 // deniz seviyesi altı
          : 10 * r + c,
    );
    final t = DemTile.parse(bytes);

    test('köşe ve nokta sayıları başlıktan', () {
      expect(t.format, DemFormat.dted);
      expect((t.south, t.west), (43, -80));
      expect((t.rows, t.cols), (121, 121));
      expect(t.resolutionArcSec, 30);
    });

    test('sütun kayıtları: güneyden kuzeye, batıdan doğuya', () {
      expect(t.valueAt(0, 0), 0);
      expect(t.valueAt(120, 0), 1200);
      expect(t.valueAt(0, 120), 120);
      expect(t.nearest(44.0, -79.0), 1320);
    });

    test('işaret-büyüklük negatif ve boşluk', () {
      expect(t.valueAt(0, 1), -12);
      expect(t.valueAt(5, 5), isNull);
    });

    test('kısaltılmış dosya hatası', () {
      expect(
        () => DemTile.parse(bytes.sublist(0, 5000)),
        throwsFormatException,
      );
    });
  });

  test('kare anahtarı', () {
    expect(DemTile.keyFor(37, 37), 'N37E037');
    expect(DemTile.keyFor(-12, -45), 'S12W045');
    expect(DemTile.parseKey('N37E037.SRTMGL1.hgt'), (37, 37));
    expect(DemTile.parseKey('s12w045.hgt'), (-12, -45));
    expect(DemTile.parseKey('turkiye.hgt'), isNull);
    expect(DemTile.parseKey('N95E037.hgt'), isNull);
  });
}
