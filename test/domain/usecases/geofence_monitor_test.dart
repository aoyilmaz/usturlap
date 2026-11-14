import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/domain/usecases/geofence_monitor.dart';
import 'package:latlong2/latlong.dart';

/// G3: geofence izleyicisi — giriş / çıkış geçişleri.
void main() {
  final t0 = DateTime.utc(2026, 11, 10, 9);
  const inside = LatLng(39.5, 32.5), outside = LatLng(40.5, 33.5);

  MapGraphic square(GeofenceTrigger? trigger, {String uid = 'a'}) => MapGraphic(
    uid: uid,
    name: 'ALAN-$uid',
    type: GraphicType.area,
    points: const [
      LatLng(39, 32),
      LatLng(39, 33),
      LatLng(40, 33),
      LatLng(40, 32),
    ],
    colorValue: 0xFFFF0000,
    createdAt: t0,
    geofence: trigger,
  );

  test('ilk konum yalnız durumu belirler, uyarı üretmez', () {
    final m = GeofenceMonitor();
    expect(m.update(inside, [square(GeofenceTrigger.both)], t0), isEmpty);
    expect(m.isInside('a'), isTrue);
  });

  test('giriş ve çıkış: uyarı türüne göre', () {
    for (final (trigger, wantIn, wantOut) in [
      (GeofenceTrigger.entry, true, false),
      (GeofenceTrigger.exit, false, true),
      (GeofenceTrigger.both, true, true),
    ]) {
      final m = GeofenceMonitor();
      final g = [square(trigger)];
      m.update(outside, g, t0);
      final enter = m.update(inside, g, t0);
      expect(enter.isNotEmpty, wantIn, reason: '$trigger giriş');
      if (wantIn) {
        expect(enter.single.entered, isTrue);
        expect(enter.single.name, 'ALAN-a');
      }
      // İçeride kalmak yeni uyarı üretmez.
      expect(m.update(inside, g, t0), isEmpty);
      final leave = m.update(outside, g, t0);
      expect(leave.isNotEmpty, wantOut, reason: '$trigger çıkış');
      if (wantOut) expect(leave.single.entered, isFalse);
    }
  });

  test('uyarısız şekiller ve çizgiler izlenmez', () {
    final m = GeofenceMonitor();
    final line = MapGraphic(
      uid: 'l',
      name: 'HAT',
      type: GraphicType.line,
      points: const [LatLng(39, 32), LatLng(40, 33)],
      colorValue: 0xFFFF0000,
      createdAt: t0,
      geofence: GeofenceTrigger.both,
    );
    m.update(outside, [square(null), line], t0);
    expect(m.update(inside, [square(null), line], t0), isEmpty);
    expect(m.snapshot, isEmpty);
  });

  test('daire: yarıçapla içeride / dışarıda', () {
    const center = LatLng(39, 32);
    final circle = MapGraphic(
      uid: 'c',
      name: 'DAİRE-1',
      type: GraphicType.circle,
      // Kenar ~1.11 km kuzeyde.
      points: const [center, LatLng(39.01, 32)],
      colorValue: 0xFFFF0000,
      createdAt: t0,
      geofence: GeofenceTrigger.entry,
    );
    expect(circle.contains(const LatLng(39.005, 32)), isTrue);
    expect(circle.contains(const LatLng(39.02, 32)), isFalse);
    final m = GeofenceMonitor();
    m.update(const LatLng(39.02, 32), [circle], t0);
    expect(
      m.update(const LatLng(39.005, 32), [circle], t0).single.entered,
      isTrue,
    );
  });

  test('silinen şeklin durumu unutulur; geri gelince yine ilk konum', () {
    final m = GeofenceMonitor();
    final g = square(GeofenceTrigger.both);
    m.update(outside, [g], t0);
    m.update(outside, const [], t0);
    expect(m.isInside('a'), isNull);
    // Yeniden eklenince ilk gözlem yine uyarısız.
    expect(m.update(inside, [g], t0), isEmpty);
  });
}
