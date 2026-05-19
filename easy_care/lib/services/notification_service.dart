import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings: initSettings);
  }

  // 즉시 알림 테스트용
  Future<void> showNotification({required int id, required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'easy_care_channel', 
      'EasyCare 알림', 
      channelDescription: '건강 관리를 위한 알림입니다.',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  // 식후 2시간(또는 특정 시간 뒤) 알람 스케줄링
  Future<void> scheduleMealAlarm({required String mealType}) async {
    // 시연을 위해 2시간 뒤가 아닌 10초 뒤로 스케줄링하여 테스트 가능하도록 함 (실제: hours: 2)
    final scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)); 

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'meal_alarm_channel', 
      '식후 혈당 알림', 
      channelDescription: '식후 혈당 측정을 위한 알림입니다.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.zonedSchedule(
      id: 100, // 고유 ID
      title: '$mealType 식후 2시간 경과! ⏰',
      body: '정확한 관리를 위해 지금 바로 혈당을 측정해보세요.',
      scheduledDate: scheduledDate,
      notificationDetails: platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    
    debugPrint("Scheduled alarm for $mealType at $scheduledDate");
  }
}
