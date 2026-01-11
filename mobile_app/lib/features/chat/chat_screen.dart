import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:async'; // For timer
import 'package:intl/intl.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/api/constants.dart';
import '../../shared_widgets/user_avatar.dart';
import '../community/public_profile_screen.dart';

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
  List<dynamic> _groupedMessages = [];
  int? _activeConversationId;
  Timer? _timer;
  bool _isLoading = true; // Add loading state
  dynamic _replyMessage; // Swipe to reply state

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

  void _groupMessages() {
    final List<dynamic> grouped = [];
    DateTime? lastDate;

    // Assumes _messages is sorted Oldest -> Newest
    for (var msg in _messages) {
      final createdAt = DateTime.parse(msg['created_at']).toLocal();
      final date = DateTime(createdAt.year, createdAt.month, createdAt.day); // Strip time

      if (lastDate == null || date != lastDate) {
        grouped.add({'is_header': true, 'date': date});
        lastDate = date;
      }
      grouped.add(msg);
    }
    _groupedMessages = grouped;
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return "Today";
    if (date == yesterday) return "Yesterday";
    return DateFormat('MMMM d, yyyy').format(date);
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
             _groupMessages();
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
          'conversation_id': _activeConversationId, // Used for replies
          if (_replyMessage != null) 'reply_to_id': _replyMessage['id']
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // If this was a new chat, we now have an ID!
        if (_activeConversationId == null) {
          setState(() => _activeConversationId = data['conversation_id']);
        }
        setState(() {
            _replyMessage = null;
        });
        _fetchMessages(silent: true); // Refresh immediately
      }
    } catch (e) {
      if (kDebugMode) print(e);
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _groupedMessages.clear();
    });
  }

  void _muteChat() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat muted.")));
  }

  void _blockUser() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User blocked.")));
  }

  void _reportUser(String? username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Report ${username ?? 'User'}?"),
        content: const Text("Would you like to report this user for inappropriate behavior?"),
        actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
                onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User reported. Thank you.")));
                }, 
                child: const Text("Report", style: TextStyle(color: Colors.red))
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCommunity = widget.recipientName == "Community Chat";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipientName),
        elevation: 1,
        actions: [
            PopupMenuButton<String>(
                onSelected: (value) {
                    if (value == 'clear') _clearChat();
                    if (value == 'mute') _muteChat();
                    if (value == 'block') _blockUser();
                    if (value == 'report') _reportUser(widget.recipientName);
                    if (value == 'search') {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Search feature coming soon.")));
                    }
                },
                itemBuilder: (BuildContext context) {
                    if (isCommunity) {
                        return [
                            const PopupMenuItem(value: 'search', child: Text("Search")),
                            const PopupMenuItem(value: 'mute', child: Text("Mute Notifications")),
                            const PopupMenuItem(value: 'clear', child: Text("Clear Chat")),
                        ];
                    } else {
                        return [
                            const PopupMenuItem(value: 'search', child: Text("Search")),
                            const PopupMenuItem(value: 'mute', child: Text("Mute Chat")),
                            const PopupMenuItem(value: 'clear', child: Text("Clear Chat")),
                            const PopupMenuItem(value: 'block', child: Text("Block User")),
                            const PopupMenuItem(value: 'report', child: Text("Report User")),
                        ];
                    }
                },
            ),
        ],
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : ListView.builder(
              padding: const EdgeInsets.all(16),
              reverse: true, // Start from bottom
              itemCount: _groupedMessages.length,
              itemBuilder: (context, index) {
                // With reverse: true, index 0 is Bottom (Last Item in List).
                final item = _groupedMessages[_groupedMessages.length - 1 - index];
                
                if (item['is_header'] == true) {
                    return Center(
                        child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                                _getDateLabel(item['date']),
                                style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.bold),
                            ),
                        ),
                    );
                }

                final msg = item;
                final isMe = msg['is_me'];
                final isRead = msg['is_read'] ?? false;
                final username = msg['sender']['username'] ?? 'Unknown';
                final createdAt = DateTime.parse(msg['created_at']).toLocal();
                final timeString = "${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}";

                // Resolve Reply
                final replyId = msg['reply_to_id'] ?? (msg['reply_to'] is int ? msg['reply_to'] : (msg['reply_to'] != null ? msg['reply_to']['id'] : null));
                Map<String, dynamic>? replyContext;
                
                // Try to find replied message locally if not fully populated
                if (replyId != null) {
                    if (msg['reply_to'] is Map) {
                        replyContext = msg['reply_to'];
                    } else {
                        // Find locally
                         try {
                             final found = _messages.firstWhere((m) => m['id'] == replyId, orElse: () => null);
                             if (found != null) replyContext = found;
                         } catch (e) { /* ignore */ }
                    }
                }

                return Dismissible(
                  key: Key(msg['id'].toString()),
                  direction: DismissDirection.startToEnd,
                  confirmDismiss: (direction) async {
                    setState(() {
                      _replyMessage = msg;
                    });
                    // Vibrate or sound could go here
                    return false; // Don't actually dismiss
                  },
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    color: Colors.grey[200],
                    child: const Icon(Icons.reply, color: FfigTheme.primaryBrown),
                  ),
                  child: Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end, // Align avatar to bottom of bubble
                    children: [
                      if (!isMe) ...[
                        GestureDetector(
                          onTap: () {
                             // Navigate to Public Profile
                             Navigator.push(context, MaterialPageRoute(builder: (c) => PublicProfileScreen(
                                userId: msg['sender']['id'],
                                username: username,
                                initialData: msg['sender'], // Pass data we already have
                             )));
                          },
                          behavior: HitTestBehavior.opaque, // Ensure clicks are caught
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
                            child: UserAvatar(
                                radius: 16, // Small avatar
                                imageUrl: msg['sender']['photo'] ?? msg['sender']['photo_url'],
                                username: username,
                            ),
                          ),
                        ),
                      ],
                      Flexible( // Use Flexible to allow shrinking
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              // Name label only if group or just design choice. Let's keep name above bubble if not me
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(username, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                                      if (msg['sender']['tier'] == 'PREMIUM') ...[
                                        const SizedBox(width: 2),
                                        const Icon(Icons.verified, color: Colors.amber, size: 10),
                                      ]
                                    ],
                                  ),
                                ),
                              GestureDetector(
                                onLongPress: () {
                                     if (!isMe) _reportUser(username);
                                },
                                child: Container(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Limit width
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isMe ? FfigTheme.accentBrown.withOpacity(0.2) : Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                        bottomRight: isMe ? Radius.zero : const Radius.circular(16)
                                    ),
                                    border: Border.all(color: isMe ? FfigTheme.accentBrown : Colors.grey.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, // Align text start inside bubble
                                    children: [
                                      // SHOW REPLY CONTEXT
                                      if (replyContext != null)
                                          Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border(left: BorderSide(color: FfigTheme.primaryBrown, width: 3))
                                              ),
                                              child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                      Text(
                                                          replyContext['sender']['username'] ?? 'User', 
                                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: FfigTheme.primaryBrown)
                                                      ),
                                                      Text(
                                                          replyContext['text'] ?? '', 
                                                          maxLines: 1, 
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(fontSize: 10, color: Colors.black54)
                                                      ),
                                                  ],
                                              ),
                                          ),
                                      
                                      Text(
                                        msg['text'],
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Row(
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
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ),
                    ],
                  ),
                ));
              },
            ),
          ),
          // Reply Preview
          if (_replyMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.reply, color: FfigTheme.primaryBrown),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Replying to ${_replyMessage['sender']['username']}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          _replyMessage['text'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _replyMessage = null),
                  )
                ],
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
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

