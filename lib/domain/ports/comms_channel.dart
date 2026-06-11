import '../models/contact.dart';

/// Dışarıyla mesaj/waypoint paylaşım kanalı soyutlaması (§4.2).
///
/// v1'de gerçek bir ağ yoktur; bu yüzden implementasyon ya hiçbir şey yapmaz
/// (`NullCommsChannel`) ya da yerel paylaşım yapar (clipboard/SMS — sonraki
/// adımlar). Faz 2'de `MeshCommsChannel` Meshtastic üzerinden metin ve
/// waypoint mesajları taşır.
///
/// Uygulama katmanı bu arayüzü kullanır; kanalın gerçekte mesh mi, no-op mu
/// olduğunu bilmez.
abstract interface class CommsChannel {
  /// Kanalın kullanıma hazır olup olmadığı (ör. mesh düğümü bağlı mı).
  bool get isAvailable;

  /// Düz metin taktik mesaj gönderir.
  Future<void> sendText(String text);

  /// Bir konumu (waypoint) paylaşır.
  Future<void> shareWaypoint(Contact waypoint);

  /// Gelen düz metin mesajları akışı. v1 no-op implementasyonunda boş kalır.
  Stream<String> get incomingText;
}
