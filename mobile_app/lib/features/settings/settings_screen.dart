import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/api/constants.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/theme/theme_controller.dart'; 
import '../../main.dart'; // To access themeController global
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  
  Future<void> _logout() async {
     const storage = FlutterSecureStorage();
     await storage.deleteAll();
     if(mounted) {
       Navigator.of(context).pushAndRemoveUntil(
         MaterialPageRoute(builder: (c) => const LoginScreen()),
         (route) => false
       );
     }
  }

  Future<void> _changePassword(String oldPass, String newPass) async {
      try {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: 'access_token');
        final response = await http.post(
          Uri.parse('${baseUrl}auth/password/change/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'old_password': oldPass, 'new_password': newPass}),
        );
        
        if (response.statusCode == 200) {
            if(mounted) {
                Navigator.pop(context); // Close dialog
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password changed successfully!")));
            }
        } else {
             final data = jsonDecode(response.body);
             throw Exception(data['error'] ?? "Failed to change password");
        }
      } catch (e) {
          if(mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
          }
      }
  }

  void _showPasswordChangeDialog() {
      final oldPassCtrl = TextEditingController();
      final newPassCtrl = TextEditingController();
      final confirmPassCtrl = TextEditingController();
      
      showDialog(
        context: context, 
        builder: (context) => AlertDialog(
          title: const Text("Change Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               TextField(controller: oldPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Current Password")),
               const SizedBox(height: 8),
               TextField(controller: newPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: "New Password")),
               const SizedBox(height: 8),
               TextField(controller: confirmPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Confirm New Password")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                 if (newPassCtrl.text != confirmPassCtrl.text) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New passwords do not match")));
                     return;
                 }
                 _changePassword(oldPassCtrl.text, newPassCtrl.text);
              }, 
              child: const Text("Update")
            )
          ],
        )
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // 1. Account Config
          _buildSectionHeader("Account"),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Edit Profile"),
            subtitle: const Text("Name, Bio, Industry, Photo"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text("Change Password"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showPasswordChangeDialog,
          ),
          
          const Divider(),

          // 2. App Config
          _buildSectionHeader("Preferences"),
          
          // Theme Toggle
          AnimatedBuilder(
            animation: themeController, // From main.dart or pass via provider
            builder: (context, _) {
              return ExpansionTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text("Theme"),
                subtitle: Text(themeController.themeMode.toString().split('.').last.toUpperCase()),
                children: [
                   RadioListTile<ThemeMode>(
                     title: const Text("Light Mode"),
                     value: ThemeMode.light,
                     groupValue: themeController.themeMode,
                     onChanged: (val) => themeController.setTheme(val!),
                   ),
                   RadioListTile<ThemeMode>(
                     title: const Text("Dark Mode"),
                     value: ThemeMode.dark,
                     groupValue: themeController.themeMode,
                     onChanged: (val) => themeController.setTheme(val!),
                   ),
                   RadioListTile<ThemeMode>(
                     title: const Text("System Default"),
                     value: ThemeMode.system,
                     groupValue: themeController.themeMode,
                     onChanged: (val) => themeController.setTheme(val!),
                   ),
                ]
              );
            }
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Sign Out", style: TextStyle(color: Colors.redAccent)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(), 
        style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)
      ),
    );
  }
}
