import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../../shared_widgets/user_avatar.dart';
import 'chat_screen.dart'; 
import 'chat_screen.dart'; 
import '../../core/api/constants.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;
  String? _myUsername;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserAndConversations();
  }

  Future<void> _fetchCurrentUserAndConversations() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    // 1. Fetch "Me" to know who I am
    try {
      final meResponse = await http.get(
        // Use the same URL structure as MemberListScreen
        Uri.parse('${baseUrl}members/me/'), 
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (meResponse.statusCode == 200) {
        final meData = jsonDecode(meResponse.body);
        _myUsername = meData['username'];
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching me: $e");
    }

    // 2. Fetch Conversations
    // const String baseUrl = '...';
    
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}chat/conversations/'), 
        headers: {'Authorization': 'Bearer $token'}
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _conversations = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print(e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getOtherParticipantName(List<dynamic> participants) {
    if (_myUsername == null) {
        // Fallback if we failed to fetch "me"
        // Return everybody joined
        return participants.map((p) => p['username']).join(", ");
    }
    
    // Filter ME out
    final others = participants.where((p) => p['username'] != _myUsername).toList();
    if (others.isEmpty) return "Me (Draft)"; // Should typically not happen in normal chats
    
    return others.map((p) => p['username']).join(", ");
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
                         // Navigation logic if needed
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
                  final participants = chat['participants'] as List;
                  
                  // Clean Name
                  final String title = _getOtherParticipantName(participants);
                  
                  final lastMsg = chat['last_message'] != null 
                      ? chat['last_message']['text'] 
                      : "Start chatting...";
                  
                  // Live Count Logic
                  // Assuming API structure. If not present, we default to 0.
                  // Or we confirm unread logic.
                  // For now, let's look for 'unread_count' from the backend.
                  // If not explicitly sent, we can check basic `is_read` of last message if NOT me.
                  final int unreadCount = chat['unread_count'] ?? 0; 

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: UserAvatar(
                      radius: 24, 
                      username: title,
                    ),
                    title: Text(
                      title, 
                      style: TextStyle(
                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      lastMsg, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unreadCount > 0 ? Colors.black87 : Colors.grey,
                        fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary, // Using Theme Color
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                           const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            conversationId: chat['id'],
                            recipientName: title,
                          ),
                        ),
                      ).then((_) => _fetchCurrentUserAndConversations()); // Refresh on return
                    },
                  );
                },
              ),
    );
  }
}
