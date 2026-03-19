import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mobile_app/core/services/admin_api_service.dart';
import '../../main.dart'; // Global Navigator Key
import '../../features/chat/chat_screen.dart';
import '../../features/chat/community_chat_screen.dart';

// 1. TOP-LEVEL BACKGROUND HANDLER
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
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

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      if (kDebugMode) print('User declined or has not accepted permission');
      return;
    }

    // 2. Setup Local Notifications (for Foreground display)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle foreground notification tap
        if (response.payload != null) {
           try {
             final data = jsonDecode(response.payload!);
             _handleNotificationData(data);
           } catch (e) {
             if (kDebugMode) print("Error parsing notification payload: $e");
           }
        }
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
      if (kDebugMode) {
        print("🔔 Received foreground message: ${message.messageId}");
        print("🔔 Message Data: ${message.data}");
        if (message.from != null) print("🔔 Message From: ${message.from}");
      }

      // If app is in foreground, Firebase doesn't show notification automatically.
      // We must show it manually using Local Notifications.
      // Note: topic messages on Android can arrive with notification == null,
      // so we always fall back to data fields.
      final notification = message.notification;
      final String title = notification?.title 
          ?? (message.data['type'] == 'community_chat' 
              ? 'Community Chat: ${message.data['sender_name'] ?? 'New message'}' 
              : 'Message from ${message.data['sender_name'] ?? 'Someone'}');
      final String body = notification?.body 
          ?? message.data['text']
          ?? 'You have a new message';

      _localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data), // Pass data payload for tap handling
      );
    });

    // 6. Get FCM Token (Send this to your Django Backend)
    String? token;
    
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // On iOS, we MUST wait for the APNs token before getting the FCM token
      // Otherwise FCM may return an invalid/empty registration token.
      String? apnsToken = await _firebaseMessaging.getAPNSToken();
      if (apnsToken == null) {
        if (kDebugMode) print("🔔 Waiting for APNs token...");
        // Wait a bit and retry up to 3 times
        for (int i = 0; i < 3; i++) {
           await Future.delayed(const Duration(seconds: 2));
           apnsToken = await _firebaseMessaging.getAPNSToken();
           if (apnsToken != null) break;
        }
      }
      if (kDebugMode) print("🔔 APNs Token: $apnsToken");
    }

    token = await _firebaseMessaging.getToken();
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

    // 7. Subscribe to Community Topic
    // Add a small delay for iOS to ensure token is synced before subscription
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
       await Future.delayed(const Duration(seconds: 1));
    }
    try {
      await _firebaseMessaging.subscribeToTopic('community_chat');
      if (kDebugMode) print("🔔 Successfully subscribed to 'community_chat' topic");
    } catch (e) {
      if (kDebugMode) print("❌ Error subscribing to community_chat topic: $e");
    }
    
    _isInitialized = true;
  }

  /// Sets up interactions for Background and Terminated states.
  Future<void> _setupInteractedMessage() async {
    // 1. Terminated State
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // 2. Background State
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    _handleNotificationData(message.data);
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    if (kDebugMode) print("🔔 Notification Data: $data");
    
    // Normalize data keys (background messages sometimes come as Map<Object?, Object?>)
    final params = Map<String, dynamic>.from(data);

    if (params['type'] == 'chat_message') {
       final conversationId = int.tryParse(params['conversation_id']?.toString() ?? '');
       final recipientId = int.tryParse(params['sender_id']?.toString() ?? ''); 
       final name = params['sender_name']?.toString() ?? 'Chat';

       if (conversationId != null) {
           // Navigate to Chat Screen using Global Key
           navigatorKey.currentState?.push(
             MaterialPageRoute(
               builder: (_) => ChatScreen(
                 conversationId: conversationId,
                 recipientId: recipientId,
                 recipientName: name, 
               ),
             ),
           );
       }
    } else if (params['type'] == 'community_chat') {
       // Navigate to Community Chat
       navigatorKey.currentState?.push(
         MaterialPageRoute(
           builder: (_) => const CommunityChatScreen(),
         ),
       );
    }
  }

  /// Forces a token sync with the backend.
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
