import '../../domain/models/contact.dart';
import '../../domain/ports/comms_channel.dart';

/// No-op `CommsChannel` implementasyonu (Adım 1).
///
/// Hiçbir yere bir şey göndermez, hiçbir şey almaz. v1'de gerçek bir
/// iletişim kanalı yoktur; bu stub sadece arayüzün yerine oturduğunu gösterir.
/// Faz 2'de `MeshCommsChannel` ile değiştirilecek.
class NullCommsChannel implements CommsChannel {
  @override
  bool get isAvailable => false;

  @override
  Future<void> sendText(String text) async {}

  @override
  Future<void> shareWaypoint(Contact waypoint) async {}

  @override
  Stream<String> get incomingText => const Stream<String>.empty();
}
