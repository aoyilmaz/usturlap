import 'package:flutter_test/flutter_test.dart';
import 'package:usturlap/core/bearing_format.dart';
import 'package:usturlap/domain/models/bloodhound.dart';
import 'package:usturlap/domain/models/range_line.dart';
import 'package:usturlap/features/nav/bloodhound_panel.dart';
import 'package:latlong2/latlong.dart';

/// E4: çoklu Bloodhound — ETA, eşikler, renk.
void main() {
  const a = LatLng(37.0, 37.0);
  const b = LatLng(37.01, 37.0); // ≈ 1112 m kuzey

  group('EtaThresholds', () {
    const t = EtaThresholds(); // sarı 15, kırmızı 5 dk
    test('seviye', () {
      expect(t.level(const Duration(minutes: 3)), EtaLevel.close);
      expect(t.level(const Duration(minutes: 5)), EtaLevel.close);
      expect(t.level(const Duration(minutes: 10)), EtaLevel.near);
      expect(t.level(const Duration(minutes: 16)), EtaLevel.far);
    });

    test('dakika değişince sınırlar ve sıra korunur', () {
      expect(t.withMinutes(warn: 30).warn.inMinutes, 30);
      // Kırmızı sarıya yetişirse sarı bir dk ileri gider.
      final a = t.withMinutes(alarm: 15);
      expect((a.alarm.inMinutes, a.warn.inMinutes), (15, 16));
      // Sarı kırmızının altına inerse kırmızı bir dk geri gider.
      final w = t.withMinutes(warn: 5);
      expect((w.alarm.inMinutes, w.warn.inMinutes), (4, 5));
      expect(t.withMinutes(alarm: 0).alarm.inMinutes, 1);
      expect(t.withMinutes(warn: 500).warn.inMinutes, 120);
    });

    test('JSON; bozuk kayıt varsayılan', () {
      final x = t.withMinutes(warn: 20, alarm: 7);
      final back = EtaThresholds.fromJson(x.toJson());
      expect((back.warn.inMinutes, back.alarm.inMinutes), (20, 7));
      expect(EtaThresholds.fromJson('x').warn.inMinutes, 15);
      expect(EtaThresholds.fromJson({'warn': 'a'}).alarm.inMinutes, 5);
    });
  });

  group('BloodhoundReading', () {
    test('iki sabit nokta: kerteriz ve mesafe, ETA / renk yok', () {
      final r = BloodhoundReading.of(a, b, hasSpeed: false, speedMps: 3);
      expect(r.meters, closeTo(1112, 3));
      expect(r.bearing, closeTo(0, 0.01));
      expect(r.eta, isNull);
      expect(r.level, isNull);
    });

    test('gerçek hızla ETA ve renk', () {
      final r = BloodhoundReading.of(a, b, hasSpeed: true, speedMps: 2);
      expect(r.eta!.inSeconds, closeTo(556, 2));
      expect(r.estimated, isFalse);
      expect(r.level, EtaLevel.near); // ≈ 9 dk: 5 ile 15 dk arası → sarı
    });

    test('duruyorsam yürüyüş hızıyla tahmin (~)', () {
      final r = BloodhoundReading.of(a, b, hasSpeed: true, speedMps: 0.1);
      // 4 km/s ≈ 1,11 m/s → ≈ 1000 sn ≈ 16,7 dk → yeşil.
      expect(r.eta!.inSeconds, closeTo(1001, 3));
      expect(r.estimated, isTrue);
      expect(r.level, EtaLevel.far);
    });
  });

  test('takibin hızı yalnız bir ucu bensem bilinir', () {
    final me = Bloodhound(
      id: 1,
      from: const RbEnd(a, RbEnd.selfRef),
      to: RbEnd(b, RbEnd.waypointRef('x')),
    );
    final two = Bloodhound(
      id: 2,
      from: RbEnd(a, RbEnd.waypointRef('y')),
      to: RbEnd(b, RbEnd.waypointRef('x')),
    );
    expect(me.hasSpeed, isTrue);
    expect(two.hasSpeed, isFalse);
  });

  test('metin: kerteriz · mesafe · ~süre (varış saati)', () {
    final r = BloodhoundReading.of(a, b, hasSpeed: true);
    expect(
      bloodhoundText(
        r,
        a,
        const BearingFormatter(),
        now: DateTime(2026, 1, 1, 14),
      ),
      '000° · 1.11 km · ~16 dk (14:16)',
    );
    final fixed = BloodhoundReading.of(a, b, hasSpeed: false);
    expect(
      bloodhoundText(fixed, a, const BearingFormatter()),
      '000° · 1.11 km',
    );
  });
}
