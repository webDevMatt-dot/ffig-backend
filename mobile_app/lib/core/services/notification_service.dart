import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_app/core/services/admin_api_service.dart';

// 1. TOP-LEVEL BACKGROUND HANDLER
// This must be outside of any class. It runs in a separate isolate when app is closed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // You can also show a local notification here if needed, 
  // but usually Firebase handles "notification" payloads automatically.
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Request Permission
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

    // 2. Setup Local Notifications (for Foreground display)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Ensure this icon exists

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap logic here
        if (kDebugMode) print("Notification tapped: ${response.payload}");
      },
    );

    // 3. Create Android Channel (High Importance for Heads-up)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.', // description
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. Foreground Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // If app is in foreground, Firebase doesn't show notification automatically.
      // We must show it manually using Local Notifications.
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    // 5. Get FCM Token (Send this to your Django Backend)
    String? token = await _firebaseMessaging.getToken();
    if (kDebugMode) print("FCM Token: $token");
    
    // Send to Backend
    if (token != null) {
      print("🔔 FCM Token retrieved. Sending to backend...");
      await AdminApiService().updateFCMToken(token);
    }
    
    // Listen for Token Refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print("🔔 FCM Token Refreshed. Sending new token to backend...");
      AdminApiService().updateFCMToken(newToken);
    });
    
    _isInitialized = true;
  }

  /// Forces a token sync with the backend.
  /// user-initiated or post-login.
  Future<void> forceTokenSync() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print("🔔 Forcing FCM Token Sync...");
        await AdminApiService().updateFCMToken(token);
      }
    } catch (e) {
      print("Error forcing token sync: $e");
    }
  }
}
