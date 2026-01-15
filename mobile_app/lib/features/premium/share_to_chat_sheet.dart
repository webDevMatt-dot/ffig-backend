
// ... previous imports
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/constants.dart';
import '../../shared_widgets/user_avatar.dart';

class ShareToChatSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  const ShareToChatSheet({super.key, required this.item});

  @override
  State<ShareToChatSheet> createState() => _ShareToChatSheetState();
}

class _ShareToChatSheetState extends State<ShareToChatSheet> {
  final _searchController = TextEditingController();
  List<dynamic> _users = [];
  bool _isLoading = false;
  
  @override
  void initState() {
      super.initState();
      // Optionally load recent conversations here
  }

  Future<void> _search(String query) async {
      if (query.isEmpty) {
          setState(() => _users = []);
          return;
      }
      setState(() => _isLoading = true);
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      try {
          final uri = Uri.parse('${baseUrl}chat/search/?q=$query');
          final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
          if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (mounted) setState(() {
                  _users = data['users'] ?? [];
                  _isLoading = false;
              });
          }
      } catch (e) {
          if (mounted) setState(() => _isLoading = false);
      }
  }

  Future<void> _send(dynamic user) async {
       // Send Message
       setState(() => _isLoading = true);
       const storage = FlutterSecureStorage();
       final token = await storage.read(key: 'access_token');
       
       final text = "Check out this ${widget.item['type']} on FFig: ${widget.item['title']}\n${widget.item['link'] ?? ''}";
       
       try {
           final response = await http.post(
               Uri.parse('${baseUrl}chat/messages/send/'),
               headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
               body: jsonEncode({
                   'text': text,
                   'recipient_id': user['id']
               })
           );
           
           if (response.statusCode == 201) {
               if (mounted) {
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sent to ${user['username']}!")));
               }
           } else {
               throw Exception("Failed to send");
           }
       } catch (e) {
           if (mounted) {
               setState(() => _isLoading = false);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send.")));
           }
       }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
            children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text("Share to Chat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                        hintText: "Search users...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[100]
                    ),
                    onChanged: (val) => _search(val),
                ),
                const SizedBox(height: 16),
                Expanded(
                    child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _users.isEmpty 
                        ? const Center(child: Text("Search for a user to share with."))
                        : ListView.builder(
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                                final user = _users[index];
                                var photoUrl = user['photo_url'];
                                if (photoUrl != null && photoUrl.toString().startsWith('/')) {
                                    final domain = baseUrl.replaceAll('/api/', '');
                                    photoUrl = '$domain$photoUrl';
                                }
                                return ListTile(
                                    leading: CircleAvatar(
                                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                        child: photoUrl == null ? Text(user['username'][0].toUpperCase()) : null,
                                    ),
                                    title: Text(user['username']),
                                    trailing: const Icon(Icons.send, color: Colors.blue),
                                    onTap: () => _send(user),
                                );
                            },
                        )
                )
            ],
        ),
    );
  }
}
