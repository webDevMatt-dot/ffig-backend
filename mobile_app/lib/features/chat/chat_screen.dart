import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:async'; // For timer
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart'; // For Clipboard
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
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<int> _searchResults = []; // Indices in _groupedMessages
  int _currentSearchIndex = 0;
  
  // Timer for debouncing search
  Timer? _searchDebounce;

  Timer? _timer;
  bool _isLoading = true; // Add loading state
  Map<String, dynamic>? _replyMessage; // Swipe to reply state (Use Map instead of dynamic for type safety)
  final ItemScrollController _itemScrollController = ItemScrollController();
  int? _highlightedMessageId; // For highlighting searched message

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
    // 1. Resolve ID if missing
    if (_activeConversationId == null && widget.recipientId != null) {
        final id = await _fetchConversationIdByRecipient(widget.recipientId!);
        if (id != null) {
             setState(() => _activeConversationId = id);
        } else {
             // No chat yet
             if (mounted) setState(() => _isLoading = false);
             return; 
        }
    }

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
           setState(() => _messages = jsonDecode(response.body));
           _groupMessages(); // Only group after verify
           setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (kDebugMode) print(e);
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<int?> _fetchConversationIdByRecipient(int recipientId) async {
      try {
          final token = await const FlutterSecureStorage().read(key: 'access_token');
          final response = await http.get(
              Uri.parse('${baseUrl}chat/conversations/?recipient_id=$recipientId'),
              headers: {'Authorization': 'Bearer $token'}
          );
          
          if (response.statusCode == 200) {
              final List data = jsonDecode(response.body);
              if (data.isNotEmpty) {
                  return data[0]['id'];
              }
          }
      } catch (e) {
          if (kDebugMode) print("Error resolving chat: $e");
      }
      return null;
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
          if (_replyMessage != null) 'reply_to_id': _replyMessage!['id']
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

  void _toggleSearch() {
      setState(() {
          _isSearching = !_isSearching;
          if (!_isSearching) {
              _searchController.clear();
              _searchResults.clear();
              _currentSearchIndex = 0;
          }
      });
  }

  void _performInChatSearch(String query) {
      if (query.isEmpty) {
          setState(() => _searchResults.clear());
          return;
      }
      
      final lowerQuery = query.toLowerCase();
      // Find ALL matches. 
      // Note: _groupedMessages contains 'is_header' entries too. Skip them.
      // We search from NEWEST (index 0) to OLDEST.
      // But typically "Next" means older (up) or newer (down)?
      // WhatsApp: "Up" arrow goes to older messages (further up the list). "Down" goes to newer.
      // Our list is Reversed? List[0] is bottom.
      
      // Search Reversed (Newest First) so that "Next" goes to Older
      List<int> results = [];
      for (int i = _groupedMessages.length - 1; i >= 0; i--) {
          final item = _groupedMessages[i];
          if (item['is_header'] == true) continue;
          
          final text = (item['text'] ?? '').toString().toLowerCase();
          if (text.contains(lowerQuery)) {
              results.add(i);
          }
      }
      // Results are now [NewestIndex, ... OldestIndex] (since we iterated backwards from end? No.)
      // _groupedMessages: 0=Oldest, Max=Newest.
      // Loop Max down to 0.
      // First found is at Max (Newest).
      // So results[0] = Max (Newest).
      
      setState(() {
          _searchResults = results;
          _currentSearchIndex = 0; // Start at Newest
          if (results.isNotEmpty) {
               _scrollToMessage(results[0], indexMode: true);
          } else {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No matches found.")));
          }
      });
  }

  void _nextSearchResult() {
      if (_searchResults.isEmpty) return;
      setState(() {
          if (_currentSearchIndex < _searchResults.length - 1) {
              _currentSearchIndex++;
              _scrollToMessage(_searchResults[_currentSearchIndex], indexMode: true);
          } else {
             // Loop back or stay? Stay.
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No older matches."), duration: Duration(milliseconds: 500)));
          }
      });
  }

   void _prevSearchResult() {
      if (_searchResults.isEmpty) return;
      setState(() {
          if (_currentSearchIndex > 0) {
              _currentSearchIndex--;
              _scrollToMessage(_searchResults[_currentSearchIndex], indexMode: true);
          } else {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No newer matches."), duration: Duration(milliseconds: 500)));
          }
      });
  }


  void _scrollToMessage(int idOrIndex, {bool indexMode = false}) {
      // Find the message in our list
      int indexInData = -1;
      
      if (indexMode) {
          indexInData = idOrIndex;
      } else {
          indexInData = _groupedMessages.indexWhere((m) => m['id'] == idOrIndex);
      }
      
      if (indexInData != -1) {
          // Calculate Widget Index (Reverse Mapping)
          // List is rendered with reverse: true
          // Widget Index 0 = Data Last Item
          // Widget Index W = Data[Length - 1 - W]
          // So W = Length - 1 - DataIndex
          
          final widgetIndex = _groupedMessages.length - 1 - indexInData;
          
          if (_itemScrollController.isAttached) {
               _itemScrollController.scrollTo(
                   index: widgetIndex, 
                   duration: const Duration(milliseconds: 500),
                   curve: Curves.easeInOut,
               );
               
               // Highlight for 3 seconds
               final int targetId = indexMode ? _groupedMessages[indexInData]['id'] : idOrIndex;
               setState(() => _highlightedMessageId = targetId);
               Timer(const Duration(seconds: 3), () {
                   if (mounted) {
                       setState(() => _highlightedMessageId = null);
                   }
               });
          }
      } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Message not found (it might be too old).")));
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

  Future<void> _blockUser() async {
     try {
         final token = await const FlutterSecureStorage().read(key: 'access_token');
         final userId = widget.recipientId; 
         
         if (userId == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot block unknown user.")));
              return;
         }

         final response = await http.post(
              Uri.parse('${baseUrl}members/block/$userId/'),
              headers: {'Authorization': 'Bearer $token'}
         );

         if (response.statusCode == 200) {
              if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User blocked. You will no longer receive messages from them.")));
                   Navigator.pop(context); // Exit chat
              }
         } else {
             String msg = "Failed to block user";
             try {
                final body = jsonDecode(response.body);
                if (body['error'] != null) msg = body['error'];
             } catch (_) {}
             
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$msg (${response.statusCode})")));
         }
     } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error blocking user.")));
     }
  }

  void _reportUser(String? username) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Report ${username ?? 'User'}"),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                const Text("Please verify the reason for reporting this user:"),
                const SizedBox(height: 10),
                TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Reason..."),
                    maxLines: 3,
                )
            ]
        ),
        actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
                onPressed: () {
                    Navigator.pop(context);
                    if (reasonController.text.isNotEmpty) {
                        _sendReport(reasonController.text);
                    }
                }, 
                child: const Text("Report", style: TextStyle(color: Colors.red))
            ),
        ],
      ),
    );
  }

  Future<void> _sendReport(String reason) async {
       try {
           const storage = FlutterSecureStorage();
           final token = await storage.read(key: 'access_token');
           
           // Pack Context into Reason (Format: [CID:123] Reason)
           final fullReason = "[CID:$_activeConversationId] $reason";
           
           final response = await http.post(
               Uri.parse('${baseUrl}members/report/'),
               headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
               body: jsonEncode({
                   'reported_item_type': 'USER',
                   'reported_item_id': widget.recipientId?.toString() ?? 'unknown',
                   'reason': fullReason
               })
           );
           
           if (response.statusCode == 201) {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report submitted successfully.")));
           } else {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to submit report.")));
           }
       } catch (e) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error submitting report.")));
       }
  }

  Future<void> _onOpenLink(LinkableElement link) async {
    final uri = Uri.parse(link.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open link.")));
    }
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
      final isMe = msg['is_me'];
      final text = msg['text'];
      final username = msg['sender']['username'];

      showModalBottomSheet(
          context: context,
          builder: (context) => SafeArea(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      ListTile(
                          leading: const Icon(Icons.copy),
                          title: const Text("Copy Text"),
                          onTap: () async {
                              await Clipboard.setData(ClipboardData(text: text));
                              if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard"), duration: Duration(seconds: 1)));
                              }
                          },
                      ),
                      ListTile(
                          leading: const Icon(Icons.reply),
                          title: const Text("Reply"),
                          onTap: () {
                              Navigator.pop(context);
                              setState(() => _replyMessage = msg);
                          },
                      ),
                      if (!isMe)
                          ListTile(
                              leading: const Icon(Icons.flag, color: Colors.red),
                              title: const Text("Report User", style: TextStyle(color: Colors.red)),
                              onTap: () {
                                  Navigator.pop(context);
                                  _reportUser(username);
                              },
                          ),
                  ],
              ),
          ),
      );
  }

  Future<void> _toggleFavorite() async {
      int? targetId = widget.recipientId;
      
      // Fallback: Try to find from messages if null (e.g. came from push notification or simple ID link)
      if (targetId == null && _messages.isNotEmpty) {
          final firstMsg = _messages.first;
          if (firstMsg['sender']['id'] != null) { 
             // Logic check: ensure it's not ME
             targetId = firstMsg['sender']['id'];
          }
      }

      if (targetId == null) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot favorite this user (ID missing).")));
           return;
      }

      try {
          const storage = FlutterSecureStorage();
          final token = await storage.read(key: 'access_token');
          final response = await http.post(
              Uri.parse('${baseUrl}members/favorites/toggle/$targetId/'),
              headers: {'Authorization': 'Bearer $token'}
          );
          
          if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final isFav = data['is_favorite'];
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isFav ? "User added to favourites" : "User removed from favourites"),
                      backgroundColor: FfigTheme.primaryBrown,
                  ));
              }
          } else {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update favourites.")));
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network error updating favourites.")));
      }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCommunity = widget.recipientName == "Community Chat";

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _isSearching 
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.black87),
                cursorColor: FfigTheme.primaryBrown,
                decoration: InputDecoration(
                    hintText: "Search...",
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)
                ),
                onChanged: (val) {
                   if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
                   _searchDebounce = Timer(const Duration(milliseconds: 300), () => _performInChatSearch(val));
                },
              )
            : Text(widget.recipientName),
        elevation: 1,
        actions: _isSearching 
        ? [
            IconButton(
                icon: const Icon(Icons.keyboard_arrow_up), // Older (Up in list)
                onPressed: _nextSearchResult, // Next in Results (Older)
                tooltip: "Older",
            ),
            IconButton(
                icon: const Icon(Icons.keyboard_arrow_down), // Newer (Down in list)
                onPressed: _prevSearchResult, // Prev in Results (Newer)
                tooltip: "Newer",
            ),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSearch,
            ),
        ] 
        : [
            PopupMenuButton<String>(
                onSelected: (value) {
                    if (value == 'clear') _clearChat();
                    if (value == 'mute') _muteChat();
                    if (value == 'block') _blockUser();
                    if (value == 'report') _reportUser(widget.recipientName);
                    if (value == 'favorite') _toggleFavorite();
                    if (value == 'search') _toggleSearch();
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
                            const PopupMenuItem(value: 'favorite', child: Text("Favourite User")),
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
              : ScrollablePositionedList.builder(
              itemScrollController: _itemScrollController,
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
                final isHighlighted = msg['id'] == _highlightedMessageId;
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
                
                // Username Visibility Logic
                bool showUsername = false;
                if (isCommunity && !isMe) {
                    // List is REVERSED. Index 0 is bottom. Index MAX is top.
                    // Previous message (visually above) is at `index + 1`.
                    if (index == _groupedMessages.length - 1) {
                        // Topmost message always shows name (if it's a message)
                         showUsername = true; 
                    } else {
                        final nextMsg = _groupedMessages[index + 1]; // Visually above
                        // If it's a header or different sender, show name
                        if (nextMsg['is_header'] == true || 
                            nextMsg['sender']['id'] != msg['sender']['id']) {
                            showUsername = true;
                        }
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              // Name label only if group or just design choice. Let's keep name above bubble if not me
                              if (showUsername)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 2, top: 4),
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
                                     _showMessageOptions(msg);
                                },
                                child: Container(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Limit width to 75%
                                    decoration: BoxDecoration(
                                    color: isHighlighted 
                                        ? Colors.amber.withOpacity(0.4) 
                                        : (isMe 
                                            ? FfigTheme.primaryBrown 
                                            : (Theme.of(context).brightness == Brightness.dark 
                                                ? const Color(0xFF21262D) 
                                                : Colors.grey[200])), // Solid colors
                                    borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                        bottomRight: isMe ? Radius.zero : const Radius.circular(16)
                                    ),
                                    // Remove border for solid style, or keep subtle
                                    // border: Border.all(color: isMe ? FfigTheme.accentBrown : Colors.grey.withOpacity(0.2)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: IntrinsicWidth(
                                    child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, 
                                    children: [
                                      // SHOW REPLY CONTEXT
                                      if (replyContext != null)
                                          GestureDetector(
                                              onTap: () {
                                                  // Scroll to original message
                                                  if (replyContext != null) {
                                                       _scrollToMessage(replyContext['id']);
                                                  }
                                              },
                                              child: Container(
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
                                          ),
                                      
                                      Linkify(
                                        onOpen: _onOpenLink,
                                        text: msg['text'],
                                        style: TextStyle(fontSize: 16, color: isMe ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                                        linkStyle: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.none),
                                        options: const LinkifyOptions(humanize: false),
                                      ),
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end, // Align time right
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              timeString,
                                              style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey[600]),
                                            ),
                                            if (isMe && !isCommunity) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                isRead ? Icons.done_all : Icons.check, 
                                                size: 14,
                                                color: isRead ? Colors.blueAccent : Colors.white70, 
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
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
                          "Replying to ${_replyMessage!['sender']['username']}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          _replyMessage!['text'],
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
