import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'chat_screen.dart'; // Import Chat Screen

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    const String baseUrl = 'https://ffig-api.onrender.com/api/chat/conversations/';

    try {
      final response = await http.get(Uri.parse(baseUrl), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        setState(() {
          _conversations = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) print(e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MESSAGES")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _conversations.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text("No messages yet."),
                    TextButton(
                      onPressed: () {
                         // Logic to switch tab to Network could go here, 
                         // but for now simple text is enough.
                      }, 
                      child: const Text("Find a founder to chat with!")
                    )
                  ],
                ),
              )
            : ListView.separated(
                itemCount: _conversations.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final chat = _conversations[index];
                  
                  // Logic to find "The Other Person" name
                  // (The API returns a list of participants. We need the one that isn't ME.)
                  // For simplicity, we'll just grab the first username for now, 
                  // but in production, you'd check IDs.
                  final participants = chat['participants'] as List;
                  final String title = participants.map((p) => p['username']).join(", "); 
                  
                  final lastMsg = chat['last_message'] != null 
                      ? chat['last_message']['text'] 
                      : "Start chatting...";

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      title, 
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      lastMsg, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      // Open the chat with the Conversation ID directly
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            conversationId: chat['id'],
                            recipientName: title,
                          ),
                        ),
                      ).then((_) => _fetchConversations()); // Refresh when coming back
                    },
                  );
                },
              ),
    );
  }
}
