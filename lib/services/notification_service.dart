// lib/services/notification_service.dart
// FCM 推送通知服务

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:vanguardfyp/main/router.dart';

/// 后台消息处理器（必须是顶级函数）
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 Background message received: ${message.notification?.title}');
}

/// 通知服务单例类
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Android 通知渠道
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'vanguard_high_importance',
    'Vanguard Notifications',
    description: 'Important notifications from Vanguard App',
    importance: Importance.high,
    playSound: true,
  );

  /// 初始化通知服务
  Future<void> initialize() async {
    // 0. 初始化时区数据（用于定时通知）
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    // 1. 请求通知权限
    await _requestPermission();

    // 2. 设置后台消息处理器
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. 初始化本地通知（用于前台显示）
    await _initLocalNotifications();

    // 4. 创建 Android 通知渠道
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 5. 设置前台通知显示选项
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 6. 监听前台消息
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 7. 监听通知点击
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 8. 检查是否通过通知启动 App
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    debugPrint('✅ NotificationService initialized');
  }

  /// 请求通知权限
  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('📱 Notification permission status: ${settings.authorizationStatus}');
  }

  /// 初始化本地通知插件
  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleLocalNotificationTap(response.payload);
      },
    );
  }

  /// 处理前台消息
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 Foreground message received: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // 显示本地通知
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['route'], // 可用于点击跳转
    );
  }

  /// 处理通知点击（FCM 推送通知）
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.data}');
    
    final route = message.data['route'];
    if (route != null && route.isNotEmpty) {
      _navigateToRoute(route);
    }
  }

  /// 处理本地通知点击
  void _handleLocalNotificationTap(String? payload) {
    debugPrint('👆 Local notification tapped: $payload');
    
    if (payload != null && payload.isNotEmpty) {
      _navigateToRoute(payload);
    }
  }

  /// 导航到指定路由
  void _navigateToRoute(String route) {
    try {
      // 使用 go_router 导航
      appRouter.go(route);
      debugPrint('✅ Navigated to: $route');
    } catch (e) {
      debugPrint('❌ Navigation failed: $e');
      // 如果导航失败，尝试跳转到对应的 home 页面
      if (route.startsWith('/admin')) {
        appRouter.go('/admin');
      } else if (route.startsWith('/security')) {
        appRouter.go('/security');
      } else {
        appRouter.go('/user');
      }
    }
  }

  /// 获取 FCM Token
  Future<String?> getToken() async {
    try {
      final token = await _fcm.getToken();
      debugPrint('🔑 FCM Token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      debugPrint('❌ Failed to get FCM Token: $e');
      return null;
    }
  }

  /// 保存 FCM Token 到 Firestore
  Future<void> saveTokenToFirestore(String userId) async {
    final token = await getToken();
    if (token == null) return;

    try {
      final docRef =
          FirebaseFirestore.instance.collection('accounts').doc(userId);

      // 使用 arrayUnion 避免重复添加
      await docRef.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ FCM Token saved to Firestore');
    } catch (e) {
      debugPrint('❌ Failed to save FCM Token: $e');
    }

    // 监听 Token 刷新
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM Token refreshed');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('accounts')
            .doc(user.uid)
            .update({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// 登出时移除 FCM Token
  Future<void> removeTokenOnLogout(String userId) async {
    final token = await getToken();
    if (token == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('accounts')
          .doc(userId)
          .update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
      debugPrint('✅ FCM Token removed from Firestore');
    } catch (e) {
      debugPrint('❌ Failed to remove FCM Token: $e');
    }
  }

  /// 订阅主题（可选，用于群发通知）
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
    debugPrint('📢 Subscribed to topic: $topic');
  }

  /// 取消订阅主题
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
    debugPrint('📢 Unsubscribed from topic: $topic');
  }


  /// 显示预订确认通知
  Future<void> showBookingConfirmedNotification({
    required String facilityName,
    required DateTime bookingTime,
    required int durationHours,
  }) async {
    final endTime = bookingTime.add(Duration(hours: durationHours));
    final dateStr = '${bookingTime.day}/${bookingTime.month}/${bookingTime.year}';
    final timeStr = '${bookingTime.hour.toString().padLeft(2, '0')}:00 - ${endTime.hour.toString().padLeft(2, '0')}:00';

    await _localNotifications.show(
      bookingTime.millisecondsSinceEpoch ~/ 1000, // unique ID
      'Booking Confirmed ✓',
      '$facilityName on $dateStr at $timeStr',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: '/user/bookFacility', // 点击跳转到设施预订页面
    );
    debugPrint('✅ Booking confirmed notification sent');
  }

  /// 安排预订提醒通知（预订时间前 15 分钟）
  Future<void> scheduleBookingReminder({
    required String facilityName,
    required DateTime bookingTime,
    required int durationHours,
  }) async {
    // 计算提醒时间（预订前 15 分钟）
    final reminderTime = bookingTime.subtract(const Duration(minutes: 15));
    
    // 如果提醒时间已经过了，就不安排
    if (reminderTime.isBefore(DateTime.now())) {
      debugPrint('⏰ Reminder time already passed, skipping');
      return;
    }

    final endTime = bookingTime.add(Duration(hours: durationHours));
    final timeStr = '${bookingTime.hour.toString().padLeft(2, '0')}:00 - ${endTime.hour.toString().padLeft(2, '0')}:00';

    // 使用 zonedSchedule 安排定时通知
    await _localNotifications.zonedSchedule(
      bookingTime.millisecondsSinceEpoch ~/ 1000 + 1, // unique ID (不同于确认通知)
      'Upcoming Booking ⏰',
      'Your $facilityName booking starts in 15 minutes ($timeStr)',
      _convertToTZDateTime(reminderTime),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: '/user/bookFacility', // 点击跳转到设施预订页面
    );
    
    debugPrint('⏰ Booking reminder scheduled for $reminderTime');
  }

  /// 转换 DateTime 为 TZDateTime（本地时区）
  tz.TZDateTime _convertToTZDateTime(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// 取消预订提醒（当预订被取消时调用）
  Future<void> cancelBookingReminder(DateTime bookingTime) async {
    final notificationId = bookingTime.millisecondsSinceEpoch ~/ 1000 + 1;
    await _localNotifications.cancel(notificationId);
    debugPrint('🚫 Booking reminder cancelled');
  }
}
