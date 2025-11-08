import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Store high priority notification IDs for alarm management
  static final Set<int> _alarmNotifications = <int>{};

  static Future<void> onDidReceiveBackgroundNotification(
      NotificationResponse notificationResponse) async {
    // Handle notification responses here
    String? actionId = notificationResponse.actionId;
    int notificationId = notificationResponse.id ?? 0;

    if (actionId == 'dismiss') {
      await cancelNotification(notificationId);
    } else if (actionId == 'snooze') {
      // Snooze for 5 minutes
      await snoozeNotification(notificationId, 5);
    } else if (actionId == 'stop_alarm') {
      await stopAlarm(notificationId);
    }
  }

  static Future<void> init() async {
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings("@mipmap/ic_launcher");

    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true, // For high priority alarms
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotification,
      onDidReceiveNotificationResponse: onDidReceiveBackgroundNotification,
    );

    // Get Android-specific implementation
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // Request basic notification permission
      await androidImplementation.requestNotificationsPermission();

      // Request exact alarm permission for high priority notifications (Android 12+)
      await androidImplementation.requestExactAlarmsPermission();

      // Request full screen intent permission for alarm-style notifications
      await androidImplementation.requestFullScreenIntentPermission();
    }
  }

  static NotificationDetails _getNotificationDetails(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            "high_priority_channel",
            "High Priority Tasks",
            channelDescription: "Critical task notifications with alarm",
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(
                'alarm_sound'), // Custom alarm sound
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            ongoing: true, // Makes notification persistent
            autoCancel: false, // Prevents auto-dismiss
            timeoutAfter: null, // Never timeout
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction('stop_alarm', 'Stop Alarm',
                  showsUserInterface: true),
              AndroidNotificationAction('snooze', 'Snooze 5min'),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'alarm_sound.aiff', // Custom alarm sound
            interruptionLevel: InterruptionLevel.critical,
            categoryIdentifier: 'high_priority_category',
          ),
        );

      case 'MEDIUM':
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            "medium_priority_channel",
            "Medium Priority Tasks",
            channelDescription: "Important task notifications",
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
            fullScreenIntent: false,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction('dismiss', 'Dismiss'),
              AndroidNotificationAction('snooze', 'Snooze 5min'),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        );

      case 'LOW':
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            "low_priority_channel",
            "Low Priority Tasks",
            channelDescription: "Low priority task notifications",
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            enableVibration: false,
            playSound: true,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction('dismiss', 'Dismiss'),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.passive,
          ),
        );

      case 'NONE':
      default:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            "none_priority_channel",
            "Reminders",
            channelDescription: "General reminders",
            importance: Importance.low,
            priority: Priority.low,
            enableVibration: false,
            playSound: false,
            showWhen: true,
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction('dismiss', 'Dismiss'),
            ],
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: false,
            interruptionLevel: InterruptionLevel.passive,
          ),
        );
    }
  }

  static Future<int> showScheduledNotification(
      String title, String body, DateTime scheduleDate, String priority) async {
    final int notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    final NotificationDetails platformChannelSpecific =
        _getNotificationDetails(priority);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(scheduleDate, tz.local),
      platformChannelSpecific,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: priority == 'HIGH'
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.exact,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );

    // Track high priority notifications for alarm management
    if (priority.toUpperCase() == 'HIGH') {
      _alarmNotifications.add(notificationId);
      // Schedule repeating notifications every 30 seconds for high priority
      _scheduleRepeatingAlarm(notificationId, title, body, scheduleDate);
    }

    return notificationId;
  }

  // Schedule repeating alarm notifications for high priority tasks
  static Future<void> _scheduleRepeatingAlarm(
      int baseId, String title, String body, DateTime originalTime) async {
    // Schedule up to 10 repeating notifications (5 minute alarm duration)
    for (int i = 1; i <= 10; i++) {
      final int repeatId = baseId + (i * 100000); // Unique ID for each repeat
      final DateTime repeatTime = originalTime.add(Duration(seconds: 30 * i));

      await flutterLocalNotificationsPlugin.zonedSchedule(
        repeatId,
        "🚨 URGENT: $title",
        body,
        tz.TZDateTime.from(repeatTime, tz.local),
        _getNotificationDetails('High'),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );

      _alarmNotifications.add(repeatId);
    }
  }

  static Future<void> stopAlarm(int notificationId) async {
    // Cancel the main notification and all repeating alarms
    await cancelNotification(notificationId);

    // Cancel all related repeating notifications
    for (int i = 1; i <= 10; i++) {
      int repeatId = notificationId + (i * 100000);
      await cancelNotification(repeatId);
    }

    _alarmNotifications.removeWhere((id) =>
        id == notificationId ||
        (id > notificationId && id < notificationId + 1000000));
  }

  static Future<void> snoozeNotification(
      int notificationId, int minutes) async {
    // Cancel current notification
    await cancelNotification(notificationId);

    // Reschedule for later
    final DateTime snoozeTime = DateTime.now().add(Duration(minutes: minutes));

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      "⏰ Snoozed Reminder",
      "Your task reminder is back!",
      tz.TZDateTime.from(snoozeTime, tz.local),
      _getNotificationDetails('Medium'),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelNotification(int notificationId) async {
    await flutterLocalNotificationsPlugin.cancel(notificationId);
    _alarmNotifications.remove(notificationId);
    print("Cancelled notification with ID: $notificationId");
  }

  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    _alarmNotifications.clear();
    print("Cancelled all notifications");
  }

  // Helper method to create notification with priority
  static Future<int> scheduleTaskNotification({
    required String title,
    required String body,
    required DateTime scheduleDate,
    required String priority,
  }) async {
    return await showScheduledNotification(title, body, scheduleDate, priority);
  }
}
