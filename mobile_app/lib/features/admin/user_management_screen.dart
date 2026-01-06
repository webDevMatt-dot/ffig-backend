import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/constants.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ffig_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) _fetchUsers(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      
      final response = await http.get(
        Uri.parse('${baseUrl}admin/users/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _users = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load users: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _createUser(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'password2': password, // Simple fallback
        }),
      );

      if (response.statusCode == 201) {
        _fetchUsers(); // Reload list
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User created successfully")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _updateUser(int id, bool isStaff, bool isPremium) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      
      final response = await http.patch(
        Uri.parse('${baseUrl}admin/users/$id/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'is_staff': isStaff,
          'is_premium': isPremium, // Send as top-level field matches Serializer
        }),
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

  Future<void> _deleteUser(int userId) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      
      final response = await http.delete(
        Uri.parse('${baseUrl}admin/users/$userId/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 204) {
        setState(() {
          _users.removeWhere((user) => user['id'] == userId);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User deleted.")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 1. Create Dialog
  void _showCreateDialog() {
    final userController = TextEditingController();
    final emailController = TextEditingController();
    final passController = TextEditingController();

    showDialog(
      context: context,
        builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).cardTheme.color,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               Text("New Member", style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.displayMedium?.color)),
               const SizedBox(height: 24),
               _buildPremiumField(userController, "Username", Icons.person),
               const SizedBox(height: 16),
               _buildPremiumField(emailController, "Email", Icons.email),
               const SizedBox(height: 16),
               _buildPremiumField(passController, "Password", Icons.lock, obscure: true),
               const SizedBox(height: 32),
               ElevatedButton(
                 onPressed: () {
                    if(userController.text.isNotEmpty && passController.text.isNotEmpty) {
                      _createUser(userController.text, emailController.text, passController.text);
                    }
                 }, 
                 style: ElevatedButton.styleFrom(
                   backgroundColor: FfigTheme.matteBlack,
                   foregroundColor: FfigTheme.gold,
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                 ),
                 child: Text("CREATE MEMBER", style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
               ),
             ],
          ),
        ),
      ),
    );
  }

  // 2. Edit Dialog
  void _showEditDialog(Map<String, dynamic> user) {
    bool isStaff = user['is_staff'] ?? false;
    bool isPremium = user['is_premium'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Theme.of(context).cardTheme.color,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Text("Edit Access", style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.displayMedium?.color)),
                   const SizedBox(height: 8),
                   Text("Manage roles for ${user['username']}", style: GoogleFonts.lato(color: Colors.grey)),
                   const SizedBox(height: 24),
                   
                   Container(
                     decoration: BoxDecoration(color: Theme.of(context).inputDecorationTheme.fillColor, borderRadius: BorderRadius.circular(16)),
                     child: Column(
                       children: [
                         SwitchListTile(
                            title: const Text("Admin Access"),
                            secondary: Icon(Icons.shield_outlined, color: Theme.of(context).iconTheme.color),
                            value: isStaff, 
                            activeColor: FfigTheme.gold,
                            onChanged: (val) => setState(() => isStaff = val)
                          ),
                          Divider(height: 1, color: Theme.of(context).dividerColor),
                          SwitchListTile(
                            title: const Text("Premium Member"),
                            secondary: const Icon(Icons.diamond_outlined, color: FfigTheme.gold),
                            value: isPremium, 
                            activeColor: FfigTheme.gold,
                            onChanged: (val) => setState(() => isPremium = val)
                          ),
                       ],
                     ),
                   ),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => _updateUser(user['id'], isStaff, isPremium), 
                    style: ElevatedButton.styleFrom(
                       backgroundColor: FfigTheme.matteBlack,
                       foregroundColor: FfigTheme.gold,
                       padding: const EdgeInsets.symmetric(vertical: 16),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("SAVE CHANGES", style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  // 3. Delete Dialog
  void _confirmDelete(int userId, String username) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Remove Member", style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: FfigTheme.matteBlack)),
              const SizedBox(height: 16),
              Text("Are you sure you want to remove $username? They will lose all access immediately.", 
                   textAlign: TextAlign.center,
                   style: GoogleFonts.lato(fontSize: 14, color: Colors.grey[700], height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                   Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Text("CANCEL", style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                         Navigator.pop(context);
                         _deleteUser(userId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(vertical: 14),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         elevation: 0,
                      ),
                      child: Text("REMOVE", style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.lato(fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        labelText: label,
        labelStyle: GoogleFonts.lato(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
        prefixIcon: Icon(icon, color: FfigTheme.gold, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Management")),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null 
          ? Center(child: Text(_error!))
          : ListView.separated(
              itemCount: _users.length,
              separatorBuilder: (c, i) => const Divider(),
              itemBuilder: (context, index) {
                final user = _users[index];
                final isStaff = user['is_staff'] ?? false;
                final isPremium = user['is_premium'] ?? false;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isStaff ? Colors.purple : (isPremium ? Colors.amber : Colors.grey),
                    child: Text(user['username'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(user['username'], style: TextStyle(fontWeight: isStaff ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(user['email']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditDialog(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDelete(user['id'], user['username']),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
