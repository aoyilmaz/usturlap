import 'package:flutter_test/flutter_test.dart';

import 'package:usturlap/core/track_filter.dart';

void main() {
  group('TrackFilter.accuracyOk', () {
    test('filtre kapalıyken her zaman kabul', () {
      expect(TrackFilter.accuracyOk(100, false), true);
      expect(TrackFilter.accuracyOk(null, false), true);
    });

    test('filtre açık: eşik altı kabul, üstü ret', () {
      expect(TrackFilter.accuracyOk(10, true), true);
      expect(TrackFilter.accuracyOk(TrackFilter.maxAccuracyMeters, true), true);
      expect(TrackFilter.accuracyOk(25, true), false);
    });

    test('doğruluk bilinmiyorsa (null) kabul', () {
      expect(TrackFilter.accuracyOk(null, true), true);
    });
  });
}
