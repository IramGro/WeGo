import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../data/models/itinerary_item.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Manejar toque en notificación si es necesario
      },
    );
  }

  Future<void> scheduleActivityReminders(ItineraryItem item) async {
    if (item.timeHHmm == null) return;

    final parts = item.timeHHmm!.split(':');
    if (parts.length != 2) return;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final activityTime = DateTime(
      item.dayDate.year,
      item.dayDate.month,
      item.dayDate.day,
      hour,
      minute,
    );

    // Definir los intervalos de recordatorio (en minutos antes)
    final intervals = [120, 60, 30];

    for (var interval in intervals) {
      final scheduledTime = activityTime.subtract(Duration(minutes: interval));

      if (scheduledTime.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: item.id.hashCode + interval,
          title: 'Próxima actividad: ${item.title}',
          body: 'Faltan ${interval == 120 ? "2 horas" : (interval == 60 ? "1 hora" : "30 minutos")} para tu actividad.',
          scheduledDate: scheduledTime,
        );
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'activity_reminders',
          'Recordatorios de Actividades',
          channelDescription: 'Notificaciones sobre tus próximas actividades en WeGo',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
