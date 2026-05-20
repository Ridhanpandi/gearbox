import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzData;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    // ── Fix: set device's actual local timezone ──
    tzData.initializeTimeZones();
    String timeZoneName;
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final raw = timezoneInfo.toString();
      // Extract IANA timezone from the raw string
      if (raw.contains('Asia/') || raw.contains('America/') ||
          raw.contains('Europe/') || raw.contains('Pacific/') ||
          raw.contains('Africa/') || raw.contains('Australia/')) {
        timeZoneName = raw.replaceAll(RegExp(r'[()]'), '').trim().split(' ').last;
      } else {
        timeZoneName = 'Asia/Kolkata'; // fallback for India
      }
    } catch (e) {
      timeZoneName = 'Asia/Kolkata'; // fallback
    }
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> scheduleReminder({
    required int id,
    required String vehicleNumber,
    required String serviceName,
    required DateTime scheduledDateTime,
  }) async {
    await init();

    // ── Fix: if scheduled time already passed today, skip ──
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);
    if (scheduled.isBefore(now)) return;

    const androidDetails = AndroidNotificationDetails(
      'service_reminders',
      'Service Reminders',
      channelDescription: 'Vehicle service due notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    await _plugin.zonedSchedule(
      id,
      '🔧 Service Due: $vehicleNumber',
      '$serviceName is scheduled for today!',
      scheduled,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static Future<void> showInstant({
    required String title,
    required String body,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'service_reminders',
      'Service Reminders',
      channelDescription: 'Vehicle service due notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}