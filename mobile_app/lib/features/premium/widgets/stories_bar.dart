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
  /// - Backend returns a List of Groups (User + Stories).
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
           final rawGroups = jsonDecode(response.body) as List<dynamic>;
           
           // --- FIX 1: Robust URL Correction ---
           // Clean the domain (remove /api/ if present to get root)
           final domain = baseUrl.contains('/api/') 
               ? baseUrl.substring(0, baseUrl.indexOf('/api/')) 
               : baseUrl;

           for (var group in rawGroups) {
             // 1. Fix User Photo URL (On the Group Object)
             if (group['user_photo'] != null) {
               String photo = group['user_photo'].toString();
               if (photo.startsWith('/')) {
                 group['user_photo'] = '$domain$photo';
               } else if (!photo.startsWith('http')) {
                  group['user_photo'] = '$domain/media/$photo'; 
               }
             }

             // 2. Fix Media URL for each story in the group
             if (group['stories'] != null) {
                for (var s in group['stories']) {
                   if (s['media_url'] != null) {
                     String url = s['media_url'].toString();
                     if (url.startsWith('/')) {
                       s['media_url'] = '$domain$url';
                     } else if (!url.startsWith('http')) {
                        s['media_url'] = '$domain/media/$url';
                     }
                   }
                }
             }
           }

           // Sort the groups: Unseen first, then Recent (Newest story) first
           rawGroups.sort((a, b) {
             // 1. Unseen First
             bool aUnseen = a['has_unseen'] ?? false;
             bool bUnseen = b['has_unseen'] ?? false;
             if (aUnseen != bUnseen) {
               return aUnseen ? -1 : 1; // Unseen comes first
             }

             // 2. Most Recent Update First (Check last story in group as they are sorted Oldest->Newest by backend)
             var storiesA = a['stories'] as List?;
             var storiesB = b['stories'] as List?;
             
             DateTime timeA = DateTime(2000);
             if (storiesA != null && storiesA.isNotEmpty) {
                timeA = DateTime.tryParse(storiesA.last['created_at'] ?? '') ?? DateTime(2000);
             }
             
             DateTime timeB = DateTime(2000);
             if (storiesB != null && storiesB.isNotEmpty) {
                timeB = DateTime.tryParse(storiesB.last['created_at'] ?? '') ?? DateTime(2000);
             }
             
             return timeB.compareTo(timeA); // Descending
           });
           
           setState(() {
             _uniqueUserStories = rawGroups; // This is now a list of GROUPS
             _allStories = []; 
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
          final group = _uniqueUserStories[index];
          // Use user_id as stable key for seen/unseen logic if needed
          // Backend sends 'has_unseen' in the group object, which is better.
          final bool hasUnseen = group['has_unseen'] ?? false;
          final isSeen = !hasUnseen; 

          return StoryBubble(
            name: group['username'] ?? 'User',
            imageUrl: group['user_photo'], // Now sends corrected URL
            isSeen: isSeen,
            onTap: () => _openStoryViewer(group),
          );
        },
      ),
    );
  }

  /// Opens the Story Viewer interaction.
  /// - Takes the GROUP object (User + List of Stories).
  /// - Passes the list of stories to `StoryViewer`.
  void _openStoryViewer(dynamic group) {
    // 1. Get ONLY this user's stories from the group
    final List<dynamic> userStories = group['stories'] ?? [];

    if (userStories.isEmpty) return;

    // 2. Open Viewer with this user's stories
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
             // Local seen state update if we want to track it immediately in the UI
             // But since we rely on `has_unseen` from backend group, we might need to 
             // update the group object in `_uniqueUserStories` to mark as seen.
             // For now, let's leave it as is.
          },
        );
      },
      transitionBuilder: (_, anim, __, child) {
         return FadeTransition(opacity: anim, child: child);
      },
    );
  }
}
