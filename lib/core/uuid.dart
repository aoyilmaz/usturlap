import 'dart:math';

final Random _secure = Random.secure();

/// Rastgele UUID v4 (RFC 4122), ör. "9405e320-9356-41c4-8449-f46990aa17f8".
///
/// Her harita nesnesinin kalıcı kimliği (CoT `uid`) budur: cihazlar arası
/// paylaşımda (veri paketi, mesh) aynı nesneyi tanımak için kullanılır.
/// Paket bağımlılığı yerine `Random.secure()` ile üretilir.
String newUuidV4([Random? random]) {
  final r = random ?? _secure;
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // sürüm 4
  b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 varyantı
  final h = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
