import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/models/contact.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/providers/geofence_providers.dart';
import 'package:usturlap/providers/graphic_providers.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:latlong2/latlong.dart';

/// Testte konumu elle sürmek için.
class _FakeSelf extends Notifier<Contact?> {
  @override
  Contact? build() => null;
  void set(Contact? c) => state = c;
}

final _fakeSelf = NotifierProvider<_FakeSelf, Contact?>(_FakeSelf.new);

/// G3: geofence sağlayıcısı — konumdan uyarıya.
void main() {
  final t0 = DateTime.utc(2026, 11, 10, 9);
  const inside = LatLng(39.5, 32.5), outside = LatLng(40.5, 33.5);
  final fence = MapGraphic(
    uid: 'a',
    name: 'ALAN-1',
    type: GraphicType.area,
    points: const [
      LatLng(39, 32),
      LatLng(39, 33),
      LatLng(40, 33),
      LatLng(40, 32),
    ],
    colorValue: 0xFFFF0000,
    createdAt: t0,
    geofence: GeofenceTrigger.both,
  );

  late ProviderContainer c;
  setUp(() async {
    c = ProviderContainer(
      overrides: [
        selfContactProvider.overrideWith((ref) => ref.watch(_fakeSelf)),
        mapGraphicsProvider.overrideWith((ref) => Stream.value([fence])),
      ],
    );
    addTearDown(c.dispose);
    c.listen(geofenceProvider, (_, _) {});
    c.listen(mapGraphicsProvider, (_, _) {});
    await c.read(mapGraphicsProvider.future);
  });

  /// Konumu değiştirip izleyiciyi okur: Riverpod okunmadan art arda gelen
  /// değerleri birleştirir (uygulamada her GPS konumu ayrı karede gelir).
  void move(Contact self) {
    c.read(_fakeSelf.notifier).set(self);
    c.read(geofenceProvider);
  }

  Contact at(LatLng p, {double? acc, int min = 0}) => Contact(
    callsign: 'BEN',
    position: p,
    timestamp: t0.add(Duration(minutes: min)),
    accuracyMeters: acc,
    isSelf: true,
  );

  test('giriş ve çıkış uyarısı geçmişe yazılır', () {
    move(at(outside));
    expect(c.read(geofenceProvider).inside['a'], isFalse);
    expect(c.read(geofenceProvider).latest, isEmpty);
    move(at(inside, min: 1));
    var s = c.read(geofenceProvider);
    expect(s.latest.single.entered, isTrue);
    expect(s.latest.single.name, 'ALAN-1');
    move(at(outside, min: 2));
    s = c.read(geofenceProvider);
    expect(s.latest.single.entered, isFalse);
    expect(s.history.map((e) => e.entered), [true, false]);
    c.read(geofenceProvider.notifier).clearHistory();
    expect(c.read(geofenceProvider).history, isEmpty);
    expect(c.read(geofenceProvider).inside['a'], isFalse);
  });

  test('kötü doğruluklu konum yok sayılır', () {
    move(at(outside, acc: 10));
    move(at(inside, acc: 120, min: 1));
    expect(c.read(geofenceProvider).latest, isEmpty);
    expect(c.read(geofenceProvider).inside['a'], isFalse);
    move(at(inside, acc: 20, min: 2));
    expect(c.read(geofenceProvider).latest.single.entered, isTrue);
  });

  test('geçmiş en çok ${GeofenceState.maxHistory} uyarı tutar', () {
    move(at(outside));
    for (var i = 1; i <= 40; i++) {
      move(at(i.isOdd ? inside : outside, min: i));
    }
    final h = c.read(geofenceProvider).history;
    expect(h, hasLength(GeofenceState.maxHistory));
    // En yeni sonda.
    expect(h.last.at, t0.add(const Duration(minutes: 40)));
  });
}
