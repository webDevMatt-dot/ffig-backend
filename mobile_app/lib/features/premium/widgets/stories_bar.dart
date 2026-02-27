import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
               if (photo.contains('localhost')) {
                  try {
                    final uri = Uri.parse(photo);
                    group['user_photo'] = '$domain${uri.path}';
                  } catch (_) {}
               } else if (photo.startsWith('/')) {
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
                     if (url.contains('localhost')) {
                        try {
                          final uri = Uri.parse(url);
                          s['media_url'] = '$domain${uri.path}';
                        } catch (_) {}
                     } else if (url.startsWith('/')) {
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
            _precacheInitialStories();
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          clipBehavior: Clip.hardEdge,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: 110,
              color: const Color(0xFF161B22).withOpacity(0.7),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                itemBuilder: (_, __) => const ShimmerStoryBubble(),
              ),
            ),
          ),
        ),
      );
    }


    if (_uniqueUserStories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),

      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 110,
            color: const Color(0xFF161B22).withOpacity(0.7), // Premium Obsidian Glass
            child: ListView.builder(

              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _uniqueUserStories.length,
              itemBuilder: (context, index) {
                final group = _uniqueUserStories[index];
                final bool hasUnseen = group['has_unseen'] ?? false;
                final isSeen = !hasUnseen; 

                return StoryBubble(
                  name: group['username'] ?? 'User',
                  imageUrl: group['user_photo'], 
                  isSeen: isSeen,
                  onTap: () => _openStoryViewer(group),
                );
              },
            ),
          ),
        ),
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
             // Locally update the seen status for instant UI feedback
             if (mounted) {
               setState(() {
                 for (var group in _uniqueUserStories) {
                   final stories = group['stories'] as List?;
                   if (stories != null) {
                     // Check if this user's group contains the viewed story
                     bool containsStory = stories.any((s) => s['id'] == id);
                     if (containsStory) {
                       // Mark this specific user's group as "fully seen" 
                       // (Strictly speaking, we should check if ALL stories are seen, 
                       // but for simple grouping, marking the indicator as seen is standard)
                       group['has_unseen'] = false;
                     }
                   }
                 }
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

  /// Proactively downloads the first few story images so they appear instantly.
  void _precacheInitialStories() {
    if (_uniqueUserStories.isEmpty) return;
    
    // Precache first 3 users' first stories
    int catchCount = 0;
    for (var group in _uniqueUserStories) {
      if (catchCount >= 3) break;
      
      final stories = group['stories'] as List?;
      if (stories != null && stories.isNotEmpty) {
        final firstStory = stories.first;
        final String? mediaUrl = firstStory['media_url']?.toString();
        
        if (mediaUrl != null) {
          final urlLower = mediaUrl.toLowerCase();
          final bool isImage = !urlLower.endsWith('.mp4') && 
                               !urlLower.endsWith('.mov') && 
                               !urlLower.endsWith('.m4v') && 
                               !urlLower.endsWith('.3gp');
          
          if (isImage) {
            precacheImage(CachedNetworkImageProvider(mediaUrl), context);
            catchCount++;
          }
        }
      }
    }
  }
}

