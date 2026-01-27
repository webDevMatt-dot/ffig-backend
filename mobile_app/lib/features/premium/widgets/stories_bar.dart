import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/constants.dart';
import '../../../core/api/constants.dart';
import '../../../shared_widgets/user_avatar.dart';
import '../create_story_screen.dart';

class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  List<dynamic> _stories = [];
  bool _isLoading = true;

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
           setState(() {
             _stories = jsonDecode(response.body);
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
    if (_isLoading) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
    
    // Include specific internal/static stories if needed, or just DB stories
    // User requested: "Your Story", "Sarah", "Elena" etc.
    // For now, assume DB returns actual stories. We can inject a "Your Story" button.
    
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _stories.length + 1, // +1 for "Your Story"
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildStoryItem(
              name: "Your Story",
              isAdd: true,
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (c) => const CreateStoryScreen()));
              },
            );
          }
          
          final story = _stories[index - 1];
          final user = story['username'] ?? 'User';
          final photo = story['user_photo'];
          
          return _buildStoryItem(
            name: user,
            imageUrl: photo,
            onTap: () {
               // Show story
            }
          );
        },
      ),
    );
  }

  Widget _buildStoryItem({required String name, String? imageUrl, bool isAdd = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAdd ? Colors.grey : Colors.cyan.shade400,
                  width: 2,
                ),
              ),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[800],
                  border: Border.all(color: Colors.black, width: 2),
                ),
                clipBehavior: Clip.hardEdge,
                child: isAdd 
                    ? const Icon(Icons.add, color: Colors.white, size: 30)
                    : UserAvatar(
                        imageUrl: imageUrl, 
                        radius: 30,
                        username: name,
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
