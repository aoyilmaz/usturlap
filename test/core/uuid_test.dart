import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/uuid.dart';

void main() {
  final v4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('RFC 4122 v4 biçimi: sürüm 4, varyant 8/9/a/b', () {
    for (var i = 0; i < 200; i++) {
      expect(newUuidV4(), matches(v4));
    }
  });

  test('çakışmaz', () {
    final set = {for (var i = 0; i < 5000; i++) newUuidV4()};
    expect(set, hasLength(5000));
  });

  test('aynı tohumla aynı sonuç (test edilebilirlik)', () {
    expect(newUuidV4(Random(7)), newUuidV4(Random(7)));
    expect(newUuidV4(Random(7)), matches(v4));
  });
}
