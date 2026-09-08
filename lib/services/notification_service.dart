import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Lichte notificatieservice: toont een systeemmelding terwijl de app
/// open is of op de achtergrond draait (proces nog actief).
///
/// Let op: dit is GEEN echte push-notificatie. Als de app volledig is
/// afgesloten (geswiped), komt er niets binnen. Voor meldingen die ook
/// dan aankomen is een Cloud Function + Firebase Cloud Messaging nodig.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Android 13+ vereist expliciete runtime-toestemming voor meldingen
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  Future<void> show({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'taxi_app_channel',
      'Taxi app meldingen',
      channelDescription: 'Meldingen over ritten en statuswijzigingen',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
