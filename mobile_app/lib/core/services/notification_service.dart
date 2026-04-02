import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  final _storage = const FlutterSecureStorage();

  String? _currentUserId;
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

    // 1.1 Set Foreground Presentation Options (Crucial for avoiding double-notifications)
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // 1.2 Load Current User ID for Filtering
    _currentUserId = await _storage.read(key: 'user_id');
    if (kDebugMode) print("🔔 Initialized Notification Service for User: $_currentUserId");

    // 2. Setup Local Notifications (for Foreground display)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'FLUTTER_NOTIFICATION_CLICK',
          actions: [],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.allowAnnouncement,
          },
        ),
      ],
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
        print("🔔 [FOREGROUND] Received message: ${message.messageId}");
        print("🔔 [FOREGROUND] Data: ${message.data}");
        print("🔔 [FOREGROUND] Notification: ${message.notification?.title}");
      }

      final notification = message.notification;
      final data = message.data;
      
      // A. EXCLUDE SELF-NOTIFICATIONS
      final senderId = data['sender_id']?.toString();
      if (senderId != null && _currentUserId != null && senderId == _currentUserId) {
        if (kDebugMode) print("🔔 [FOREGROUND] Skipping self-notification from sender: $senderId");
        return; 
      }
      
      String title = notification?.title ?? data['title'] ?? 'New Message';
      String body = notification?.body ?? data['body'] ?? data['text'] ?? '';

      // B. AVOID DOUBLE-NOTIFY
      // If there's a notification object, the OS (via setForegroundNotificationPresentationOptions) 
      // already handles the alert. We only show a manual local notification if there is DATA ONLY.
      if (notification != null) {
        if (kDebugMode) print("🔔 [FOREGROUND] OS is handling the 'notification' block. Skipping manual show.");
        return;
      }

      if (kDebugMode) print("🔔 [FOREGROUND] Showing Local Notification: $title - $body");

      _localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(data),
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
      await _firebaseMessaging.subscribeToTopic('global');
      if (kDebugMode) print("🔔 Successfully subscribed to 'community_chat' and 'global' topics");
    } catch (e) {
      if (kDebugMode) print("❌ Error subscribing to topics: $e");
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
