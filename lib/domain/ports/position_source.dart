import '../models/contact.dart';

/// Haritadaki tüm konum işaretçilerinin tek beslenme noktası (§4.1).
///
/// Harita ve HUD katmanı yalnızca bu arayüzü dinler; arkasında ne olduğunu
/// (telefon GPS'i mi, mesh ağı mı) bilmez. Böylece Faz 2'de mesh desteği
/// eklerken harita/HUD koduna dokunmadan sadece yeni bir implementasyon
/// (`MeshPositionSource`) takılabilir.
///
/// Implementasyonlar:
/// - v1: `DevicePositionSource` (telefon GPS'i — tek `Contact`, `isSelf`).
/// - Faz 2: `MeshPositionSource` (mesh düğümlerinden çoklu callsign).
abstract interface class PositionSource {
  /// Aktif konum işaretçilerinin akışı. Her yeni ölçümde güncel liste yayılır.
  /// v1'de liste tek elemanlı (kendi konumumuz) veya boştur.
  Stream<List<Contact>> get contacts;

  /// Konum dinlemeyi başlatır (izin isteme, GPS/donanım açma vb.).
  Future<void> start();

  /// Uygulama arka plandayken (ekran kapalı) de konum üretmeye devam et.
  /// İz kaydı sırasında açılır, bitince kapatılır (batarya tasarrufu).
  /// Stub/mesh kaynakları için no-op olabilir.
  Future<void> setBackgroundEnabled(bool enabled);

  /// Konum dinlemeyi durdurur ve kaynakları serbest bırakır.
  Future<void> stop();
}
