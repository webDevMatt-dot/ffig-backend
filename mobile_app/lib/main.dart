import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:overlay_support/overlay_support.dart';
import 'features/auth/login_screen.dart';
import 'core/theme/ffig_theme.dart';
import 'core/theme/theme_controller.dart';

// Global access to theme controller (Simple dependency injection)
final themeController = ThemeController();

void main() {
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
  void initState() {
    super.initState();
    // Simulate checking for a Django Token, then navigate
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const LoginScreen())
      );
    });
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