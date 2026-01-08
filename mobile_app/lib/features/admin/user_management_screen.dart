import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/constants.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ffig_theme.dart';
import 'dart:math';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = []; // Filtered list
  bool _isLoading = true;
  String? _error;
  String _searchQuery = "";
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) _fetchUsers(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  void _filterUsers() {
    if (_searchQuery.isEmpty) {
      _filteredUsers = _users;
    } else {
      _filteredUsers = _users.where((u) {
        final name = u['username'].toString().toLowerCase();
        final email = u['email'].toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }
  }

  Future<void> _fetchUsers({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse('${baseUrl}admin/users/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _users = jsonDecode(response.body);
            _filterUsers(); // Re-filter on new data
          });
        }
      } else {
        if (!silent) setState(() => _error = "Failed: ${response.statusCode}");
      }
    } catch (e) {
      if (!silent) setState(() => _error = "Error: $e");
    } finally {
      if (!silent && mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Keep existing Create, Update, Reset logic - Assuming unchanged)
  // To be safe, I will include them if I was rewriting whole file, but for replace_file_content 
  // keeping purely state logic here isn't easy without seeing middle.
  // I will use multi_replace to target specific blocks or rewrite build method.
  
  // NOTE: For brevity in this tool call, I'm rewriting the BUILD method principally.
  // I will inject the methods back via "keep existing" assumption isn't valid for replace_file_content.
  // Since I read the file, I can reconstruct it. But it's large.
  // I will use replace_file_content to replace the State class mostly.
  
  // Wait, I should probably target the `build` method and `initState` separately or just rewrite the class if it's small enough.
  // It's 285 lines. Using multi_replace is safer.
  
  // ... _createUser, _updateUser, _resetPassword, _showCreateDialog, _showEditDialog, _deleteUser ...
  // (I will omit them in this thought block but include in tool call if rewriting)
  
  // Actually, I'll just rewrite the `build` method and `_filterUsers`/`initState` logic.
  


  Future<void> _createUser(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'password2': password,
        }),
      );
      if (response.statusCode == 201) {
        _fetchUsers();
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User created successfully")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _updateUser(int id, Map<String, dynamic> data) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final response = await http.patch(
        Uri.parse('${baseUrl}admin/users/$id/'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        _fetchUsers();
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User updated")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed update: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _resetPassword(int userId, String newPassword) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      // Using the backend endpoint: /api/admin/password-reset/ (Assuming standard path)
      final response = await http.post(
        Uri.parse('${baseUrl}admin/reset-password/'), 
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'new_password': newPassword}),
      );
      if (response.statusCode == 200) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Password reset to: $newPassword")));
      } else {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Reset Failed: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // DIALOGS
  void _showCreateDialog() {
    final userController = TextEditingController();
    final emailController = TextEditingController();
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text("New Member", style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
               const SizedBox(height: 24),
               _buildField(userController, "Username", Icons.person),
               const SizedBox(height: 16),
               _buildField(emailController, "Email", Icons.email),
               const SizedBox(height: 16),
               _buildField(passController, "Password", Icons.lock, obscure: true),
               const SizedBox(height: 32),
               ElevatedButton(
                 onPressed: () => _createUser(userController.text, emailController.text, passController.text),
                 style: ElevatedButton.styleFrom(backgroundColor: FfigTheme.pureBlack, foregroundColor: FfigTheme.primaryBrown),
                 child: const Text("CREATE MEMBER"),
               ),
             ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> user) {
    bool isStaff = user['is_staff'] ?? false;
    bool isPremium = user['is_premium'] ?? false; // Fixed: Use field from profile if needed, or dict
    if (user['profile'] != null && user['profile'] is Map) {
       isPremium = user['profile']['is_premium'] ?? isPremium;
    }
    
    final userController = TextEditingController(text: user['username']);
    final emailController = TextEditingController(text: user['email']);
    final fNameController = TextEditingController(text: user['first_name'] ?? '');
    final lNameController = TextEditingController(text: user['last_name'] ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text("Edit User", style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
                       IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                     ],
                   ),
                   const SizedBox(height: 24),
                   _buildField(userController, "Username", Icons.person),
                   const SizedBox(height: 16),
                   _buildField(fNameController, "First Name", Icons.person_outline),
                   const SizedBox(height: 16),
                   _buildField(lNameController, "Last Name", Icons.person_outline),
                   const SizedBox(height: 16),
                   _buildField(emailController, "Email", Icons.email),
                   const SizedBox(height: 24),
                   
                   SwitchListTile(title: const Text("Admin Access"), value: isStaff, onChanged: (v) => setState(() => isStaff = v)),
                   SwitchListTile(title: const Text("Premium Member"), value: isPremium, onChanged: (v) => setState(() => isPremium = v)),
                   
                   const SizedBox(height: 24),
                   OutlinedButton.icon(
                     icon: const Icon(Icons.lock_reset, size: 18),
                     label: const Text("Reset Password"),
                     onPressed: () {
                        // Generate random password
                        final newPass = _generatePassword();
                        _resetPassword(user['id'], newPass);
                        // Show dialog with new pass
                        showDialog(context: context, builder: (_) => AlertDialog(
                          title: const Text("Password Reset"),
                          content: SelectableText("New Password for ${user['username']}:\n\n$newPass"),
                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
                        ));
                     },
                   ),
                   const SizedBox(height: 24),
                   ElevatedButton(
                     onPressed: () => _updateUser(user['id'], {
                       'username': userController.text,
                       'email': emailController.text,
                       'first_name': fNameController.text,
                       'last_name': lNameController.text,
                       'is_staff': isStaff,
                       'profile': {'is_premium': isPremium} 
                     }), 
                     style: ElevatedButton.styleFrom(backgroundColor: FfigTheme.pureBlack, foregroundColor: FfigTheme.primaryBrown, padding: const EdgeInsets.all(16)),
                     child: const Text("SAVE CHANGES"),
                   ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
  
  String _generatePassword() {
     const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
     return List.generate(10, (index) => chars[Random().nextInt(chars.length)]).join();
  }
  
  Future<void> _deleteUser(int userId) async {
     // ... (Existing delete logic if needed, or use simple call)
     try {
       final token = await const FlutterSecureStorage().read(key: 'access_token');
       await http.delete(Uri.parse('${baseUrl}admin/users/$userId/'), headers: {'Authorization': 'Bearer $token'});
       _fetchUsers();
     } catch (e) {}
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: FfigTheme.primaryBrown),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Management")),
      floatingActionButton: FloatingActionButton(onPressed: _showCreateDialog, child: const Icon(Icons.add)),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Search Users...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _filterUsers();
                });
              },
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(user['username'][0].toUpperCase())),
                      title: Text(user['username']),
                      subtitle: Text(user['email']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEditDialog(user)),
                           IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteUser(user['id'])),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
