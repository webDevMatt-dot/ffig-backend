import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:async'; // For timer
import '../../core/theme/ffig_theme.dart';
import '../../core/api/constants.dart';

class ChatScreen extends StatefulWidget {
  final int? conversationId;
  final int? recipientId;
  final String recipientName;

  const ChatScreen({super.key, this.conversationId, this.recipientId, required this.recipientName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _messages = [];
  int? _activeConversationId;
  Timer? _timer;
  bool _isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    _activeConversationId = widget.conversationId;
    _fetchMessages();
    // Auto-refresh every 5 seconds (Simple "Real-time")
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) => _fetchMessages(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (_activeConversationId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
    }

    final token = await const FlutterSecureStorage().read(key: 'access_token');
    final String url = '${baseUrl}chat/conversations/$_activeConversationId/messages/';

    try {
      final response = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        if (mounted) {
           setState(() {
             _messages = jsonDecode(response.body);
             _isLoading = false;
           });
        }
      }
    } catch (e) {
      if (kDebugMode) print(e);
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;
    final text = _controller.text;
    _controller.clear(); // Clear input immediately for UX
    // Optimistic Update could go here for even faster feel

    final token = await const FlutterSecureStorage().read(key: 'access_token');
    final String url = '${baseUrl}chat/messages/send/';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'recipient_id': widget.recipientId, // Used for the FIRST message
          'conversation_id': _activeConversationId // Used for replies
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // If this was a new chat, we now have an ID!
        if (_activeConversationId == null) {
          setState(() => _activeConversationId = data['conversation_id']);
        }
        _fetchMessages(silent: true); // Refresh immediately
      }
    } catch (e) {
      if (kDebugMode) print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipientName),
        elevation: 1,
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                  final isMe = msg['is_me'];
                  final isRead = msg['is_read'] ?? false;
                  final username = msg['sender']['username'] ?? 'Unknown';
                  final createdAt = DateTime.parse(msg['created_at']).toLocal();
                  final timeString = "${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}";

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(username, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                if (msg['sender']['tier'] == 'PREMIUM') ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: Colors.amber, size: 14),
                                ] else if (msg['sender']['tier'] == 'STANDARD') ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: FfigTheme.primaryBrown, size: 14),
                                ]
                              ],
                            ),
                          ),
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? FfigTheme.accentBrown.withOpacity(0.2) : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isMe ? FfigTheme.accentBrown : Colors.grey.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg['text'],
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeString,
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      isRead ? Icons.done_all : Icons.check, 
                                      size: 14,
                                      color: isRead ? Colors.blueAccent : Colors.black54, 
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
              },
            ),
          ),
          // Input Bar
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
