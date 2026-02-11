import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

/// Service wrapper for Push Notifications (FCM) and Local Notifications.
///
/// **Functionality:**
/// - Initializes Firebase Messaging.
/// - Requests User Permissions (iOS).
/// - Configures Local Notifications (for foreground display).
/// - Listens for incoming messages in Foreground/Background.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initializes the Notification Service.
  /// 1. Requests permissions.
  /// 2. Sets up Local Notification channels (Android).
  /// 3. Listens for foreground messages.
  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Request Permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) print('User granted permission');
    } else {
      if (kDebugMode) print('User declined or has not accepted permission');
      return; 
    }

    // 2. Initialize Local Notifications (for displaying foreground notifications)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(initializationSettings);

    // 3. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
      }

      if (message.notification != null) {
        // Show local notification
        _showLocalNotification(message);
      }
    });

    // 4. Handle Background/Terminated Messages (Data Only or Notification)
    // Firebase Messaging handles notification display automatically in background
    // for standard notification messages.

    _isInitialized = true;
  }
  
  /// Retrieves the FCM Device Token for backend targeting.
  Future<String?> getDeviceToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Displays a Local Notification when the app is in the foreground.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel_id',
            'Default Channel',
            channelDescription: 'Main channel for app notifications',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            onlyAlertOnce: true, // Prevent re-sounding on updates
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }
}

