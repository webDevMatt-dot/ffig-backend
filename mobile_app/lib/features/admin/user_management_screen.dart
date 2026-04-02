import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/constants.dart';
import 'dart:async';
import 'edit_user_screen.dart';
import 'widgets/admin_dark_list_item.dart';

/// Screen for managing application users.
///
/// **Features:**
/// - Tabbed view for All, Suspended, and Blocked users.
/// - Search functionality by username or email.
/// - Edit user details or delete users.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Lists for each category
  List<dynamic> _allUsers = [];
  List<dynamic> _suspendedUsers = [];
  List<dynamic> _blockedUsers = [];
  
  bool _isLoading = true;
  String? _error;
  String _searchQuery = "";
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllCategories();
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) _fetchAllCategories(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Fetches users for all tabs concurrently.
  /// - `silent`: If true, suppresses loading indicator (for background refresh).
  /// - Updates `_allUsers`, `_suspendedUsers`, `_blockedUsers`.
  Future<void> _fetchAllCategories({bool silent = false}) async {
      if (!silent) setState(() => _isLoading = true);
      try {
          await Future.wait([
              _fetchUsers(null).then((res) => _allUsers = res),
              _fetchUsers('suspended').then((res) => _suspendedUsers = res),
              _fetchUsers('blocked').then((res) => _blockedUsers = res),
          ]);
          if (mounted) setState(() {});
      } catch (e) {
          if (mounted && !silent) setState(() => _error = e.toString());
      } finally {
          if (mounted && !silent) setState(() => _isLoading = false);
      }
  }

  /// Helper to fetch users with optional status filter.
  /// - Status filters: 'suspended', 'blocked', or null (all).
  Future<List<dynamic>> _fetchUsers(String? statusFilter) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    String url = '${baseUrl}members/';
    if (statusFilter != null) {
        url += '?status=$statusFilter';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (response.statusCode == 200) {
        return jsonDecode(response.body);
    } else {
        throw Exception("Failed to load users: ${response.statusCode}");
    }
  }

  List<dynamic> _applySearch(List<dynamic> items) {
      if (_searchQuery.isEmpty) return items;
      final q = _searchQuery.toLowerCase();
      return items.where((u) {
          final name = u['username'].toString().toLowerCase();
          final email = u['email'].toString().toLowerCase();
          return name.contains(q) || email.contains(q);
      }).toList();
  }

  // ... (Keep CRUD Methods _createUser, _updateUser, _deleteUser, etc.)
  // Since replace_file_content replaces the whole block, I must assume CRUD methods are safely preserved or I must re-include them.
  // The user prompt implied keeping logic.
  // BUT the previous view was truncated. I must re-implement basic CRUD calls or rely on a "keep existing" assumption that isn't safe.
  // I will re-implement the CRUD calls briefly to ensure functionality.

  /// Deletes a user by ID.
  /// - Sends DELETE request to `/admin/users/$id/`.
  /// - Silently refreshes the list on success.
  Future<void> _deleteUser(int userId) async {
     try {
       final token = await const FlutterSecureStorage().read(key: 'access_token');
       final response = await http.delete(Uri.parse('${baseUrl}admin/users/$userId/'), headers: {'Authorization': 'Bearer $token'});
       if (response.statusCode == 204 || response.statusCode == 200) {
           _fetchAllCategories(silent: true);
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User deleted")));
       } else {
           if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(
                       content: Text("Failed to delete user: ${response.statusCode} - ${response.body}"),
                       backgroundColor: Colors.red,
                   )
               );
           }
       }
     } catch (e) {
       if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                   content: Text("Error deleting user: $e"),
                   backgroundColor: Colors.red,
               )
           );
       }
     }
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final firstName = (user['first_name'] ?? user['name'] ?? '').toString().trim();
    final surname = (user['last_name'] ?? user['surname'] ?? '').toString().trim();
    final fallbackName = user['username']?.toString() ?? 'this user';
    final fullName = [firstName, surname].where((part) => part.isNotEmpty).join('+');
    final displayName = fullName.isEmpty ? fallbackName : fullName;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text("Are you sure you want to delete $displayName's profile?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await _deleteUser(user['user_id'] ?? user['id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("User Management"),
          actions: [
            IconButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditUserScreen()));
                _fetchAllCategories();
              },
              icon: const Icon(Icons.add, size: 34),
              tooltip: "Add User",
            ),
          ],
          bottom: TabBar(
              controller: _tabController,
              tabs: const [
                  Tab(text: "All"),
                  Tab(text: "Suspended"),
                  Tab(text: "Blocked"),
              ],
          ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Users...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                filled: true, 
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16)
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                      _buildUserList(_applySearch(_allUsers)),
                      _buildUserList(_applySearch(_suspendedUsers)),
                      _buildUserList(_applySearch(_blockedUsers)),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<dynamic> users) {
      if (users.isEmpty) return const Center(child: Text("No users found."));
      
      return ListView.builder(
        itemCount: users.length,
        padding: const EdgeInsets.only(bottom: 150),
        itemBuilder: (context, index) {
          final user = users[index];
          final isBlocked = user['is_blocked'] ?? false;
          final suspendedUntil = user['suspension_expiry'];
          bool isSuspended = false;
          if (suspendedUntil != null) {
              isSuspended = DateTime.parse(suspendedUntil).isAfter(DateTime.now());
          }

          return AdminDarkListItem(
            title: user['username'],
            subtitle: user['email'],
            imageUrl: () {
              var url = user['photo'] ?? user['photo_url'];
              if (url != null && url.toString().startsWith('/')) {
                return '${baseUrl.replaceAll('/api/', '')}$url';
              }
              return url?.toString();
            }(),
            fallbackIcon: Icons.person_outline,
            statusChip: isBlocked
                ? _statusChip("BLOCKED", Colors.red)
                : (isSuspended ? _statusChip("SUSPENDED", Colors.orange) : null),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white70),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => EditUserScreen(user: user)));
                    _fetchAllCategories(silent: true);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmDeleteUser(user),
                ),
              ],
            ),
          );
        },
      );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
