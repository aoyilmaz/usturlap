import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerteriz/core/geo_math.dart';
import 'package:kerteriz/data/db/app_database.dart';
import 'package:kerteriz/domain/models/contact.dart';
import 'package:kerteriz/domain/ports/position_source.dart';
import 'package:kerteriz/providers/location_providers.dart';
import 'package:kerteriz/providers/settings_providers.dart';
import 'package:kerteriz/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

class _FakeSource implements PositionSource {
  final _c = StreamController<List<Contact>>.broadcast();

  void emit(LatLng p, {double accuracy = 5}) => _c.add([
    Contact(
      callsign: 'T',
      position: p,
      accuracyMeters: accuracy,
      timestamp: DateTime.now(),
      isSelf: true,
    ),
  ]);

  @override
  Stream<List<Contact>> get contacts => _c.stream;
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setBackgroundEnabled(bool enabled) async {}
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('son 15 dk izi: GPS konumlarını toplar, kötü doğruluğu atlar', () async {
    final src = _FakeSource();
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        positionSourceProvider.overrideWithValue(src),
      ],
    );
    addTearDown(c.dispose);
    c.listen(recentTrailProvider, (_, _) {});
    await _settle();
    const start = LatLng(39.9, 32.85);
    src.emit(start);
    await _settle();
    src.emit(GeoMath.destination(start, 30, 90), accuracy: 120); // atlanır
    await _settle();
    src.emit(GeoMath.destination(start, 60, 90));
    await _settle();
    final trail = c.read(recentTrailProvider);
    expect(trail, hasLength(2));
    expect(GeoMath.distance(trail.last, start), closeTo(60, 0.5));
  });

  test('GPS dairesi varsayılan açık; kapatma kalıcı', () async {
    ProviderContainer open() {
      final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      c.listen(showGpsCircleProvider, (_, _) {});
      c.listen(showCompassRoseProvider, (_, _) {});
      return c;
    }

    final c = open();
    await _settle();
    expect(c.read(showGpsCircleProvider), isTrue);
    expect(c.read(showCompassRoseProvider), isFalse);
    c.read(showGpsCircleProvider.notifier).toggle();
    c.read(showCompassRoseProvider.notifier).toggle();
    await _settle();

    final again = open();
    await _settle();
    expect(again.read(showGpsCircleProvider), isFalse);
    expect(again.read(showCompassRoseProvider), isTrue);
  });

  test('elle konum haritaya geçer; GPS ve son 15 dk izi etkilenmez', () async {
    final src = _FakeSource();
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        positionSourceProvider.overrideWithValue(src),
      ],
    );
    addTearDown(c.dispose);
    c.listen(selfContactProvider, (_, _) {});
    c.listen(recentTrailProvider, (_, _) {});
    await _settle();

    // GPS yokken bile elle konum kendi konumu olur.
    const fix = LatLng(40.0, 33.0);
    c.read(manualPositionProvider.notifier).set(fix);
    expect(c.read(selfContactProvider)?.position, fix);
    expect(c.read(selfContactProvider)?.accuracyMeters, isNull);
    expect(c.read(gpsSelfContactProvider), isNull);

    // GPS gelir: kendi konumu yine elle olan; iz GPS'le dolar.
    const gps = LatLng(39.9, 32.85);
    src.emit(gps);
    await _settle();
    expect(c.read(selfContactProvider)?.position, fix);
    expect(c.read(gpsSelfContactProvider)?.position, gps);
    expect(c.read(recentTrailProvider), [gps]);

    c.read(manualPositionProvider.notifier).clear();
    expect(c.read(selfContactProvider)?.position, gps);
  });

  test('kendi işaretin adı çağrı adından (GPS kaynağının adı değil)', () async {
    final src = _FakeSource();
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        positionSourceProvider.overrideWithValue(src),
      ],
    );
    addTearDown(c.dispose);
    c.listen(selfContactProvider, (_, _) {});
    await _settle();
    src.emit(const LatLng(39.9, 32.85));
    await _settle();
    c.read(callsignProvider.notifier).set('TA2STZ');
    expect(c.read(selfContactProvider)?.callsign, 'TA2STZ');
    expect(c.read(selfContactProvider)?.position, const LatLng(39.9, 32.85));
    c.read(manualPositionProvider.notifier).set(const LatLng(40, 33));
    expect(c.read(selfContactProvider)?.callsign, 'TA2STZ');
  });
}
