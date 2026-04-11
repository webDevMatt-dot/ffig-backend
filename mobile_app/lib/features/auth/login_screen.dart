import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../home/dashboard_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import '../../core/theme/ffig_theme.dart';
import '../../shared_widgets/moderation_dialog.dart';
import '../../core/api/django_api_client.dart';

/// The Main Authentication Entry Point.
///
/// **Features:**
/// - User Login (Email/Username & Password).
/// - Secure Token Storage (`access`, `refresh`) via `FlutterSecureStorage`.
/// - Optional "Remember me" credential autofill on this device.
/// - Admin Status Check (`is_staff`).
/// - Account Moderation Checks (Block/Suspend).
/// - Version Display.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _rememberMeKey = 'remember_me';
  static const String _rememberedUsernameKey = 'remembered_username';
  static const String _rememberedPasswordKey = 'remembered_password';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiClient = DjangoApiClient();
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String _version = "";

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadRememberedCredentials();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _loadRememberedCredentials() async {
    final rememberValue = await _storage.read(key: _rememberMeKey);
    final shouldRemember = rememberValue == 'true';
    if (!shouldRemember) return;

    final savedUsername = await _storage.read(key: _rememberedUsernameKey) ?? '';
    final savedPassword = await _storage.read(key: _rememberedPasswordKey) ?? '';

    if (!mounted) return;
    setState(() {
      _rememberMe = true;
      _emailController.text = savedUsername;
      _passwordController.text = savedPassword;
    });
  }

  Future<void> _persistRememberMe() async {
    await _storage.write(key: _rememberMeKey, value: _rememberMe.toString());
    if (_rememberMe) {
      await _storage.write(key: _rememberedUsernameKey, value: _emailController.text.trim());
      await _storage.write(key: _rememberedPasswordKey, value: _passwordController.text);
    } else {
      await _storage.delete(key: _rememberedUsernameKey);
      await _storage.delete(key: _rememberedPasswordKey);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Authenticates the user with the backend.
  /// - Validates credentials.
  /// - Stores tokens and user roles securely.
  /// - Performs Moderation Checks:
  ///   - **Blocked:** Shows `ModerationDialog` (blocking) and prevents login.
  ///   - **Suspended:** Shows `ModerationDialog` with expiry date.
  /// - Navigates to `DashboardScreen` on success.
  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      final raw = await _apiClient.post(
        'auth/login/',
        requiresAuth: false,
        retryEnabled: false,
        data: {
          'username': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        },
      );

      if (raw is Map<String, dynamic>) {
        final data = raw;
        final String accessToken = data['access'];
        final String refreshToken = data['refresh'];

        await _apiClient.saveAuthTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        if (data.containsKey('is_staff')) {
          await _storage.write(
            key: 'is_staff',
            value: data['is_staff'].toString(),
          );
        }

        if (data.containsKey('user_id')) {
          await _storage.write(
            key: 'user_id',
            value: data['user_id'].toString(),
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
        final verifyToken = await _storage.read(key: 'access_token');
        if (verifyToken != accessToken) {
          throw Exception(
            "Token Storage Failed! Read-back returned: $verifyToken",
          );
        }

        await _persistRememberMe();

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
            (route) => false,
          );
        }
      } else {
        _showError("Unexpected server response. Please try again.");
      }
    } on DjangoApiException catch (e) {
      if (e.statusCode == 401) {
        _showError("Invalid credentials. Please check your username and password.");
      } else {
        _showError(e.message);
      }
      debugPrint("Login API exception: $e");
    } catch (e) {
      _showError("Unable to sign in right now. Please check your internet connection and try again.");
      debugPrint("Login exception: $e");
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
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.go, // Show "Go" or arrow
                  onSubmitted: (_) => _login(), // Enter = Login
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() => _rememberMe = value ?? false);
                      },
                    ),
                    const Expanded(
                      child: Text(
                        "Remember me on this device",
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

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
                        TextSpan(
                          text: "No account? ",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
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
