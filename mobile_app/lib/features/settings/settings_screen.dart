import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/api/constants.dart';
import '../../core/theme/ffig_theme.dart';
import '../../main.dart'; // To access themeController global
import '../auth/login_screen.dart';
import 'edit_profile_screen.dart';
import '../tickets/my_tickets_screen.dart';
import 'blocked_users_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _email = "Loading...";
  String _appVersion = "";
  bool _isPremium = false;
  String _tier = "FREE";
  bool _readReceiptsEnabled = true; // Default true
  String? _adminNotice;
  
  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _fetchVersion();
  }

  Future<void> _fetchVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  Future<void> _fetchUserInfo() async {
      try {
        const storage = FlutterSecureStorage();
        final token = await storage.read(key: 'access_token');
        final response = await http.get(Uri.parse('${baseUrl}members/me/'), headers: {'Authorization': 'Bearer $token'});
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted) {
            setState(() {
              _email = data['email'] ?? "Unknown";
              _isPremium = data['is_premium'] ?? false;
              _tier = data['tier'] ?? "FREE";
              // Backend returns flat JSON via ProfileSerializer
              _readReceiptsEnabled = data['read_receipts_enabled'] ?? true;
              _adminNotice = data['admin_notice']; // May be null
            });
          }
        }
      } catch (e) {}
  }

  void _showDeleteConfirmation() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("DELETE ACCOUNT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("This action cannot be undone. Type 'sudo delete this account.' to confirm:"),
            const SizedBox(height: 16),
            TextField(controller: controller, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "sudo delete this account.")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
               if (controller.text.trim() == "sudo delete this account.") {
                 Navigator.pop(context);
                 _deleteAccount();
               } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect text.")));
               }
            },
            child: const Text("DELETE PERMANENTLY"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
       const storage = FlutterSecureStorage();
       final token = await storage.read(key: 'access_token');
       final response = await http.delete(Uri.parse('${baseUrl}auth/delete/'), headers: {'Authorization': 'Bearer $token'}); // Updated URL
       if (response.statusCode == 204) {
          _logout();
       } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete account.")));
       }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
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

  Future<void> _updatePrivacy(bool enabled) async {
       try {
           const storage = FlutterSecureStorage();
           final token = await storage.read(key: 'access_token');
           await http.patch(
               Uri.parse('${baseUrl}members/me/'), // Ensure this endpoint handles profile update
               headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
               body: jsonEncode({'read_receipts_enabled': enabled})
           );
       } catch (e) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update privacy settings.")));
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
          
          const SizedBox(height: 16),
          
          if (_adminNotice != null && _adminNotice!.isNotEmpty)
             Container(
                 margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                     color: Colors.orange.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: Colors.orange),
                 ),
                 child: Row(
                     children: [
                         const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                         const SizedBox(width: 16),
                         Expanded(
                             child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                     const Text("Account Notice", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                     const SizedBox(height: 4),
                                     Text(_adminNotice!, style: const TextStyle(fontSize: 13)),
                                 ],
                             ),
                         )
                     ],
                 ),
             ),
             
          // 1. General (Edit Profile, Change Password)
          _buildSectionHeader("General"),
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

          // 2. Preferences (Theme)
          _buildSectionHeader("Preferences"),
          AnimatedBuilder(
            animation: themeController, 
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

          // 3. Privacy
          _buildSectionHeader("Privacy"),
          SwitchListTile(
            title: const Text("Read Receipts"),
            subtitle: const Text("Let others know when you've read their messages."),
            value: _readReceiptsEnabled,
            onChanged: (val) {
                setState(() => _readReceiptsEnabled = val);
                _updatePrivacy(val);
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.block, color: Colors.grey),
            title: const Text("Blocked Users"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const BlockedUsersScreen()));
            },
          ),
          
          const Divider(),

          // 3. Account & Subscription
          _buildSectionHeader("Account & Subscription"),
          Container(
             margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Theme.of(context).cardColor,
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: Theme.of(context).dividerColor),
             ),
             child: Column(
               children: [
                 Row(
                   children: [
                     const Icon(Icons.email_outlined, color: FfigTheme.primaryBrown),
                     const SizedBox(width: 12),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            const Text("Email Address", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(_email, style: const TextStyle(fontWeight: FontWeight.bold)),
                         ],
                       ),
                     )
                   ],
                 ),
                 const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                 Row(
                   children: [
                      if (_tier == 'PREMIUM')
                       const Icon(Icons.verified, color: Colors.amber) // Gold
                      else if (_tier == 'STANDARD')
                       const Icon(Icons.verified, color: FfigTheme.primaryBrown) // Brown
                      else
                       const Icon(Icons.verified_outlined, color: Colors.grey),
                       
                     const SizedBox(width: 12),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Text("Subscription", style: TextStyle(fontSize: 12, color: Colors.grey)),
                           Text(_tier == 'PREMIUM' ? "Premium Member" : (_tier == 'STANDARD' ? "Standard Member" : "Free Tier"), style: const TextStyle(fontWeight: FontWeight.bold)),
                         ],
                       ),
                     )
                   ],
                 ),
               ],
             ),
          ),
          
          const Divider(),

          // 4. System (Version)
           ListTile(
            leading: const Icon(Icons.confirmation_number_outlined),
            title: const Text("My Tickets"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const MyTicketsScreen()));
            },
          ),
          
          const Divider(),

          // 4. System (Version)
           _buildSectionHeader("System"),
           ListTile(
             leading: const Icon(Icons.info_outline),
             title: const Text("App Version"),
             trailing: Text(_appVersion, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
           ),

           const Divider(),

          // 5. Sign Out
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.grey),
            title: const Text("Sign Out"),
            onTap: _logout,
          ),
          
          const SizedBox(height: 48),
          
          // 6. Danger Zone
          _buildSectionHeader("DANGER ZONE"),
           Container(
             margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             decoration: BoxDecoration(
               color: Colors.red.withOpacity(0.05),
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: Colors.red.withOpacity(0.3)),
             ),
             child: ListTile(
               leading: const Icon(Icons.delete_forever, color: Colors.red),
               title: const Text("Delete Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
               subtitle: const Text("This action is permanent and cannot be undone."),
               onTap: _showDeleteConfirmation,
             ),
           ),
           const SizedBox(height: 24),
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
