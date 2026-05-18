import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Kısa bilgilendirme bildirimleri (rota uyarısı vb.).
class LocalNotifyService {
  LocalNotifyService._();
  static final LocalNotifyService instance = LocalNotifyService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  Future<void> _ensureAndroidPostPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  /// Anında tek bildirim gösterir (kanal: `safeher_route`).
  Future<void> showImmediate({
    required String title,
    required String body,
    int id = 91001,
  }) async {
    await init();
    await _ensureAndroidPostPermission();

    const android = AndroidNotificationDetails(
      'safeher_route',
      'Rota uyarıları',
      channelDescription: 'Güvenli yol planı ve güvensiz bölge hatırlatmaları',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: android, iOS: ios),
    );
  }
}
