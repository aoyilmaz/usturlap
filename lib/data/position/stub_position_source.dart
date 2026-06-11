import '../../domain/models/contact.dart';
import '../../domain/ports/position_source.dart';

/// Geçici, boş `PositionSource` implementasyonu (Adım 1).
///
/// Hiç konum yaymaz; sadece arayüzün derlenip uygulamaya bağlanabildiğini
/// gösterir. Gerçek GPS okuması Adım 3'te `DevicePositionSource` ile gelecek.
class StubPositionSource implements PositionSource {
  @override
  Stream<List<Contact>> get contacts => const Stream<List<Contact>>.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> setBackgroundEnabled(bool enabled) async {}

  @override
  Future<void> stop() async {}
}
