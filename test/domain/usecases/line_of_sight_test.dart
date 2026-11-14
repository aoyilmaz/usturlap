import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:usturlap/data/elevation/hgt_parser.dart';
import 'package:usturlap/domain/usecases/line_of_sight_calculator.dart';

/// Testler için sahte (Fake) bir DEM veri sağlayıcısı.
/// 40.5, 30.5 koordinatını bir dağ zirvesi (500m) kabul eder, diğer yerler düzlük (100m).
class FakeHgtParser extends HgtParser {
  @override
  Future<int?> getElevation(double lat, double lon) async {
    const distance = Distance();
    double distToCenter = distance.as(
      LengthUnit.Meter,
      LatLng(lat, lon),
      const LatLng(40.5, 30.5),
    );

    // Merkeze 20 km'den yakınsa "dağ" (500m)
    if (distToCenter < 20000) {
      return 500;
    }
    // Geri kalan her yer "düzlük" (100m)
    return 100;
  }
}

void main() {
  group('LineOfSightCalculator Tests', () {
    late FakeHgtParser fakeParser;
    late LineOfSightCalculator calc;

    setUp(() {
      fakeParser = FakeHgtParser();
      calc = LineOfSightCalculator(fakeParser);
    });

    test('Aradaki tepe görüş hattını keser (Kırmızı Çizgi)', () async {
      // Dağın (40.5, 30.5) iki zıt ucuna antenleri koyalım
      final source = const LatLng(40.2, 30.2); // Yükseklik 100m
      final target = const LatLng(40.8, 30.8); // Yükseklik 100m

      final result = await calc.calculate(
        source: source,
        target: target,
        sampleStepMeters: 2000,
        useRadioHorizon: false,
      );

      // Antenler 2 metre yükseklikte (102m). Ortadaki dağ 500m.
      // Işın dağın içinden geçer, görüş kapalı olmalıdır.
      expect(result.isVisible, isFalse);

      // En yüksek noktanın 500 civarında olduğunu test et
      final peak = result.profile.reduce(
        (curr, next) => curr.elevation > next.elevation ? curr : next,
      );
      expect(peak.elevation, 500);
    });

    test('Engelsiz düz arazide görüş hattı açıktır (Yeşil Çizgi)', () async {
      // Dağa uzak düz arazide, radyo ufkunun içinde (~4.2 km).
      final source = const LatLng(41.5, 31.5);
      final target = const LatLng(41.53, 31.53);

      final result = await calc.calculate(
        source: source,
        target: target,
        sampleStepMeters: 500,
      );

      // Engel olmadığı için görüş açık olmalıdır
      expect(result.isVisible, isTrue);
    });

    // 2 m antenin radyo ufku (4/3 R): √(2·R·h) ≈ 5.8 km; iki anten ≈ 11.7 km.
    // ~13.9 km'de ortadaki dünya şişkinliği ≈ 2.8 m > 2 m anten.
    test(
      'Düz arazide radyo ufkunun ötesi: dünya eğriliği görüşü keser',
      () async {
        final result = await calc.calculate(
          source: const LatLng(41.5, 31.5),
          target: const LatLng(41.6, 31.6),
          sampleStepMeters: 500,
        );
        expect(result.isVisible, isFalse);
        // Engel arazi değil eğrilik: ham yükseklik her yerde 100 m.
        expect(result.profile.every((p) => p.elevation == 100), isTrue);
      },
    );

    test('Aynı mesafede antenler yükselince (20 m) görüş açılır', () async {
      final result = await calc.calculate(
        source: const LatLng(41.5, 31.5),
        target: const LatLng(41.6, 31.6),
        sourceHeightMeters: 20,
        targetHeightMeters: 20,
        sampleStepMeters: 500,
      );
      expect(result.isVisible, isTrue);
    });
  });
}
