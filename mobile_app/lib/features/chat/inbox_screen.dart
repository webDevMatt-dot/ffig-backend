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
      String url = '${baseUrl}chat/conversations/?filter=$_selectedFilter';
      if (search != null && search.isNotEmpty) {
          url += '&search=$search';
      }

      final response = await http.get(
        Uri.parse(url), 
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
    return Scaffold(
      appBar: AppBar(title: const Text("MESSAGES")),
      body: Column(
        children: [
           // Search Bar
           Padding(
             padding: const EdgeInsets.all(12.0),
             child: TextField(
               controller: _searchController,
               decoration: InputDecoration(
                   hintText: "Search messages...",
                   prefixIcon: const Icon(Icons.search, color: Colors.grey),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                   filled: true,
                   fillColor: Colors.grey[200],
                   contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0)
               ),
               onChanged: (val) {
                   if (_debounce?.isActive ?? false) _debounce!.cancel();
                   _debounce = Timer(const Duration(milliseconds: 500), () {
                       _fetchCurrentUserAndConversations(search: val);
                   });
               },
             ),
           ),
           // Filter Chips
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
           Expanded(
             child: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _conversations.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text("No messages found.", style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: _conversations.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
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

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                          bio: targetUser['bio'], // Backend might need to send this in ConversationSerializer if missing
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
                          radius: 24, 
                          username: title,
                        ),
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
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTimestamp(chat['last_message']?['created_at']),
                          style: TextStyle(fontSize: 12, color: unreadCount > 0 ? FfigTheme.primaryBrown : Colors.grey[600], fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal),
                        ),
                        const SizedBox(height: 6),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: FfigTheme.primaryBrown,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                  );
                },
              ),
           ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
      final isSelected = _selectedFilter == value;
      return FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
            setState(() {
                _selectedFilter = value;
                _isLoading = true;
            });
            _fetchCurrentUserAndConversations();
        },
        backgroundColor: Colors.grey[200],
        selectedColor: FfigTheme.primaryBrown.withOpacity(0.2),
        labelStyle: TextStyle(
            color: isSelected ? FfigTheme.primaryBrown : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
        ),
        showCheckmark: false,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isSelected ? const BorderSide(color: FfigTheme.primaryBrown) : BorderSide.none
        ),
      );
  }
}
