import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/ports/alert_output.dart';

/// Yerel bildirimler (flutter_local_notifications). Sunucu / internet yok:
/// bildirim cihazda üretilir. Uygulama arka plandayken geofence ve rota
/// uyarıları için.
class PluginAlertNotifications implements AlertNotifications {
  PluginAlertNotifications([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _ready;

  static const _android = AndroidNotificationDetails(
    'uyarilar',
    'Uyarılar',
    channelDescription: 'Geofence ve rota uyarıları',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<bool> _init() async {
    try {
      final ok = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // İzin açılışta değil, gerektiğinde (geofence / rota) sorulur.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('Bildirimler başlatılamadı: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!await (_ready ??= _init())) return false;
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (e) {
      debugPrint('Bildirim izni istenemedi: $e');
      return false;
    }
  }

  @override
  Future<void> show(int id, String title, String body) async {
    if (!await (_ready ??= _init())) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: _android,
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
      );
    } catch (e) {
      debugPrint('Bildirim gösterilemedi: $e');
    }
  }
}
