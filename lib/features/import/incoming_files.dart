import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// "Kerteriz ile aç" (G8): AirDrop / Dosyalar / Mail'den gelen dosyaların
/// yolları. iOS tarafı dosyayı geçici klasöre kopyalar
/// (`ios/Runner/AppDelegate.swift` IncomingFilesPlugin); burada yalnız yol
/// alınır, dosya önizletilip onaylanmadan hiçbir şey eklenmez.
class IncomingFiles {
  IncomingFiles._();

  static const _channel = MethodChannel('kerteriz/incoming_files');

  /// [onFile] her gelen dosya için sırayla çağrılır; uygulama kapalıyken
  /// gelenler (soğuk açılış) hemen işlenir.
  static Future<void> listen(Future<void> Function(String path) onFile) async {
    _channel.setMethodCallHandler((call) async {
      final path = call.arguments;
      if (call.method == 'open' && path is String) await onFile(path);
    });
    try {
      final pending = await _channel.invokeListMethod<String>('takePending');
      for (final p in pending ?? const <String>[]) {
        await onFile(p);
      }
    } on MissingPluginException {
      // Test / desteklenmeyen platform.
    } on PlatformException catch (e) {
      debugPrint('Gelen dosyalar alınamadı: $e');
    }
  }

  static void stop() => _channel.setMethodCallHandler(null);
}
