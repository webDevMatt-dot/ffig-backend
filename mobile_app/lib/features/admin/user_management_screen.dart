import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/constants.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/ffig_theme.dart';
import 'dart:math';
import '../../core/utils/dialog_utils.dart';
import 'edit_user_screen.dart';

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
  


  Future<void> _createUser(String username, String email, String password, String fName, String lName, String tier) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}auth/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'password2': password,
          'first_name': fName,
          'last_name': lName,
        }),
      );
      
      if (response.statusCode == 201) {
        // User created. Now update tier if needed.
        if (tier != 'FREE') {
           final body = jsonDecode(response.body);
           final newUserId = body['id']; // Requires backend to return ID
           if (newUserId != null) {
              // Call update quietly
              await _updateUser(newUserId, {
                'profile': {'tier': tier}
              }, silent: true);
           }
        }

        await _fetchUsers(); 
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User created successfully")));
      } else {
        DialogUtils.showError(context, "Creation Failed", "Could not create user.\nBackend says: ${response.body}");
      }
    } catch (e) {
      DialogUtils.showError(context, "Error", "An unexpected error occurred.\n$e");
    }
  }

  Future<void> _updateUser(int id, Map<String, dynamic> data, {bool silent = false}) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final response = await http.patch(
        Uri.parse('${baseUrl}admin/users/$id/'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        if (!silent) {
           _fetchUsers();
           if (mounted) Navigator.pop(context); // Only pop if explicit user action
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User updated")));
        }
      } else {
        if (!silent) DialogUtils.showError(context, "Update Failed", "Could not update user.\n${response.body}");
      }
    } catch (e) {
      if (!silent) DialogUtils.showError(context, "Error", "Network error: $e");
    }
  }

  Future<void> _deleteUser(int userId) async {
     try {
       final token = await const FlutterSecureStorage().read(key: 'access_token');
       final response = await http.delete(Uri.parse('${baseUrl}admin/users/$userId/'), headers: {'Authorization': 'Bearer $token'});
       if (response.statusCode == 204 || response.statusCode == 200) {
           _fetchUsers();
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User deleted")));
       } else {
           if (mounted) DialogUtils.showError(context, "Error", "Failed to delete user: ${response.body}");
       }
     } catch (e) {
       if (mounted) DialogUtils.showError(context, "Error", "Network error: $e");
     }
  }

  // No Dialog helpers needed.

  // No Dialog helpers needed.


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Management")),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
           await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditUserScreen()));
           _fetchUsers();
        }, 
        child: const Icon(Icons.add)
      ),
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
                           IconButton(
                             icon: const Icon(Icons.edit, color: Colors.blue), 
                             onPressed: () async {
                               await Navigator.push(context, MaterialPageRoute(builder: (_) => EditUserScreen(user: user)));
                               _fetchUsers();
                             }
                           ),
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
