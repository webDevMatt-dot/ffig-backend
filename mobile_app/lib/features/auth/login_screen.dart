import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../home/dashboard_screen.dart';
import 'signup_screen.dart';
import '../../core/api/constants.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/services/version_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared_widgets/moderation_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _version = "";

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _checkForUpdates();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _checkForUpdates() async {
    final updateData = await VersionService().checkUpdate();
    if (updateData != null &&
        mounted &&
        updateData['updateAvailable'] == true) {
      _showUpdateDialog(updateData);
    }
  }

  void _showUpdateDialog(Map<String, dynamic> data) {
    if (!mounted) return;
    final bool required = data['required'] ?? false;
    final String url = data['url'];
    final String version = data['latestVersion'];

    showDialog(
      context: context,
      barrierDismissible: !required,
      builder: (context) => AlertDialog(
        title: const Text("Update Available"),
        content: Text("Version $version is available."),
        actions: [
          if (!required)
            TextButton(
              child: const Text("Later"),
              onPressed: () => Navigator.pop(context),
            ),
          ElevatedButton(
            onPressed: () {
              // Cache Busting: Add timestamp to force fresh download
              final uri = Uri.parse(
                "$url?t=${DateTime.now().millisecondsSinceEpoch}",
              );
              launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    String url = '${baseUrl}auth/login/';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String accessToken = data['access'];
        final String refreshToken = data['refresh'];

        const storage = FlutterSecureStorage();
        await storage.write(key: 'access_token', value: accessToken);
        await storage.write(key: 'refresh_token', value: refreshToken);

        if (data.containsKey('is_staff')) {
          await storage.write(
            key: 'is_staff',
            value: data['is_staff'].toString(),
          );
        }

        // Moderation Checks (Block/Suspend)
        if (data['is_blocked'] == true) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  const ModerationDialog(type: ModerationType.block),
            );
          }
          return; // Stop login
        }

        if (data['is_suspended'] == true) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => ModerationDialog(
                type: ModerationType.suspend,
                message:
                    "Your account is suspended until ${data['suspension_expiry']}.",
              ),
            );
          }
          return; // Stop login
        }

        // VERIFY TOKEN WRITE (Debug Step)
        final verifyToken = await storage.read(key: 'access_token');
        if (verifyToken != accessToken) {
          throw Exception(
            "Token Storage Failed! Read-back returned: $verifyToken",
          );
        }

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
          );
        }
      } else if (response.statusCode == 401) {
        // Account might be deleted/disabled
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const ModerationDialog(type: ModerationType.delete),
        );
      } else {
        _showError("Invalid credentials.");
      }
    } catch (e) {
      _showError("Login Error: $e");
      print("Login exception: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Login Failed"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Modern "React.js" Vibe: Clean, centered, subtle gradient
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              const Color(0xFFF5F5F7), // Apple-like subtle grey
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Brand Mark (Gold)
                Container(
                  height: 64,
                  width: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FfigTheme.primaryBrown.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/images/female_founders_icon.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32),

                // 2. Headline
                Text(
                  "Welcome back.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  "Sign in to your Female Founders Initiative Global account.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 48),

                // 3. Modern Inputs
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.next, // Show "Next"
                  decoration: const InputDecoration(
                    labelText: "Email or Username",
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.go, // Show "Go" or arrow
                  onSubmitted: (_) => _login(), // Enter = Login
                  decoration: const InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 40),

                // 4. Action Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Sign In"),
                ),

                const SizedBox(height: 32),

                // 5. Links
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignUpScreen(),
                    ),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: [
                        const TextSpan(text: "No account? "),
                        TextSpan(
                          text: "Sign Up",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 6. Version Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "v$_version",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
