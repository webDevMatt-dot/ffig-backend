import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/constants.dart';
import '../create_story_screen.dart';
import 'story_bubbles.dart';
import 'story_viewer.dart';
import '../logic/story_logic.dart';

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
           // Sort
           final sorted = StoryLogic.sortStories(rawStories, null); // Pass current user ID if available
           
           // Filter for unique users for the Bar display
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
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 6,
          itemBuilder: (_, __) => const ShimmerStoryBubble(),
        ),
      );
    }

    return Container(
      height: 115,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _uniqueUserStories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return StoryBubble(
              name: 'Your Story',
              isAdd: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
                );
              },
            );
          }

          final story = _uniqueUserStories[index - 1];
          final storyId = story['id'];
          final isSeen = storyId != null && _seenStoryIds.contains(storyId);

          return StoryBubble(
            name: story['username'] ?? 'User',
            imageUrl: story['user_photo'],
            isSeen: isSeen,
            onTap: () => _openStoryViewer(story),
          );
        },
      ),
    );
  }

  void _openStoryViewer(dynamic startingStory) {
    // Find index in ALL stories to start playing from there
    // This allows "Play all" behavior while selecting a specific user's starting point
    final index = _allStories.indexOf(startingStory);
    if (index == -1) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Story',
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) {
        return StoryViewer(
          stories: _allStories,
          initialIndex: index,
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
