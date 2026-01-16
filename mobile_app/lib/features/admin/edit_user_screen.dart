import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../../core/api/constants.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/utils/dialog_utils.dart';

class EditUserScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const EditUserScreen({super.key, this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _fNameController = TextEditingController();
  final _lNameController = TextEditingController();
  final _passController = TextEditingController(); // Only for create
  
  // State
  String _selectedTier = 'FREE';
  bool _isStaff = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _usernameController.text = widget.user!['username'] ?? '';
      _emailController.text = widget.user!['email'] ?? '';
      _fNameController.text = widget.user!['first_name'] ?? '';
      _lNameController.text = widget.user!['last_name'] ?? '';
      _isStaff = widget.user!['is_staff'] ?? false;
      
      // Determine Tier
      if (widget.user!['tier'] != null) {
         _selectedTier = widget.user!['tier'];
      } else if (widget.user!['profile'] != null && widget.user!['profile'] is Map) {
         _selectedTier = widget.user!['profile']['tier'] ?? 'FREE';
      } else {
         bool isPremium = widget.user!['is_premium'] ?? false;
         if (isPremium) _selectedTier = 'PREMIUM';
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (widget.user == null) {
        await _createUser();
      } else {
        await _updateUser();
      }
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Error", e.toString());
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createUser() async {
      final response = await http.post(
        Uri.parse('${baseUrl}auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text,
          'email': _emailController.text,
          'password': _passController.text,
          'password2': _passController.text,
          'first_name': _fNameController.text,
          'last_name': _lNameController.text,
        }),
      );
      
      if (response.statusCode == 201) {
        // User created. Now update tier/staff if needed.
        bool needsUpdate = _selectedTier != 'FREE' || _isStaff;
        
        if (needsUpdate) {
           final body = jsonDecode(response.body);
           final newUserId = body['id'];
           if (newUserId != null) {
              await _performUpdate(newUserId, true); // Silent update
           }
        }
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User created successfully")));
           Navigator.pop(context, true); // Return true to refresh
        }
      } else {
        throw Exception("Could not create user.\nBackend says: ${response.body}");
      }
  }

  Future<void> _updateUser() async {
      await _performUpdate(widget.user!['id'], false);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User updated")));
         Navigator.pop(context, true);
      }
  }

  Future<void> _performUpdate(int id, bool silent) async {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final response = await http.patch(
        Uri.parse('${baseUrl}admin/users/$id/'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
           'username': _usernameController.text,
           'email': _emailController.text,
           'first_name': _fNameController.text,
           'last_name': _lNameController.text,
           'is_staff': _isStaff,
           'profile': {'tier': _selectedTier}
        }),
      );
      if (response.statusCode != 200) {
        throw Exception("Update failed: ${response.body}");
      }
  }

  Future<void> _resetPassword() async {
     try {
       final newPass = _generatePassword();
       const storage = FlutterSecureStorage();
       final token = await storage.read(key: 'access_token');
       final response = await http.post(
          Uri.parse('${baseUrl}admin/reset-password/'), 
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': widget.user!['id'], 'new_password': newPass}),
       );
       
       if (response.statusCode == 200) {
          if (mounted) {
            showDialog(context: context, builder: (_) => AlertDialog(
              title: const Text("Password Reset"),
              content: SelectableText("New Password for ${_usernameController.text}:\n\n$newPass"),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
            ));
          }
       } else {
          throw Exception(response.body);
       }
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Reset Failed: $e")));
     }
  }
  
  String _generatePassword() {
     const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
     return List.generate(10, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  Future<bool> _showAdminConfirmation() async {
     final username = _usernameController.text.isNotEmpty ? _usernameController.text : "this user";
     return await showDialog<bool>(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text("Confirm Admin Access"),
         content: Text("Are you sure you want to make $username an administrator?"),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
             onPressed: () => Navigator.pop(context, true), 
             child: const Text("Confirm")
           ),
         ],
       ),
     ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.user == null ? "Create User" : "Edit User")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               _buildSection("Profile Information", [
                  TextFormField(
                    controller: _usernameController, 
                    decoration: const InputDecoration(labelText: "Username", prefixIcon: Icon(Icons.person)),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _fNameController, decoration: const InputDecoration(labelText: "First Name"))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _lNameController, decoration: const InputDecoration(labelText: "Last Name"))),
                  ]),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController, 
                    decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email)),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
               ]),
               const SizedBox(height: 24),
               

               _buildSection("Membership & Access", [
                   DropdownButtonFormField<String>(
                     decoration: const InputDecoration(labelText: "Membership Tier", border: OutlineInputBorder()),
                     value: _selectedTier,
                     items: const [
                       DropdownMenuItem(value: 'FREE', child: Text("Free")),
                       DropdownMenuItem(value: 'STANDARD', child: Text("Standard")),
                       DropdownMenuItem(value: 'PREMIUM', child: Text("Premium")),
                       DropdownMenuItem(value: 'ADMIN', child: Text("Admin")),
                     ],
                     onChanged: (v) async {
                        if (v == 'ADMIN') {
                           final confirmed = await _showAdminConfirmation();
                           if (confirmed) {
                              setState(() => _selectedTier = v!);
                           }
                        } else {
                           setState(() => _selectedTier = v!);
                        }
                     },
                   ),
                   const SizedBox(height: 16),
                   SwitchListTile(
                     title: const Text("Admin Access"), 
                     subtitle: const Text("Can access dashboard"),
                     value: _isStaff, 
                     onChanged: (v) async {
                        if (v) {
                           final confirmed = await _showAdminConfirmation();
                           if (confirmed) {
                              setState(() => _isStaff = true);
                           }
                        } else {
                           setState(() => _isStaff = false);
                        }
                     },
                     contentPadding: EdgeInsets.zero,
                   ),
               ]),

               const SizedBox(height: 24),
               
               _buildSection("Security", [
                  if (widget.user == null) 
                    TextFormField(
                      controller: _passController, 
                      decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock)),
                      obscureText: true,
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    )
                  else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lock_reset),
                      label: const Text("Reset Password"),
                      onPressed: _resetPassword,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    )
               ]),
               
               const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: FfigTheme.primaryBrown,
                  foregroundColor: Colors.white,
              ),
              child: Text(_isLoading ? "Saving..." : (widget.user == null ? "CREATE MEMBER" : "SAVE CHANGES")),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            const SizedBox(height: 12),
            ...children
          ],
        ),
      ),
    );
  }
}
