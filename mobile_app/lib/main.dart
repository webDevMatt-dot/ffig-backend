import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:overlay_support/overlay_support.dart';
import 'features/home/dashboard_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/theme/ffig_theme.dart';
import 'core/theme/theme_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/services/version_service.dart';
// import 'firebase_options.dart'; // Uncomment if you have generated firebase_options.dart using FlutterFire CLI

// Global access to theme controller (Simple dependency injection)
final themeController = ThemeController();

// Global Navigator Key for Services
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


/// Application Entry Point.
/// 
/// **Responsibilities:**
/// 1. Initialize Flutter Bindings.
/// 2. Initialize Firebase (if not on Web, or configured).
/// 3. Initialize Notification Services.
/// 4. Launch the `FFIGApp`.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // on Web, we skip Firebase unless configured (to avoid crash)
    if (!kIsWeb) {
      // Initialize Firebase. Assumes native config files (google-services.json / GoogleService-Info.plist) are present.
      await Firebase.initializeApp();
      
      // REGISTER BACKGROUND HANDLER
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Initialize Notifications
      await NotificationService().init();
    }
  } catch (e) {
    print("Firebase/Notification Init Error: $e");
  }
  runApp(const FFIGApp());
}

/// The Root Widget of the Application.
///
/// Sets up:
/// - `OverlaySupport` for in-app notifications.
/// - `MaterialApp` with global configurations.
/// - System-wide Theme (Light/Dark).
/// - Initial Route (`SplashScreen`).
class FFIGApp extends StatelessWidget {
  const FFIGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, child) {
        return OverlaySupport.global(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Female Founders Initiative Global Mobile',
            debugShowCheckedModeBanner: false,
            // Mode
            themeMode: themeController.themeMode,
            // Light
            theme: FfigTheme.lightTheme,
            // Dark (VVIP Night Mode)
            darkTheme: FfigTheme.darkTheme,
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  /// Checks for an existing session token.
  /// - If valid, navigates to `DashboardScreen` (Authenticated).
  /// - If invalid/missing, navigates to `DashboardScreen` (Guest Mode).
  Future<void> _checkSession() async {
    // Just wait for splash animation/branding
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) _navigateBasedOnToken();
  }

  Future<void> _navigateBasedOnToken() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    if (!mounted) return;

    if (token != null) {
       Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
    } else {
       Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.onInverseSurface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder for Logo
            // Logo
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Image.asset(
                'assets/images/tm_female_founders_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}