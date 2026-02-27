import 'package:flutter/material.dart';
import 'dart:ui';
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
import 'package:cached_network_image/cached_network_image.dart';
import '../premium/widgets/story_viewer.dart';

/// The Main Chat Interface.
///
/// **Features:**
/// - Real-time messaging (via 5s polling).
/// - Message Grouping by Date.
/// - In-Chat Search.
/// - Reply, Copy, Report, and Block functionality.
/// - Supports both 1-on-1 DMs and Community Chat functionality.
class ChatScreen extends StatefulWidget {
  final int? conversationId;
  final int? recipientId;
  final String recipientName;
  final bool isCommunity;

  const ChatScreen({
    super.key, 
    this.conversationId, 
    this.recipientId, 
    required this.recipientName,
    this.isCommunity = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
// ... existing state variables ...
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _messages = [];
  List<dynamic> _groupedMessages = [];
  int? _activeConversationId;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<int> _searchResults = []; 
  int _currentSearchIndex = 0;
  
  // Timer for debouncing search
  Timer? _searchDebounce;

  Timer? _timer;
  bool _isLoading = true; 
  Map<String, dynamic>? _replyMessage; 
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create(); 
  bool _showScrollToBottom = false; 
  int? _highlightedMessageId; 

  @override
  void initState() {
    super.initState();
    _activeConversationId = widget.conversationId;
    _fetchMessages();
    // Auto-refresh every 5 seconds (Simple "Real-time")
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) => _fetchMessages(silent: true));

    // Listen to scroll position
    _itemPositionsListener.itemPositions.addListener(() {
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
          // Check if index 0 (bottom-most message in reversed list) is visible
          final isAtBottom = positions.any((p) => p.index == 0);
          
          // Show button if NOT at bottom (index 0 not visible)
          if (_showScrollToBottom == isAtBottom) {
              setState(() => _showScrollToBottom = !isAtBottom);
          }
      }
    });
  }

  // ... (dispose, groupMessages, getDateLabel, fetchMessages, fetchConversationIdByRecipient, sendMessage, toggleSearch, performInChatSearch, nextSearchResult, prevSearchResult, scrollToMessage, clearChat, muteChat, blockUser, reportUser, sendReport, onOpenLink, showMessageOptions, toggleFavorite) ...
  // Keeping mostly unchanged, just showing the widget definition change above for context match if needed, 
  // but let's target specific blocks to be safe and avoid huge replacement.


  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Groups messages by Date for the UI.
  /// - Inserts 'header' items into `_groupedMessages`.
  /// - Assumes input `_messages` is sorted.
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

  /// Fetches messages for the active conversation.
  /// - Resolves `conversationId` if only `recipientId` is known.
  /// - Groups messages by date for UI rendering.
  /// - Polls every 5 seconds for updates (if `silent` is true).
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

  // --- Logic to Open Story from Reply ---
  Future<void> _checkAndOpenStory(int storyId) async {
      try {
          const storage = FlutterSecureStorage();
          final token = await storage.read(key: 'access_token');
          
          final response = await http.get(
              Uri.parse('${baseUrl}members/stories/$storyId/'),
              headers: {'Authorization': 'Bearer $token'}
          );

          if (response.statusCode == 200) {
              // Story Exists -> Open Viewer
              final storyData = jsonDecode(response.body);
              
              // Normalize URLs
              final domain = baseUrl.replaceAll('/api/', '');
              if (storyData['media_url'] != null) {
                 String url = storyData['media_url'].toString();
                 if (url.startsWith('/')) storyData['media_url'] = '$domain$url';
                 else if (url.contains('localhost')) {
                    try { final uri = Uri.parse(url); storyData['media_url'] = '$domain${uri.path}'; } catch (_) {}
                 }
              }
              if (storyData['user_photo'] != null) {
                  String photo = storyData['user_photo'].toString();
                  if (photo.startsWith('/')) storyData['user_photo'] = '$domain$photo';
                  else if (photo.contains('localhost')) {
                    try { final uri = Uri.parse(photo); storyData['user_photo'] = '$domain${uri.path}'; } catch (_) {}
                 }
              }

              if (mounted) {
                  showGeneralDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: 'Story',
                      barrierColor: Colors.black,
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (_, __, ___) {
                        return StoryViewer(
                          stories: [storyData], // Only this story
                          initialIndex: 0,
                          onGlobalClose: () => Navigator.pop(context),
                        );
                      },
                  );
              }
          } else if (response.statusCode == 404) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Story no longer available (expired or deleted).")));
          } else {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not load story.")));
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error connecting to server.")));
      }
  }

  /// Sends a message.
  /// - Handles optimistic local update (TODO).
  /// - Posts to `/chat/messages/send/`.
  /// - Updates conversation ID if it was new.
  /// - Auto-scrolls to bottom.
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
        
        // Auto-scroll to bottom (Index 0 in reversed list)
        Future.delayed(const Duration(milliseconds: 100), () {
             if (_itemScrollController.isAttached) {
                 _itemScrollController.scrollTo(index: 0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
             }
        });
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

  /// Performs local search within the chat history.
  /// - Scans `_groupedMessages`.
  /// - Populates `_searchResults` with indices.
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


  /// Scrolls to a specific message ID or Index.
  /// - `idOrIndex`: Message ID or List Index (depending on `indexMode`).
  /// - Calculates reverse-list index.
  /// - Highlights the message temporarily.
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

  Future<void> _clearChat() async {
    try {
        final token = await const FlutterSecureStorage().read(key: 'access_token');
        final response = await http.post(
            Uri.parse('${baseUrl}chat/conversations/$_activeConversationId/clear/'),
            headers: {'Authorization': 'Bearer $token'}
        );
        
        if (response.statusCode == 200) {
            setState(() {
                _messages.clear();
                _groupedMessages.clear();
            });
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat cleared.")));
        } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to clear chat.")));
        }
    } catch (e) {
        // Fallback to local clear if offline or error, though data will return on reload
        setState(() {
            _messages.clear();
            _groupedMessages.clear();
        });
    }
  }

  Future<void> _muteChat() async {
    try {
        final token = await const FlutterSecureStorage().read(key: 'access_token');
        final response = await http.post(
            Uri.parse('${baseUrl}chat/conversations/$_activeConversationId/mute/'),
            headers: {'Authorization': 'Bearer $token'}
        );
        
        if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final isMuted = data['is_muted'];
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isMuted ? "Chat muted." : "Chat unmuted.")));
        } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to mute/unmute chat.")));
        }
    } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error muting chat.")));
    }
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
    final bool isCommunity = widget.isCommunity;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Explicitly set to avoid grey default
      resizeToAvoidBottomInset: true, // Ensure layout resizes for keyboard
      extendBodyBehindAppBar: true, // Allow content to scroll behind glass AppBar
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.7),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: _isSearching 
            ? Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: theme.textTheme.bodyLarge,
                  cursorColor: FfigTheme.primaryBrown,
                  decoration: InputDecoration(
                      hintText: "Search chat...",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0)
                  ),
                  onChanged: (val) {
                     if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
                     _searchDebounce = Timer(const Duration(milliseconds: 300), () => _performInChatSearch(val));
                  },
                ),
              )
            : Text(
                widget.recipientName.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 16),
              ),
        shape: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
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
                            const PopupMenuItem(value: 'favorite', child: Text("Star User")),
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
              itemPositionsListener: _itemPositionsListener,
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
                    showUsername = true; // Always show in Community Chat
                } else if (!isMe) {
                    // Normal Grouping for DM
                    if (index == _groupedMessages.length - 1) {
                         showUsername = true; 
                    } else {
                        final nextMsg = _groupedMessages[index + 1];
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
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                      decoration: BoxDecoration(
                                        color: isHighlighted 
                                            ? Colors.amber.withOpacity(0.4) 
                                            : (isMe 
                                                ? null // Uses gradient below
                                                : (theme.brightness == Brightness.dark 
                                                    ? Colors.white.withOpacity(0.08)
                                                    : Colors.black.withOpacity(0.05))),
                                        gradient: (!isHighlighted && isMe) ? const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [FfigTheme.primaryBrown, Color(0xFF8D6E63)],
                                        ) : null,
                                        borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(20),
                                            topRight: const Radius.circular(20),
                                            bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                                            bottomRight: isMe ? Radius.zero : const Radius.circular(20)
                                        ),
                                        border: !isMe ? Border.all(
                                          color: Colors.white.withOpacity(0.1),
                                          width: 0.5,
                                        ) : null,
                                      ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: IntrinsicWidth(
                                    child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, 
                                    children: [
                                      // --- STORY REPLY PREVIEW ---
                                      if (msg['metadata'] != null && msg['metadata']['type'] == 'story_reply')
                                        GestureDetector(
                                            onTap: () {
                                                final storyId = msg['metadata']['story_id'];
                                                if (storyId != null) _checkAndOpenStory(storyId);
                                            },
                                            child: Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border(left: BorderSide(color: isMe ? Colors.white70 : FfigTheme.primaryBrown, width: 4))
                                                ),
                                                child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                        // Thumbnail
                                                        ClipRRect(
                                                            borderRadius: BorderRadius.circular(4),
                                                            child: CachedNetworkImage(
                                                                imageUrl: msg['metadata']['media_url'] ?? '',
                                                                width: 40,
                                                                height: 60,
                                                                fit: BoxFit.cover,
                                                                errorWidget: (c,u,e) => Container(width: 40, height: 60, color: Colors.grey, child: const Icon(Icons.broken_image, size: 16)),
                                                            ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        // Label
                                                        Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                                Text(
                                                                    isMe ? "You replied to their story" : "Replied to your story",
                                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.black87),
                                                                ),
                                                                const SizedBox(height: 2),
                                                                if (msg['metadata']['is_video'] == true)
                                                                    const Icon(Icons.videocam, size: 12, color: Colors.grey)
                                                            ],
                                                        )
                                                    ],
                                                ),
                                            ),
                                        ),

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
                                                  decoration: BoxDecoration(
                                                      color: const Color(0xFFc29a77), // Fixed Accent Brown
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
          // Glass Bottom Section
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply Preview
                      if (_replyMessage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.05),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.reply, color: FfigTheme.primaryBrown, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Replying to ${_replyMessage!['sender']['username']}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 11,
                                        color: FfigTheme.primaryBrown,
                                      ),
                                    ),
                                    Text(
                                      _replyMessage!['text'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.grey[400], 
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                                onPressed: () => setState(() => _replyMessage = null),
                              )
                            ],
                          ),
                        ),
                      
                      // Input Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  controller: _controller,
                                  keyboardType: TextInputType.multiline,
                                  maxLines: 5,
                                  minLines: 1,
                                  textCapitalization: TextCapitalization.sentences,
                                  style: const TextStyle(fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: "Type a message...",
                                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _sendMessage,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: FfigTheme.primaryBrown,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _showScrollToBottom 
        ? Padding(
            padding: const EdgeInsets.only(bottom: 80.0), // Above input area
            child: FloatingActionButton(
                mini: true,
                backgroundColor: FfigTheme.primaryBrown,
                child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                onPressed: () {
                    if (_itemScrollController.isAttached) {
                        _itemScrollController.scrollTo(
                            index: 0, 
                            duration: const Duration(milliseconds: 500), 
                            curve: Curves.easeInOut
                        );
                    }
                },
            ),
        )
        : null,
    );
  }

}
