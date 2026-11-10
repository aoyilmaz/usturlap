import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/elevation/elevation_store.dart';
import 'package:kerteriz/data/elevation/hgt_parser.dart';
import 'package:kerteriz/domain/usecases/viewshed.dart';
import 'package:kerteriz/providers/elevation_providers.dart';
import 'package:kerteriz/providers/viewshed_providers.dart';
import 'package:latlong2/latlong.dart';

import '../data/elevation/dem_test_data.dart';

/// F3: görüş alanı arka planda (gerçek isolate) hesaplanır.
void main() {
  late Directory dir;
  late ProviderContainer c;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('viewshed_');
    // Düz 200 m arazi.
    await ElevationStore(
      directory: () async => dir,
    ).importBytes(makeHgt(1201, (r, c) => 200), 'N37E037.hgt');
    c = ProviderContainer(
      overrides: [
        hgtParserProvider.overrideWithValue(
          HgtParser(directory: () async => dir, bundled: (_) async => null),
        ),
      ],
    );
    c.listen(viewshedProvider, (_, _) {});
  });
  tearDown(() async {
    c.dispose();
    await dir.delete(recursive: true);
  });

  test('hesapla: önce meşgul, sonra ızgara', () async {
    final n = c.read(viewshedProvider.notifier);
    final f = n.run(
      const ViewshedParams(observer: LatLng(37.5, 37.5), radius: 1000),
      observerName: 'OP-1',
    );
    expect(c.read(viewshedProvider)!.busy, isTrue);
    await f;
    final s = c.read(viewshedProvider)!;
    expect(s.busy, isFalse);
    expect(s.error, isNull);
    expect(s.observerName, 'OP-1');
    expect(s.grid!.observerGround, closeTo(200, 1e-6));
    expect(s.grid!.visibleFraction, 1);
  });

  test('veri yoksa anlaşılır uyarı', () async {
    await c
        .read(viewshedProvider.notifier)
        .run(const ViewshedParams(observer: LatLng(10.5, 10.5)));
    final s = c.read(viewshedProvider)!;
    expect(s.grid, isNull);
    expect(s.error, contains('arazi verisi yok'));
  });

  test('yeni hesap eskisinin sonucunu ezmez; temizle', () async {
    final n = c.read(viewshedProvider.notifier);
    final slow = n.run(
      const ViewshedParams(observer: LatLng(37.5, 37.5), radius: 2000),
    );
    final fast = n.run(
      const ViewshedParams(observer: LatLng(37.4, 37.4), radius: 500),
    );
    await Future.wait([slow, fast]);
    expect(c.read(viewshedProvider)!.params.radius, 500);
    n.clear();
    expect(c.read(viewshedProvider), isNull);
  });
}
