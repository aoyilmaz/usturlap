import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/data/db/app_database.dart';
import 'package:usturlap/domain/models/map_graphic.dart';
import 'package:usturlap/domain/ports/alert_output.dart';
import 'package:usturlap/providers/alert_providers.dart';
import 'package:usturlap/providers/background_location_providers.dart';
import 'package:usturlap/providers/graphic_providers.dart';
import 'package:usturlap/providers/location_providers.dart';
import 'package:usturlap/providers/track_providers.dart';
import 'package:usturlap/providers/waypoint_providers.dart';
import 'package:latlong2/latlong.dart';

class _FakeSpeaker implements Speaker {
  final said = <String>[];
  @override
  Future<void> speak(String text) async => said.add(text);
}

class _FakeNotifications implements AlertNotifications {
  final shown = <(int, String, String)>[];
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> show(int id, String title, String body) async =>
      shown.add((id, title, body));
}

class _Recording extends RecordingNotifier {
  _Recording(this._on);
  final bool _on;
  @override
  RecordingState build() => RecordingState(isRecording: _on, trackId: 1);
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

/// Sesli uyarılar ve bildirimler; arka plan konumu kararı.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('konuşma biçimleri: ad, mesafe, süre', () {
    expect(spokenName('ALAN-1'), 'ALAN 1');
    expect(spokenName('KN_2'), 'KN 2');
    expect(spokenDistance(850.4), '850 metre');
    expect(spokenDistance(1234), '1,2 kilometre');
    expect(spokenDistance(15600), '16 kilometre');
    expect(spokenDuration(const Duration(seconds: 45)), '45 saniye');
    expect(spokenDuration(const Duration(minutes: 4, seconds: 20)), '4 dakika');
    expect(
      spokenDuration(const Duration(hours: 1, minutes: 10)),
      '1 saat 10 dakika',
    );
    expect(spokenDuration(const Duration(hours: 2)), '2 saat');
  });

  test('önde sesli okur; ses kapalıysa susar; arka planda bildirim', () async {
    final speaker = _FakeSpeaker();
    final notes = _FakeNotifications();
    var foreground = true;
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        speakerProvider.overrideWithValue(speaker),
        alertNotificationsProvider.overrideWithValue(notes),
        appForegroundProvider.overrideWithValue(() => foreground),
      ],
    );
    addTearDown(c.dispose);
    c.listen(voiceAlertsProvider, (_, _) {});
    await _settle();
    final alerts = c.read(alertDispatcherProvider);

    alerts.alert(
      title: 'Rota',
      body: 'KN1 geçildi · 1.2 km',
      speech: 'KN 1 geçildi.',
    );
    expect(speaker.said, ['KN 1 geçildi.']);
    expect(notes.shown, isEmpty);

    c.read(voiceAlertsProvider.notifier).set(false);
    alerts.alert(title: 'Rota', body: 'x', speech: 'y');
    expect(speaker.said, hasLength(1));

    foreground = false;
    alerts.alert(title: 'Geofence: ALAN-1', body: 'Alana girildi (14:32)');
    alerts.alert(title: 'Geofence: ALAN-1', body: 'Alandan çıkıldı (14:40)');
    expect(notes.shown, [
      (1, 'Geofence: ALAN-1', 'Alana girildi (14:32)'),
      (2, 'Geofence: ALAN-1', 'Alandan çıkıldı (14:40)'),
    ]);

    // Ayar kalıcı.
    await _settle();
    final again = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(again.dispose);
    again.listen(voiceAlertsProvider, (_, _) {});
    await _settle();
    expect(again.read(voiceAlertsProvider), isFalse);
  });

  test(
    'arka plan konumu: iz kaydı ya da arka planda izlenen geofence',
    () async {
      MapGraphic fence(GeofenceTrigger? t) => MapGraphic(
        uid: 'a',
        name: 'ALAN-1',
        type: GraphicType.area,
        points: const [LatLng(39, 32), LatLng(39, 33), LatLng(40, 33)],
        colorValue: 0xFFFF0000,
        createdAt: DateTime.utc(2026, 11, 11),
        geofence: t,
      );
      Future<ProviderContainer> make({
        required bool recording,
        required List<MapGraphic> graphics,
      }) async {
        final c = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            recordingProvider.overrideWith(() => _Recording(recording)),
            mapGraphicsProvider.overrideWith((ref) => Stream.value(graphics)),
            // Rota takibi konumu dinler; testte GPS yok.
            gpsSelfContactProvider.overrideWithValue(null),
            selfContactProvider.overrideWithValue(null),
          ],
        );
        addTearDown(c.dispose);
        c.listen(backgroundLocationNeededProvider, (_, _) {});
        c.listen(alertPermissionWantedProvider, (_, _) {});
        await _settle();
        return c;
      }

      var c = await make(recording: false, graphics: [fence(null)]);
      expect(c.read(backgroundLocationNeededProvider), isFalse);
      expect(c.read(alertPermissionWantedProvider), isFalse);

      c = await make(recording: true, graphics: const []);
      expect(c.read(backgroundLocationNeededProvider), isTrue);

      c = await make(
        recording: false,
        graphics: [fence(GeofenceTrigger.entry)],
      );
      expect(c.read(backgroundLocationNeededProvider), isTrue);
      expect(c.read(alertPermissionWantedProvider), isTrue);
      // Kullanıcı arka planda izlemeyi kapatırsa (iz kaydı yokken) kapanır.
      c.read(geofenceBackgroundProvider.notifier).set(false);
      expect(c.read(backgroundLocationNeededProvider), isFalse);
      expect(c.read(alertPermissionWantedProvider), isTrue);
      await _settle();
    },
  );
}
