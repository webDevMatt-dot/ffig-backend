import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:overlay_support/overlay_support.dart';
import 'features/auth/login_screen.dart';
import 'features/home/dashboard_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/theme/ffig_theme.dart';
import 'core/theme/theme_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/services/version_service.dart';
// import 'firebase_options.dart'; // Uncomment if you have generated firebase_options.dart using FlutterFire CLI

// Global access to theme controller (Simple dependency injection)
final themeController = ThemeController();



  void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // on Web, we skip Firebase unless configured (to avoid crash)
    if (!kIsWeb) {
      // Initialize Firebase. Assumes native config files (google-services.json / GoogleService-Info.plist) are present.
      await Firebase.initializeApp();
       // Initialize Notifications
      await NotificationService().init();
    }
  } catch (e) {
    print("Firebase/Notification Init Error: $e");
  }
  runApp(const FFIGApp());
}

class FFIGApp extends StatelessWidget {
  const FFIGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, child) {
        return OverlaySupport.global(
          child: MaterialApp(
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

  Future<void> _checkSession() async {
    // Run Version Check and Min Delay in parallel
    final results = await Future.wait([
      Future.delayed(const Duration(seconds: 3)),
      VersionService().checkUpdate(),
    ]);

    final updateData = results[1] as Map<String, dynamic>?;

    if (mounted) {
      if (updateData != null && updateData['updateAvailable'] == true) {
        _showUpdateDialog(updateData);
      } else {
        _navigateBasedOnToken();
      }
    }
  }

  Future<void> _navigateBasedOnToken() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    if (!mounted) return;

    if (token != null) {
       Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
    } else {
       Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  void _showUpdateDialog(Map<String, dynamic> data) {
    final bool required = data['required'];
    final String url = data['url'];
    final String version = data['latestVersion'];

    showDialog(
      context: context,
      barrierDismissible: !required,
      builder: (context) => AlertDialog(
        title: const Text("Update Available"),
        content: Text("A new version ($version) is available.\nPlease update for the best experience."),
        actions: [
          if (!required)
            TextButton(
              child: const Text("Later"),
              onPressed: () {
                Navigator.pop(context);
                _navigateBasedOnToken();
              },
            ),
          ElevatedButton(
            onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            style: ElevatedButton.styleFrom(backgroundColor: FfigTheme.primaryBrown, foregroundColor: Colors.white),
            child: const Text("Update Now"),
          )
        ],
      ),
    );
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
                'assets/images/female_founders_logo_full.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "\"We don't compete,\nwe collaborate.\"",
              textAlign: TextAlign.center,
              style: GoogleFonts.dancingScript(
                fontSize: 24,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}