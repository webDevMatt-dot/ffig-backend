import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/constants.dart';
import 'story_bubbles.dart';
import 'story_viewer.dart';
import '../logic/story_logic.dart';

/// A horizontal bar that displays a list of users who have posted stories.
///
/// **Key Features:**
/// - Fetches stories from the backend (`/members/stories/`).
/// - Fixes relative image URLs to ensure they display correctly.
/// - Groups multiple stories by the same user so they appear as a single bubble.
/// - Sorts stories chronologically (Oldest -> Newest) for the viewer.
/// - Handles "seen" state locally to grey out viewed stories.
class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  List<dynamic> _allStories = [];
  List<dynamic> _uniqueUserStories = [];
  bool _isLoading = true;
  final Set<int> _seenStoryIds = {};

  @override
  void initState() {
    super.initState();
    _fetchStories();
  }

  /// Fetches stories from the API and groups them.
  /// - URL correction for media and avatars.
  /// - Sorts stories (using `StoryLogic`).
  /// - Filters for unique users to display one bubble per user.
  Future<void> _fetchStories() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}members/stories/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
           final rawStories = jsonDecode(response.body) as List<dynamic>;
           
           // --- FIX 1: Robust URL Correction ---
           // Clean the domain (remove /api/ if present to get root)
           // This ensures that we have a clean base URL for prepending to relative paths.
           final domain = baseUrl.contains('/api/') 
               ? baseUrl.substring(0, baseUrl.indexOf('/api/')) 
               : baseUrl;

           for (var s in rawStories) {
             // Fix Media URL
             if (s['media_url'] != null) {
               String url = s['media_url'].toString();
               if (url.startsWith('/')) {
                 s['media_url'] = '$domain$url';
               } else if (!url.startsWith('http')) {
                  // Handle cases where it might be just a filename
                  s['media_url'] = '$domain/media/$url';
               }
             }
             
             // Fix User Photo URL (The Exclamation Mark Fix)
             if (s['user_photo'] != null) {
               String photo = s['user_photo'].toString();
               if (photo.startsWith('/')) {
                 s['user_photo'] = '$domain$photo';
               } else if (!photo.startsWith('http')) {
                  // Handle cases where it might be just a filename or relative path
                  s['user_photo'] = '$domain/media/$photo'; // Assumption: Media path
               }
             }
           }

           // Sort (This is usually Newest First for the feed)
           final sorted = StoryLogic.sortStories(rawStories, null); 
           
           // Filter for unique users for the Bar display (Bubbles)
           final unique = <dynamic>[];
           final seenUsers = <String>{};
           
           for (var s in sorted) {
             final username = s['username'] ?? 'User';
             if (!seenUsers.contains(username)) {
               seenUsers.add(username);
               unique.add(s);
             }
           }

           setState(() {
             _allStories = sorted;
             _uniqueUserStories = unique;
             _isLoading = false;
           });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 115,
        margin: const EdgeInsets.only(top: 4, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 6,
          itemBuilder: (_, __) => const ShimmerStoryBubble(),
        ),
      );
    }

    if (_uniqueUserStories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 115,
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _uniqueUserStories.length,
        itemBuilder: (context, index) {
          final story = _uniqueUserStories[index];
          final storyId = story['id'];
          final isSeen = storyId != null && _seenStoryIds.contains(storyId);

          return StoryBubble(
            name: story['username'] ?? 'User',
            imageUrl: story['user_photo'], // Now sends corrected URL
            isSeen: isSeen,
            onTap: () => _openStoryViewer(story),
          );
        },
      ),
    );
  }

  /// Opens the Story Viewer interaction.
  /// - Filters global stories to finding ALL stories by the tapped user.
  /// - Sorts them Oldest -> Newest for viewing flow.
  /// - Launches `StoryViewer` dialog.
  void _openStoryViewer(dynamic startingStory) {
    final username = startingStory['username'];

    // --- FIX 2: Filter & Sort for "Multiple Uploads" ---
    // 1. Get ONLY this user's stories from the big list
    // Uses the 'username' as the key to filter the global list.
    final userStories = _allStories.where((s) => s['username'] == username).toList();

    // 2. Sort them Chronologically (Oldest -> Newest) so they play in order
    // Assuming 'created_at' is an ISO string
    userStories.sort((a, b) {
        String dateA = a['created_at'] ?? '';
        String dateB = b['created_at'] ?? '';
        return dateA.compareTo(dateB);
    });

    if (userStories.isEmpty) return;

    // 3. Open Viewer with ONLY this user's stories
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Story',
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return StoryViewer(
          stories: userStories, // Pass specific list
          initialIndex: 0, // Start from their first (oldest) story
          onGlobalClose: () => Navigator.pop(context),
          onStoryViewed: (id) {
            if (mounted) {
              setState(() {
                _seenStoryIds.add(id);
              });
            }
          },
        );
      },
      transitionBuilder: (_, anim, __, child) {
         return FadeTransition(opacity: anim, child: child);
      },
    );
  }
}
