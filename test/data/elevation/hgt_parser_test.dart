import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/elevation/hgt_parser.dart';

void main() {
  group('HgtParser Tests', () {
    test('Dizin bulunamazsa null döner, hata fırlatmaz', () async {
      final parser = HgtParser();
      // Testte path_provider eklentisi yok: hazırlık dizini bulamaz.
      final elevation = await parser.getElevation(41.0, 28.0);
      expect(elevation, isNull);
    });
  });
}
