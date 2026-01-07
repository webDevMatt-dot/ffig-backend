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
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FfigTheme.gold,
              ),
              child: const Icon(Icons.diamond_outlined, size: 60, color: FfigTheme.matteBlack),
            ),
            const SizedBox(height: 24),
            Text(
              "Female Founders Initiative Global",
              style: FfigTheme.textTheme.displayLarge?.copyWith(
                fontSize: 40,
                letterSpacing: 2.0,
                color: FfigTheme.gold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "FEMALE FOUNDERS INITIATIVE GLOBAL",
              style: GoogleFonts.lato(
                fontSize: 12,
                letterSpacing: 1.5,
                color: Colors.grey,
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