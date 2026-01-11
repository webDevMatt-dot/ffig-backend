import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../core/api/constants.dart';
import '../../core/theme/ffig_theme.dart';
import '../auth/login_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  String _email = "";
  bool _isPremium = false;
  
  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    try {
      final token = await _storage.read(key: 'access_token');
      // Assuming /members/me/ returns email and is_premium
      final response = await http.get(
        Uri.parse('${baseUrl}members/me/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _email = data['email'] ?? "Unknown";
          _isPremium = data['is_premium'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDeleteConfirmation() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("DANGER ZONE", style: GoogleFonts.oswald(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("This action is permanent and cannot be undone. All your data will be erased."),
            const SizedBox(height: 16),
            const Text("Type 'sudo delete this account.' to confirm:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "sudo delete this account.",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
               if (controller.text.trim() == "sudo delete this account.") {
                 Navigator.pop(context);
                 _deleteAccount();
               } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect confirmation text.")));
               }
            },
            child: const Text("DELETE ACCOUNT"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);
    try {
       final token = await _storage.read(key: 'access_token');
       final response = await http.delete(
         Uri.parse('${baseUrl}auth/delete/'),
         headers: {'Authorization': 'Bearer $token'},
       );

       if (response.statusCode == 204) {
         // Success
         await _storage.deleteAll();
         if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
         }
       } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete account.")));
       }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ACCOUNT & SUBSCRIPTION", style: FfigTheme.textTheme.titleLarge)),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: FfigTheme.primaryBrown))
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
               // INFO CARD
               Card(
                 elevation: 2,
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                 child: Padding(
                   padding: const EdgeInsets.all(24),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text("Login Info", style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 16),
                       ListTile(
                         leading: const Icon(Icons.email, color: FfigTheme.primaryBrown),
                         title: const Text("Email Address"),
                         subtitle: Text(_email),
                         contentPadding: EdgeInsets.zero,
                       ),
                       const Divider(),
                       ListTile(
                         leading: Icon(Icons.verified, color: _isPremium ? Colors.amber : Colors.grey),
                         title: const Text("Subscription Status"),
                         subtitle: Text(_isPremium ? "Premium Member" : "Free Entreprenuer Tier"),
                         contentPadding: EdgeInsets.zero,
                       ),
                     ],
                   ),
                 ),
               ),
               
               const SizedBox(height: 48),
               
               // DANGER ZONE
               Text("Danger Zone", style: GoogleFonts.oswald(color: Colors.red, fontSize: 18)),
               const SizedBox(height: 8),
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   border: Border.all(color: Colors.red),
                   borderRadius: BorderRadius.circular(12),
                   color: Colors.red.withOpacity(0.05),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text("Deleting your account is irreversible. You will lose access to the community, resources, and your profile will be removed."),
                     const SizedBox(height: 16),
                     SizedBox(
                       width: double.infinity,
                       child: ElevatedButton.icon(
                         onPressed: _showDeleteConfirmation,
                         icon: const Icon(Icons.delete_forever),
                         label: const Text("DELETE MY ACCOUNT"),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.red,
                           foregroundColor: Colors.white,
                         ),
                       ),
                     ),
                   ],
                 ),
               )
            ],
          ),
    );
  }
}
