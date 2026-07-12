import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper over [FlutterLocalNotificationsPlugin] for showing local
/// (in-app) notifications.
///
/// StallHop deliberately has no server-side push (no Cloud Functions / FCM):
/// notifications are generated on-device from Firestore listeners, so they
/// arrive while the app is running. See [NotificationCoordinator] for the
/// listeners that decide *when* to notify.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initializes the plugin and requests notification permission
  /// (Android 13+ / iOS). Safe to call more than once.
  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    try {
      await _plugin.initialize(settings);
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _initialized = true;
    } catch (e) {
      // Notifications are a nice-to-have; never let them break app startup.
      debugPrint('NotificationService init failed: $e');
    }
  }

  /// Shows a notification. [id] should be stable per subject (e.g. derived
  /// from the order id) so repeated updates replace rather than stack.
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'stallhop_default',
        'StallHop notifications',
        channelDescription: 'Order updates and venue announcements',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('NotificationService show failed: $e');
    }
  }
}
