import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import '../../core/api/constants.dart';

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
  bool _isLoading = false;

  Future<void> _register() async {
    setState(() => _isLoading = true);

    // 1. Basic Validation
    if (_passwordController.text != _confirmController.text) {
      _showError("Passwords do not match");
      setState(() => _isLoading = false);
      return;
    }

    // 2. Determine URL
    const url = '${baseUrl}auth/register/';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text,
          'email': _emailController.text,
          'first_name': _fNameController.text,
          'last_name': _lNameController.text,
          'password': _passwordController.text,
          'password2': _confirmController.text,
        }),
      );

      if (response.statusCode == 201) {
        // Success! Go back to Login so they can sign in.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account created! Please log in."), backgroundColor: Colors.green),
          );
          Navigator.pop(context); // Return to Login Screen
        }
      } else {
        // Handle errors (like "Username already exists")
        _showError("Registration failed: ${response.body}");
      }
    } catch (e) {
      _showError("Connection error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
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
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 48),

            _buildTextField("FIRST NAME", _fNameController, Icons.person),
            const SizedBox(height: 16),
            _buildTextField("LAST NAME", _lNameController, Icons.person_outline),
            const SizedBox(height: 16),
            _buildTextField("USERNAME", _usernameController, Icons.person_pin),
            const SizedBox(height: 16),
            _buildTextField("EMAIL ADDRESS", _emailController, Icons.mail_outline),
            const SizedBox(height: 16),
            _buildTextField("PASSWORD", _passwordController, Icons.lock_outline, isObscure: true),
            const SizedBox(height: 16),
            _buildTextField("CONFIRM PASSWORD", _confirmController, Icons.lock_outline, isObscure: true),

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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isObscure = false}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
