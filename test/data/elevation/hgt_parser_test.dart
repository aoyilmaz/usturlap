import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/data/elevation/hgt_parser.dart';

void main() {
  group('HgtParser Tests', () {
    test('Dizin set edilmeden null döner', () async {
      final parser = HgtParser();
      // init() çağrılmadığı için dış dizin null kalacak
      final elevation = await parser.getElevation(41.0, 28.0);
      expect(elevation, isNull);
    });
  });
}
