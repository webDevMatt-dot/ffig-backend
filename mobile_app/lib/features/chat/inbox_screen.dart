import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:async'; // Required for Timer
import 'package:intl/intl.dart';
import '../../shared_widgets/user_avatar.dart';
import 'chat_screen.dart'; 
import '../../core/api/constants.dart';
import '../../core/theme/ffig_theme.dart';
import '../community/public_profile_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class MiniProfileCard extends StatelessWidget {
  final String username;
  final String? bio;
  final String? photoUrl;
  final String? tier;
  final VoidCallback onViewProfile;

  const MiniProfileCard({
      super.key, 
      required this.username, 
      this.bio, 
      this.photoUrl, 
      this.tier,
      required this.onViewProfile
  });

  @override
  Widget build(BuildContext context) {
      return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      UserAvatar(radius: 40, imageUrl: photoUrl, username: username),
                      const SizedBox(height: 12),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          if (tier == 'PREMIUM') ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: Colors.amber, size: 20),
                          ]
                      ]),
                      if (bio != null && bio!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(bio!, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[600]))
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                          onPressed: onViewProfile,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: FfigTheme.primaryBrown,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
                          ),
                          child: const Text("View Full Profile")
                      )
                  ],
              ),
          ),
      );
  }
}

class _InboxScreenState extends State<InboxScreen> {
  bool _isLoading = true;
  List<dynamic> _conversations = [];
  String? _myUsername;
  Timer? _timer;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedFilter = 'all'; // 'all', 'unread', 'favorites'

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserAndConversations();
    // Refresh every 5 seconds for "Live" counts
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        // Only refresh if NOT searching (to avoid overwriting search results with full list)
        if (_searchController.text.isEmpty) {
            _fetchCurrentUserAndConversations(silent: true);
        }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserAndConversations({bool silent = false, String? search}) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    // 1. Fetch "Me" (Only once needed really, but kept for simplicity)
    if (_myUsername == null) {
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
    }

    // 2. Fetch Conversations
    try {
      final uri = Uri.parse('${baseUrl}chat/conversations/').replace(
          queryParameters: {
              'filter': _selectedFilter,
              if (search != null && search.isNotEmpty) 'search': search,
          }
      );

      final response = await http.get(
        uri, 
        headers: {'Authorization': 'Bearer $token'}
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            // Parse response - handle both list and paginated response formats
            var responseData = jsonDecode(response.body);
            List<dynamic> allConversations;
            
            // If response is a list, use directly
            if (responseData is List) {
              allConversations = responseData;
            } 
            // If response is a dict with 'results' (paginated), extract results
            else if (responseData is Map && responseData.containsKey('results')) {
              allConversations = responseData['results'] as List;
            }
            // Fallback
            else {
              allConversations = [];
            }
            
            // Sort by Last Message Timestamp (Descending)
            allConversations.sort((a, b) {
                final aTimeStr = a['last_message']?['created_at'];
                final bTimeStr = b['last_message']?['created_at'];
                if (aTimeStr == null && bTimeStr == null) return 0;
                if (aTimeStr == null) return 1; // Put nulls at bottom
                if (bTimeStr == null) return -1;
                return DateTime.parse(bTimeStr).compareTo(DateTime.parse(aTimeStr));
            });

            // Filter out Self-Chats immediately
            _conversations = allConversations.where((c) {
                final participants = c['participants'] as List;
                final others = participants.where((p) => p['username'] != _myUsername).toList();
                return others.isNotEmpty;
            }).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted && !silent) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) print(e);
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  String _formatTimestamp(String? isoString) {
      if (isoString == null) return "";
      try {
        final date = DateTime.parse(isoString).toLocal();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        if (date.isAfter(today)) {
            return DateFormat('HH:mm').format(date);
        }
        if (date.isAfter(today.subtract(const Duration(days: 1)))) {
            return "Yesterday";
        }
        return DateFormat('MMM d').format(date);
      } catch (e) {
          return "";
      }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "MESSAGES", 
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            fontSize: 24,
          )
        ),
      ),
      body: Column(
        children: [
          // Premium Search Bar with Gradient
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: FfigTheme.primaryBrown.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
                decoration: InputDecoration(
                  hintText: "Search conversations...",
                  hintStyle: TextStyle(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    fontSize: 15,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.search,
                      color: FfigTheme.primaryBrown.withOpacity(0.6),
                      size: 20,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark 
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark 
                        ? Colors.white.withOpacity(0.1)
                        : FfigTheme.primaryBrown.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark 
                        ? Colors.white.withOpacity(0.1)
                        : FfigTheme.primaryBrown.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: FfigTheme.primaryBrown,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (val) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    _performSearch(val);
                  });
                  setState(() {});
                },
              ),
            ),
          ),
          
          // Premium Filter Chips (Only show if NOT searching)
          if (_searchController.text.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPremiumFilterChip('All', 'all'),
                  const SizedBox(width: 10),
                  _buildPremiumFilterChip('Unread', 'unread'),
                  const SizedBox(width: 10),
                  _buildPremiumFilterChip('Favourites', 'favorites'),
                ],
              ),
            ),
          ),
           
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: FfigTheme.primaryBrown.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.mail_outline,
                              size: 56,
                              color: FfigTheme.primaryBrown.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "No messages yet",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Start a conversation to get talking",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 120),
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final chat = _conversations[index];
                        final participants = chat['participants'] as List;
                        
                        // Filter ME out to get Title
                        final others = participants.where((p) => p['username'] != _myUsername).toList();
                        final String title = others.map((p) => p['username']).join(", ");
                        
                        final lastMsg = chat['last_message'] != null 
                            ? chat['last_message']['text'] 
                            : "Start chatting...";
                        
                        final int unreadCount = chat['unread_count'] ?? 0; 
                        final bool isUnread = unreadCount > 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatScreen(
                                      conversationId: chat['id'],
                                      recipientId: others.isNotEmpty ? others.first['id'] : null,
                                      recipientName: title,
                                    ),
                                  ),
                                ).then((_) => _fetchCurrentUserAndConversations(silent: true));
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isUnread
                                    ? FfigTheme.primaryBrown.withOpacity(0.08)
                                    : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isUnread
                                      ? FfigTheme.primaryBrown.withOpacity(0.2)
                                      : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                                    width: isUnread ? 1.5 : 1,
                                  ),
                                  boxShadow: isUnread
                                    ? [
                                        BoxShadow(
                                          color: FfigTheme.primaryBrown.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    // Avatar with tap for profile
                                    InkWell(
                                      onTap: () {
                                        final targetUser = others.isNotEmpty ? others.first : null;
                                        if (targetUser != null) {
                                          showDialog(
                                            context: context,
                                            builder: (context) => MiniProfileCard(
                                              username: targetUser['username'],
                                              photoUrl: targetUser['photo'] ?? targetUser['photo_url'], 
                                              tier: targetUser['tier'],
                                              onViewProfile: () {
                                                Navigator.pop(context);
                                                Navigator.push(context, MaterialPageRoute(builder: (c) => PublicProfileScreen(
                                                  userId: targetUser['id'],
                                                  username: targetUser['username'],
                                                )));
                                              }
                                            )
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: UserAvatar(
                                          radius: 26,
                                          username: title,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Title and Message
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                              fontSize: 15,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            lastMsg,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isUnread
                                                ? theme.colorScheme.onSurface.withOpacity(0.75)
                                                : theme.textTheme.bodySmall?.color?.withOpacity(0.65),
                                              fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Time and Badge
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatTimestamp(chat['last_message']?['created_at']),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                                            color: isUnread
                                              ? FfigTheme.primaryBrown
                                              : theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (unreadCount > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  FfigTheme.primaryBrown,
                                                  FfigTheme.primaryBrown.withOpacity(0.85),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: FfigTheme.primaryBrown.withOpacity(0.3),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              unreadCount > 9 ? "9+" : unreadCount.toString(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  // --- NEW SEARCH UI ---
  Widget _buildSearchResults() {
    final users = _searchResults['users'] as List;
    final messages = _searchResults['messages'] as List;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 16, bottom: 120),
      children: [
        if (users.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              "USERS",
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ),
          ...users.where((u) => u['username'] != _myUsername).map((u) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                    recipientId: u['id'],
                    recipientName: u['username'],
                  )));
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: FfigTheme.primaryBrown.withOpacity(0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      UserAvatar(radius: 22, username: u['username'], imageUrl: u['photo_url']),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          u['username'],
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: FfigTheme.primaryBrown.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          color: FfigTheme.primaryBrown,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )),
          const Divider(height: 28, indent: 4, endIndent: 4),
        ],
        
        if (messages.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              "MESSAGES",
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ),
          ...messages.map((m) {
            final senderName = m['sender']['username'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                      conversationId: m['conversation_id'],
                      recipientName: m['chat_title'] ?? "Chat",
                    )));
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: FfigTheme.primaryBrown.withOpacity(0.15),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        UserAvatar(radius: 22, username: senderName),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                m['chat_title'] ?? "Chat",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              RichText(
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.65),
                                    fontSize: 13,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: "$senderName: ",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: FfigTheme.primaryBrown.withOpacity(0.8),
                                      ),
                                    ),
                                    TextSpan(text: m['text']),
                                  ],
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
            );
          }),
        ],
        
        if (users.isEmpty && messages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: FfigTheme.primaryBrown.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.search_off,
                      size: 40,
                      color: FfigTheme.primaryBrown.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No results found",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Try a different search term",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Map<String, dynamic> _searchResults = {'users': [], 'messages': []};

  Future<void> _performSearch(String query) async {
       if (query.isEmpty) {
           setState(() => _searchResults = {'users': [], 'messages': []});
           return;
       }
       setState(() => _isLoading = true);
       
       try {
           const storage = FlutterSecureStorage();
           final token = await storage.read(key: 'access_token');
           final uri = Uri.parse('${baseUrl}chat/search/?q=$query');
           
           final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
           if (response.statusCode == 200) {
               if (mounted) {
                   final data = jsonDecode(response.body);
                   setState(() {
                       _searchResults = data;
                       _isLoading = false;
                   });
                   if ((data['users'] as List).isEmpty && (data['messages'] as List).isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No results found."), duration: Duration(seconds: 1)));
                   }
               }
           } else {
               if (mounted) {
                   setState(() => _isLoading = false);
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Search failed: ${response.statusCode}")));
               }
           }
       } catch (e) {
           if (mounted) { 
               setState(() => _isLoading = false);
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
           }
       }
  }
  Widget _buildPremiumFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        if (_selectedFilter != value) {
          setState(() {
            _selectedFilter = value;
            _isLoading = true;
          });
          _fetchCurrentUserAndConversations();
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
            ? FfigTheme.primaryBrown
            : (isDark ? Colors.white.withOpacity(0.08) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
              ? FfigTheme.primaryBrown
              : FfigTheme.primaryBrown.withOpacity(0.2),
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
            ? [
                BoxShadow(
                  color: FfigTheme.primaryBrown.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
              ? Colors.white
              : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
