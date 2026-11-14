import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/elevation/elevation_store.dart';
import 'package:usturlap/data/elevation/hgt_parser.dart';
import 'package:usturlap/providers/elevation_providers.dart';
import 'package:usturlap/providers/terrain_analysis_providers.dart';
import 'package:latlong2/latlong.dart';

import '../data/elevation/dem_test_data.dart';

/// F4 / F5: arazi analizi arka planda (gerçek isolate).
void main() {
  late Directory dir;
  late ProviderContainer c;
  const center = LatLng(37.5, 37.5);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('terrain_');
    // Güneyden kuzeye 0 → 1200 m tırmanan kare (yaklaşık %1).
    await ElevationStore(
      directory: () async => dir,
    ).importBytes(makeHgt(1201, (r, c) => r), 'N37E037.hgt');
    c = ProviderContainer(
      overrides: [
        hgtParserProvider.overrideWithValue(
          HgtParser(directory: () async => dir, bundled: (_) async => null),
        ),
      ],
    );
    c.listen(terrainAnalysisProvider, (_, _) {});
  });
  tearDown(() async {
    c.dispose();
    await dir.delete(recursive: true);
  });

  test('otomatik aralık: en çok ~20 eğri', () {
    expect(autoContourInterval(800, 900), 5);
    expect(autoContourInterval(500, 900), 20);
    expect(autoContourInterval(0, 3000), 200);
    expect(autoContourInterval(0, 9000), 500);
  });

  test('eğriler ve renkli katman birlikte durur; ayrı kaldırılır', () async {
    final n = c.read(terrainAnalysisProvider.notifier);
    await n.drawContours(center, 2000);
    var s = c.read(terrainAnalysisProvider)!;
    expect(s.busy, isFalse);
    expect(s.error, isNull);
    // 2 km kenarda ~36 m fark → otomatik 5 m.
    expect(s.interval, 5);
    expect(s.contours, isNotEmpty);

    await n.drawColor(center, 2000, TerrainColorMode.slope);
    s = c.read(terrainAnalysisProvider)!;
    expect(s.contours, isNotEmpty); // eğriler korunur
    expect(s.colorMode, TerrainColorMode.slope);
    expect(s.image!.pixels.length, s.image!.width * s.image!.height * 4);

    n.clearContours();
    s = c.read(terrainAnalysisProvider)!;
    expect(s.contours, isEmpty);
    expect(s.image, isNotNull);
    n.clearColor();
    expect(c.read(terrainAnalysisProvider), isNull);
  });

  test('seçilen aralık kullanılır; veri yoksa uyarı', () async {
    final n = c.read(terrainAnalysisProvider.notifier);
    await n.drawContours(center, 2000, interval: 10);
    expect(c.read(terrainAnalysisProvider)!.interval, 10);
    n.clear();
    await n.drawColor(
      const LatLng(10.5, 10.5),
      1000,
      TerrainColorMode.elevation,
    );
    expect(
      c.read(terrainAnalysisProvider)!.error,
      contains('arazi verisi yok'),
    );
  });
}
