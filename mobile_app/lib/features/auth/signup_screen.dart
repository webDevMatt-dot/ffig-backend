import 'dart:convert';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'email_verification_screen.dart';
import '../../core/api/constants.dart';

/// The User Registration Screen.
///
/// **Features:**
/// - Registration Form (Name, Username, Email, Password).
/// - Industry Selection (with "Other" text field).
/// - Sends registration data to backend.
/// - Redirects to Login on success.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fNameController = TextEditingController();
  final _lNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _industryOtherController = TextEditingController();
  final _countryController = TextEditingController();
  bool _isLoading = false;
  String _selectedIndustry = 'OTH';

  final Map<String, String> _industryChoices = {
    'TECH': 'Technology',
    'FIN': 'Finance',
    'HLTH': 'Healthcare',
    'RET': 'Retail',
    'EDU': 'Education',
    'MED': 'Media & Arts',
    'LEG': 'Legal',
    'FASH': 'Fashion',
    'MAN': 'Manufacturing',
    'OTH': 'Other',
  };

  /// Submits the registration form to the backend.
  /// - Validates passwords match.
  /// - Ensures Industry "Other" field is filled if selected.
  /// - Handles successful creation (201) by showing snackbar and popping.
  /// - Displays errors on failure.
  Future<void> _register() async {
    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();

    // 1. Basic Validation
    if (_passwordController.text != _confirmController.text) {
      _showError("Passwords do not match");
      setState(() => _isLoading = false);
      return;
    }

    if (_selectedIndustry == 'OTH' &&
        _industryOtherController.text.trim().isEmpty) {
      _showError("Please specify your industry.");
      setState(() => _isLoading = false);
      return;
    }

    if (_countryController.text.trim().isEmpty) {
      _showError("Please select your country.");
      setState(() => _isLoading = false);
      return;
    }

    // 2. Determine URL
    final url = '${baseUrl}auth/register/';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'first_name': _fNameController.text.trim(),
          'last_name': _lNameController.text.trim(),
          'password': _passwordController.text,
          'password2': _confirmController.text,
          'industry': _selectedIndustry,
          'industry_other':
              _selectedIndustry == 'OTH' ? _industryOtherController.text.trim() : '',
          'location': _countryController.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        // Success! Go to Email Verification Screen.
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(email: email),
            ),
          );
        }
      } else {
        _showError(_getRegistrationErrorMessage(response));
      }
    } catch (e) {
      _showError("Unable to create your account right now. Please check your internet connection and try again.");
      debugPrint("Signup exception: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getRegistrationErrorMessage(http.Response response) {
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final usernameError = decoded['username'];
        if (_containsAlreadyExistsMessage(usernameError)) {
          return "This username already exists";
        }

        final emailError = decoded['email'];
        if (_containsAlreadyExistsMessage(emailError)) {
          return "An account with this email already exists";
        }

        final nonFieldError = _extractFirstError(decoded['non_field_errors']);
        if (nonFieldError != null) {
          return nonFieldError;
        }

        for (final entry in decoded.entries) {
          final message = _extractFirstError(entry.value);
          if (message != null) {
            return _formatFieldError(entry.key, message);
          }
        }
      }
    } catch (_) {
      // Fall through to generic message
    }

    if (response.statusCode == 429) {
      return "Too many signup attempts. Please wait a moment and try again.";
    }

    return "Registration failed. Please check your details and try again.";
  }

  bool _containsAlreadyExistsMessage(dynamic error) {
    final message = _extractFirstError(error);
    if (message == null) return false;
    return message.toLowerCase().contains('already exists');
  }

  String? _extractFirstError(dynamic error) {
    if (error is List && error.isNotEmpty) {
      return error.first.toString();
    }

    if (error is String && error.trim().isNotEmpty) {
      return error;
    }

    return null;
  }

  String _formatFieldError(String field, String message) {
    final labels = {
      'first_name': 'First name',
      'last_name': 'Last name',
      'username': 'Username',
      'email': 'Email',
      'password': 'Password',
      'password2': 'Confirm password',
      'industry': 'Industry',
      'industry_other': 'Industry',
      'location': 'Country',
    };

    final label = labels[field] ?? 'This field';
    return "$label: $message";
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("APPLY", style: Theme.of(context).textTheme.displaySmall),
        leading: const BackButton(color: Color(0xFF1A1A1A)),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              "JOIN THE\nNETWORK",
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 40,
                    letterSpacing: 2.0,
                    height: 1.1,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              "Curated for female founders.",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 48),
            _buildTextField(
              "FIRST NAME",
              _fNameController,
              Icons.person,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              "LAST NAME",
              _lNameController,
              Icons.person_outline,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              "USERNAME",
              _usernameController,
              Icons.person_pin,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              "EMAIL ADDRESS",
              _emailController,
              Icons.mail_outline,
              type: TextInputType.emailAddress,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Industry Dropdown
            DropdownButtonFormField<String>(
              value: _selectedIndustry,
              decoration: const InputDecoration(
                labelText: "INDUSTRY",
                prefixIcon: Icon(Icons.work_outline),
              ),
              items: _industryChoices.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedIndustry = val);
              },
            ),
            const SizedBox(height: 16),

            // Conditional Other Input
            if (_selectedIndustry == 'OTH') ...[
              _buildTextField(
                "SPECIFY INDUSTRY",
                _industryOtherController,
                Icons.edit,
                action: TextInputAction.next,
              ),
              const SizedBox(height: 16),
            ],

            // Country Picker
            GestureDetector(
              onTap: () {
                showCountryPicker(
                  context: context,
                  showPhoneCode: false,
                  onSelect: (Country country) {
                    setState(() {
                      _countryController.text =
                          "${country.flagEmoji} ${country.name}";
                    });
                  },
                );
              },
              child: AbsorbPointer(
                child: _buildTextField(
                  "COUNTRY",
                  _countryController,
                  Icons.public,
                  action: TextInputAction.next,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              "PASSWORD",
              _passwordController,
              Icons.lock_outline,
              isObscure: true,
              action: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              "CONFIRM PASSWORD",
              _confirmController,
              Icons.lock_outline,
              isObscure: true,
              action: TextInputAction.done,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("SUBMIT APPLICATION"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isObscure = false,
    TextInputAction? action,
    TextInputType? type,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      textInputAction: action ?? TextInputAction.next,
      keyboardType: type,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
