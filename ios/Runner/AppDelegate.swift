import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Yerel bildirimler (flutter_local_notifications): bildirim olayları
    // Flutter'a iletilsin.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IncomingFilesPlugin") {
      IncomingFilesPlugin.register(with: registrar)
    }
  }
}

/// "Usturlap ile aç" (AirDrop, Dosyalar, Mail eki — G8): gelen dosya geçici
/// klasöre kopyalanır, yolu Flutter'a iletilir (kanal: usturlap/incoming_files).
/// Flutter henüz hazır değilse (soğuk açılış) yol sırada bekler; Dart açılınca
/// "takePending" ile alır. Dosya burada açılmaz/uygulanmaz: Dart tarafı
/// önizletip onay ister.
final class IncomingFilesPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private var channel: FlutterMethodChannel?
  private var pending: [String] = []
  private var dartReady = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = IncomingFilesPlugin()
    let channel = FlutterMethodChannel(
      name: "usturlap/incoming_files", binaryMessenger: registrar.messenger())
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "takePending":
      dartReady = true
      result(pending)
      pending.removeAll()
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // Seçiciler açıkça yazıldı: Swift adlandırması değişse de çağrılsın.
  @objc(scene:willConnectToSession:options:)
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let contexts = connectionOptions?.urlContexts, !contexts.isEmpty else {
      return false
    }
    contexts.forEach { receive($0.url) }
    return true
  }

  @objc(scene:openURLContexts:)
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    URLContexts.forEach { receive($0.url) }
    return !URLContexts.isEmpty
  }

  private func receive(_ url: URL) {
    guard url.isFileURL, let path = copyToTemp(url) else { return }
    if dartReady, let channel = channel {
      channel.invokeMethod("open", arguments: path)
    } else {
      pending.append(path)
    }
  }

  /// Dosyayı (yerinde açılan / iCloud dosyası da olabilir) geçici klasöre
  /// kopyalar. AirDrop / Mail'in Belgeler/Inbox kopyası silinir.
  private func copyToTemp(_ url: URL) -> String? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let fm = FileManager.default
    let dir = fm.temporaryDirectory
      .appendingPathComponent("gelen", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    do {
      try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    } catch {
      return nil
    }
    let name = url.lastPathComponent.isEmpty ? "dosya" : url.lastPathComponent
    let target = dir.appendingPathComponent(name)
    var copyError: Error?
    var coordError: NSError?
    NSFileCoordinator().coordinate(
      readingItemAt: url, options: .withoutChanges, error: &coordError
    ) { readURL in
      do {
        try fm.copyItem(at: readURL, to: target)
      } catch {
        copyError = error
      }
    }
    if coordError != nil || copyError != nil { return nil }
    if url.path.contains("/Documents/Inbox/") {
      try? fm.removeItem(at: url)
    }
    return target.path
  }
}
