import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:usturlap/domain/models/contact.dart';
import 'package:usturlap/domain/ports/comms_channel.dart';
import 'package:usturlap/domain/ports/position_source.dart';
import 'package:usturlap/data/position/stub_position_source.dart';
import 'package:usturlap/data/comms/null_comms_channel.dart';

void main() {
  group('Contact', () {
    test('copyWith yalnızca verilen alanı değiştirir', () {
      final t = DateTime(2026, 1, 1);
      final c = Contact(
        callsign: 'ALFA-1',
        position: const LatLng(39.0, 32.0),
        timestamp: t,
        isSelf: true,
      );

      final moved = c.copyWith(position: const LatLng(40.0, 33.0));

      expect(moved.position, const LatLng(40.0, 33.0));
      expect(moved.callsign, 'ALFA-1'); // değişmedi
      expect(moved.isSelf, true); // değişmedi
      expect(moved.timestamp, t);
    });
  });

  group('Stub implementasyonlar arayüze uyuyor', () {
    test('StubPositionSource bir PositionSource\'tur ve boş yayar', () async {
      final PositionSource src = StubPositionSource();
      await src.start();
      expect(await src.contacts.isEmpty, true);
      await src.stop();
    });

    test('NullCommsChannel bir CommsChannel\'dır ve kullanılamaz', () async {
      final CommsChannel ch = NullCommsChannel();
      expect(ch.isAvailable, false);
      expect(await ch.incomingText.isEmpty, true);
      // no-op çağrılar hata atmamalı
      await ch.sendText('test');
    });
  });
}
