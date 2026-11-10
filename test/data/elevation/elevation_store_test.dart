import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/elevation/dem_tile.dart';
import 'package:kerteriz/data/elevation/elevation_store.dart';
import 'package:kerteriz/data/elevation/hgt_parser.dart';

import 'dem_test_data.dart';

/// F1: yükseklik dosyaları — içe aktar, listele, sil; okuyucu önbelleği.
void main() {
  late Directory dir;
  late ElevationStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dem_');
    store = ElevationStore(directory: () async => dir);
  });
  tearDown(() async => dir.delete(recursive: true));

  final hgt = makeHgt(1201, (r, c) => 500);
  final dted = makeDted(
    south: 38,
    west: 37,
    rows: 121,
    cols: 121,
    value: (r, c) => 700,
  );

  test('HGT adıyla, DTED başlığıyla içe aktarılır; liste', () async {
    final a = await store.importBytes(hgt, 'N37E037.SRTMGL3.hgt');
    expect(a.fileName, 'N37E037.hgt');
    final b = await store.importBytes(dted, 'n38.dt0');
    expect(b.fileName, 'N38E037.dt0');
    expect(b.format, DemFormat.dted);

    final list = await store.list();
    expect(list.map((t) => t.key), ['N37E037', 'N38E037']);
    // Uygulamayla gelen örnek, aynı kare dosyada olduğu için tekrar yok.
    expect(list.where((t) => t.bundled), isEmpty);
    expect(list.first.description, 'HGT 3″ (~93 m)');
    expect(list.last.resolutionArcSec, 30);
  });

  test(
    'örnek kare listede; aynı karenin başka biçimi eskisini değiştirir',
    () async {
      var list = await store.list();
      expect(list.single.key, 'N37E037');
      expect(list.single.bundled, isTrue);

      await store.importBytes(hgt, 'N38E037.hgt');
      final dtedSame = makeDted(
        south: 38,
        west: 37,
        rows: 121,
        cols: 121,
        value: (r, c) => 1,
      );
      await store.importBytes(dtedSame, 'kare.dt0');
      list = await store.list();
      final n38 = list.where((t) => t.key == 'N38E037').toList();
      expect(n38.single.fileName, 'N38E037.dt0');
      expect(File('${dir.path}/N38E037.hgt').existsSync(), isFalse);
    },
  );

  test('geçersiz dosyalar Türkçe hatayla reddedilir; sil', () async {
    expect(
      () => store.importBytes(hgt, 'turkiye.hgt'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => store.importBytes(hgt.sublist(0, 999), 'N37E037.hgt'),
      throwsA(isA<FormatException>()),
    );
    await store.importBytes(hgt, 'N40E030.hgt');
    await store.delete('N40E030.hgt');
    expect((await store.list()).any((t) => t.key == 'N40E030'), isFalse);
    // Klasör dışına silme yok.
    await store.delete('../baska.hgt');
  });

  group('HgtParser', () {
    var bundledLoads = 0;
    HgtParser parser() => HgtParser(
      directory: () async => dir,
      bundled: (key) async {
        bundledLoads++;
        return key == 'N41E028' ? makeHgt(1201, (r, c) => 42) : null;
      },
    );

    setUp(() => bundledLoads = 0);

    test('klasördeki HGT / DTED, yoksa örnek, o da yoksa null', () async {
      await store.importBytes(hgt, 'N37E037.hgt');
      await store.importBytes(dted, 'n38.dt0');
      final p = parser();
      expect(await p.getElevation(37.5, 37.5), 500);
      expect(await p.elevationAt(38.5, 37.5), closeTo(700, 1e-9));
      expect(await p.getElevation(41.2, 28.9), 42);
      expect(await p.getElevation(10.5, 10.5), isNull);
    });

    test('bulunamayan kare tekrar aranmaz; yenileyince aranır', () async {
      final p = parser();
      for (var i = 0; i < 50; i++) {
        expect(await p.getElevation(10.5, 10.5), isNull);
      }
      expect(bundledLoads, 1);
      await store.importBytes(hgt, 'N10E010.hgt');
      expect(await p.getElevation(10.5, 10.5), isNull); // önbellekte "yok"
      p.invalidate();
      expect(await p.getElevation(10.5, 10.5), 500);
    });

    test('klasör yoksa hata yok, örnekten okur', () async {
      final p = HgtParser(
        directory: () async => throw const FileSystemException('izin yok'),
        bundled: (key) async => makeHgt(1201, (r, c) => 7),
      );
      expect(await p.getElevation(37.1, 37.1), 7);
    });
  });
}
