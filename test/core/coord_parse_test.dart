import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/coord_format.dart';
import 'package:kerteriz/core/coord_parse.dart';
import 'package:latlong2/latlong.dart';

const _d = Distance();
Matcher near(LatLng p, double meters) => predicate<LatLng?>(
    (q) => q != null && _d(p, q) <= meters, 'within $meters m of $p');

void main() {
  const ankara = LatLng(39.92510, 32.86600);
  const gaziantep = LatLng(37.06600, 37.38300);

  group('MGRS', () {
    test('biçimlendiricinin çıktısı geri çözülür (1 m)', () {
      for (final p in [ankara, gaziantep]) {
        final s = CoordFormat.mgrs(p);
        expect(CoordParse.parse(s), near(p, 2));
        expect(CoordParse.parse(s.replaceAll(' ', '')), near(p, 2));
        expect(CoordParse.parse(s.toLowerCase()), near(p, 2));
      }
    });

    test('düşük hassasiyet → hücre merkezi', () {
      final s = CoordFormat.mgrs(ankara, accuracy: 3); // 100 m hücre
      expect(s, '36S VK 885 194'); // ilk haneler (kesme), sondakiler değil
      expect(CoordParse.mgrs(s), near(ankara, 100));
      expect(CoordParse.mgrs(CoordFormat.mgrs(ankara, accuracy: 4)),
          near(ankara, 10));
    });

    test('parçalı giriş (ayrı alanlar)', () {
      final full = CoordFormat.mgrs(ankara).split(' '); // [GZD, kare, E, N]
      expect(
          CoordParse.mgrsParts(
              gzd: full[0], square: full[1], easting: full[2], northing: full[3]),
          near(ankara, 2));
      // Doğu/kuzey uzunlukları farklı → geçersiz.
      expect(
          CoordParse.mgrsParts(
              gzd: full[0], square: full[1], easting: '123', northing: '4567'),
          isNull);
    });

    test('geçersiz MGRS', () {
      expect(CoordParse.mgrs('99S DB 12345 67890'), isNull); // zone > 60
      expect(CoordParse.mgrs('37S DB 1234 678'), isNull); // tek sayıda hane
      expect(CoordParse.mgrs('37I DB 12345 67890'), isNull); // I bant değil
    });
  });

  group('UTM', () {
    test('biçimlendiricinin çıktısı geri çözülür', () {
      for (final p in [ankara, gaziantep]) {
        final s = CoordFormat.utm(p); // "36S 489000E 4419000N"
        expect(CoordParse.parse(s), near(p, 2));
      }
    });

    test('E/N harfsiz ve virgüllü yazım', () {
      final parts = CoordFormat.utm(ankara).split(' ');
      final zone = parts[0];
      final e = parts[1].replaceAll('E', '');
      final n = parts[2].replaceAll('N', '');
      expect(CoordParse.parse('$zone $e $n'), near(ankara, 2));
      expect(CoordParse.parse('$zone $e, $n'), near(ankara, 2));
    });

    test('aralık dışı doğu → null', () {
      expect(CoordParse.utm('36S 50000 4419000'), isNull);
    });
  });

  group('Ondalık derece', () {
    test('düz, işaretli ve yön harfli', () {
      expect(CoordParse.parse('39.9251, 32.866'), near(ankara, 1));
      expect(CoordParse.parse('39.9251 32.866'), near(ankara, 1));
      expect(CoordParse.parse('39.9251N 32.866E'), near(ankara, 1));
      expect(CoordParse.parse('39,9251; 32,866'), near(ankara, 1));
    });

    test('Türkçe yön harfleri (K/G/D/B) ve güney/batı', () {
      expect(CoordParse.parse('39.9251K 32.866D'), near(ankara, 1));
      final p = CoordParse.parse('10.5G 20.25B')!;
      expect(p.latitude, -10.5);
      expect(p.longitude, -20.25);
    });

    test('aralık dışı → null', () {
      expect(CoordParse.parse('95.0, 32.0'), isNull);
    });
  });

  group('Derece-dakika-saniye', () {
    test('işaretli, boşluklu ve ondalık dakika', () {
      // 39°55'30.36"N = 39.92510
      expect(CoordParse.parse('39°55\'30.36"N 32°51\'57.6"E'), near(ankara, 2));
      expect(CoordParse.parse('39 55 30.36 K 32 51 57.6 D'), near(ankara, 2));
      expect(CoordParse.parse("39°55.506'N 32°51.96'E"), near(ankara, 2));
    });

    test('dakika ≥ 60 → null', () {
      expect(CoordParse.dms('39°75\'00"N 32°51\'57"E'), isNull);
    });
  });

  test('boş / anlamsız → null', () {
    expect(CoordParse.parse(''), isNull);
    expect(CoordParse.parse('merhaba'), isNull);
  });
}
