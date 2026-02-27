import 'package:flutter/material.dart';
import 'dart:ui';
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
import 'community_chat_screen.dart';
import '../../core/services/admin_api_service.dart'; // Import Service

/// Displays the User's Message Inbox.
///
/// **Features:**
/// - Lists recent conversations.
/// - Filters: All, Unread, Favorites.
/// - Search functionality (Users and Messages).
/// - Quick access to "Community Chat".
/// - Shows Unread Counts.
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
  int _communityUnreadCount = 0; // New State
  final _apiService = AdminApiService(); // Instantiate Helper

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserAndConversations();
    _fetchCommunityUnreadCount(); // Initial Fetch
    // Refresh every 5 seconds for "Live" counts
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        // Only refresh if NOT searching (to avoid overwriting search results with full list)
        if (_searchController.text.isEmpty) {
            _fetchCurrentUserAndConversations(silent: true);
            _fetchCommunityUnreadCount(); // Poll Community Count
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

  /// Fetches the user's conversations and "Me" profile.
  /// - Supports filtering (all/unread/favorites).
  /// - Supports searching.
  /// - Sorts conversations by last message timestamp.
  /// - Filters out self-chats.
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
            final allConversations = jsonDecode(response.body) as List;
            
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

  // New Method to fetch count
  Future<void> _fetchCommunityUnreadCount() async {
      try {
          final count = await _apiService.fetchCommunityUnreadCount();
          if (mounted && count != _communityUnreadCount) {
              setState(() => _communityUnreadCount = count);
          }
      } catch (_) {}
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

  /// Builds the list of conversations or the empty state.
  /// - Supports loading state.
  /// - Filters out empty matches during search.
  /// - Renders `ListTile` for each conversation with unread count and last message.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.7),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: Text(
          "MESSAGES", 
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          )
        ),
        shape: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
           // Search Bar
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
             child: Container(
               decoration: BoxDecoration(
                 color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                 borderRadius: BorderRadius.circular(30),
                 border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
               ),
               child: TextField(
                 controller: _searchController,
                 style: theme.textTheme.bodyLarge,
                 decoration: InputDecoration(
                     hintText: "Search messages...",
                     hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.5)),
                     prefixIcon: Icon(Icons.search, color: FfigTheme.primaryBrown.withOpacity(0.5)),
                     border: InputBorder.none,
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
                 ),
                 onChanged: (val) {
                     if (_debounce?.isActive ?? false) _debounce!.cancel();
                     _debounce = Timer(const Duration(milliseconds: 500), () {
                         _performSearch(val);
                     });
                     // Force rebuild to switch view
                     setState(() {});
                 },
               ),
             ),
           ),
           
           // Filter Chips (Only show if NOT searching)
           if (_searchController.text.isEmpty)
           SingleChildScrollView(
             scrollDirection: Axis.horizontal,
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             child: Row(
               children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Unread', 'unread'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Favourites', 'favorites'),
               ],
             ),
           ),

           // Community Chat Pinned Entry
           if (_searchController.text.isEmpty) _buildCommunityChatTile(),
           
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
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: FfigTheme.primaryBrown.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.mail_outline, size: 48, color: FfigTheme.primaryBrown.withOpacity(0.5))
                    ),
                    const SizedBox(height: 16),
                    Text("No messages yet.", style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18, color: theme.textTheme.bodyMedium?.color)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
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

                  return Container(
                    decoration: BoxDecoration(
                      color: isUnread ? (isDark ? Colors.white.withOpacity(0.05) : Colors.white) : Colors.transparent, // Highlight unread
                      border: Border(bottom: BorderSide(color: theme.dividerColor))
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: InkWell(
                          onTap: () {
                               // Show Mini Profile
                               final targetUser = others.isNotEmpty ? others.first : null;
                               if (targetUser != null) {
                                    showDialog(
                                        context: context,
                                        builder: (context) => MiniProfileCard(
                                            username: targetUser['username'],
                                            photoUrl: targetUser['photo'] ?? targetUser['photo_url'], 
                                            tier: targetUser['tier'],
                                            onViewProfile: () {
                                                Navigator.pop(context); // Close dialog
                                                Navigator.push(context, MaterialPageRoute(builder: (c) => PublicProfileScreen(
                                                    userId: targetUser['id'],
                                                    username: targetUser['username'],
                                                )));
                                            }
                                        )
                                    );
                               }
                          },
                          child: UserAvatar(
                            radius: 28, 
                            username: title,
                          ),
                      ),
                      title: Text(
                        title, 
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          lastMsg, 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isUnread ? theme.colorScheme.onSurface : theme.textTheme.bodyMedium?.color,
                            fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTimestamp(chat['last_message']?['created_at']),
                            style: TextStyle(fontSize: 12, color: isUnread ? FfigTheme.primaryBrown : theme.disabledColor, fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                          ),
                          const SizedBox(height: 8),
                          if (unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: FfigTheme.primaryBrown,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount > 9 ? "9+" : unreadCount.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
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
                        ).then((_) => _fetchCurrentUserAndConversations(silent: true)); // Refresh on return
                      },
                    ),
                  );
                },
              ),
           ),
        ],
        ),
      ),
    );
  }

  // --- NEW SEARCH UI ---
  /// Builds the search results list.
  /// - Displays matching Users and Messages separately.
  /// - Handles empty/loading states.
  Widget _buildSearchResults() {
      final users = _searchResults['users'] as List;
      final messages = _searchResults['messages'] as List;
      final theme = Theme.of(context);

      return ListView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
          children: [
              if (users.isNotEmpty) ...[
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text("USERS", style: theme.textTheme.labelLarge?.copyWith(fontSize: 16, color: theme.hintColor)),
                  ),
                  ...users.where((u) => u['username'] != _myUsername).map((u) => Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    color: theme.cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                        leading: UserAvatar(radius: 20, username: u['username'], imageUrl: u['photo_url']),
                        title: Text(u['username'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.chat_bubble_outline, color: FfigTheme.primaryBrown),
                        onTap: () {
                             Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                                 recipientId: u['id'],
                                 recipientName: u['username'],
                             )));
                        },
                    ),
                  )),
                  const Divider(height: 32),
              ],
              
              if (messages.isNotEmpty) ...[
                   Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text("MESSAGES", style: theme.textTheme.labelLarge?.copyWith(fontSize: 16, color: theme.hintColor)),
                  ),
                  ...messages.map((m) {
                       final isMe = m['is_me'] == true;
                       final senderName = m['sender']['username'];
                       return Card(
                         elevation: 0,
                         margin: const EdgeInsets.only(bottom: 8),
                         color: theme.cardColor,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         child: ListTile(
                            leading: UserAvatar(radius: 20, username: senderName), // Show Sender pic
                            title: Text(m['chat_title'] ?? "Chat", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: RichText(
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                    style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                                    children: [
                                        TextSpan(text: "$senderName: ", style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor)),
                                        TextSpan(text: m['text']),
                                    ]
                                ),
                            ),
                            onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                                     conversationId: m['conversation_id'],
                                     recipientName: m['chat_title'] ?? "Chat",
                                )));
                            },
                         ),
                       );
                  }),
              ],
              
              if (users.isEmpty && messages.isEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(child: Text("No results found.", style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16, color: theme.hintColor))),
                  )
          ],
      );
  }

  Map<String, dynamic> _searchResults = {'users': [], 'messages': []};

  /// Executes the search query against the backend.
  /// - `query`: The search text.
  /// - Updates `_searchResults` with 'users' and 'messages'.
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
  Widget _buildFilterChip(String label, String value) {
      final isSelected = _selectedFilter == value;
      final theme = Theme.of(context);

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? FfigTheme.primaryBrown : theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? FfigTheme.primaryBrown : theme.dividerColor,
            ),
             boxShadow: isSelected 
             ? [BoxShadow(color: FfigTheme.primaryBrown.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
             : null
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12
            ),
          ),
        ),
      );
  }
  Widget _buildCommunityChatTile() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        decoration: BoxDecoration(
          // Distinct background to make it stand out slightly
          color: FfigTheme.primaryBrown.withOpacity(0.1), 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FfigTheme.primaryBrown.withOpacity(0.3)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: FfigTheme.primaryBrown,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.groups, color: Colors.white, size: 28),
          ),
          title: Text(
            "Community Chat",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: FfigTheme.primaryBrown,
            ),
          ),
          subtitle: Text(
            "Connect with all members",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                if (_communityUnreadCount > 0)
                   Container(
                       margin: const EdgeInsets.only(right: 8),
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: const BoxDecoration(
                           color: Colors.red,
                           shape: BoxShape.circle,
                       ),
                       child: Text(
                           _communityUnreadCount > 9 ? "9+" : _communityUnreadCount.toString(),
                           style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                       ),
                   ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: FfigTheme.primaryBrown),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CommunityChatScreen()),
            ).then((_) {
                 // Mark as read immediately on return (or on enter, but return refreshes count safely)
                 _apiService.markCommunityChatRead();
                 setState(() => _communityUnreadCount = 0);
            });
          },
        ),
      ),
    );
  }
}
