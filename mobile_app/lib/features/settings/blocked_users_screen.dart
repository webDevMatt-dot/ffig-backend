import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api/constants.dart';
import '../../../shared_widgets/user_avatar.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<dynamic> _blockedUsers = [];
  bool _isLoading = true;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse('${baseUrl}members/blocked/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _blockedUsers = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(int userId, String username) async {
      try {
          final token = await _storage.read(key: 'access_token');
          final response = await http.delete(
              Uri.parse('${baseUrl}members/block/$userId/'),
              headers: {'Authorization': 'Bearer $token'},
          );

          if (response.statusCode == 200) {
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Unblocked $username")));
                  _fetchBlockedUsers(); // Refresh list
              }
          } else {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to unblock")));
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error unblocking user")));
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Blocked Users")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _blockedUsers.isEmpty 
            ? Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Icon(Icons.block, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text("No blocked users", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                )
            )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _blockedUsers.length,
                separatorBuilder: (c, i) => const Divider(),
                itemBuilder: (context, index) {
                   final profile = _blockedUsers[index];
                   final username = profile['username'] ?? 'Unknown';
                   final userId = profile['user_id'];
                   final photoUrl = profile['photo_url'];

                   return ListTile(
                     leading: UserAvatar(
                       imageUrl: photoUrl, 
                       username: username,
                       radius: 20,
                     ),
                     title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                     trailing: OutlinedButton(
                         onPressed: () => _unblockUser(userId, username),
                         style: OutlinedButton.styleFrom(
                             foregroundColor: Colors.red,
                             side: const BorderSide(color: Colors.red),
                             padding: const EdgeInsets.symmetric(horizontal: 16)
                         ),
                         child: const Text("Unblock"),
                     ),
                   );
                },
              ),
    );
  }
}
