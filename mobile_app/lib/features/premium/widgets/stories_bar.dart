import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/api/constants.dart';
import '../../../core/api/constants.dart';
import '../../../shared_widgets/user_avatar.dart';
import '../create_story_screen.dart';
import '../../../core/theme/ffig_theme.dart';

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
        itemCount: _stories.length, 
        itemBuilder: (context, index) {
          final story = _stories[index];
          final user = story['username'] ?? 'User';
          final photo = story['user_photo'];
          
          return _buildStoryItem(
            name: user,
            imageUrl: photo,
              onTap: () {
                 if (story['media_url'] != null) {
                    showDialog(
                      context: context,
                      builder: (c) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: EdgeInsets.zero,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                             // Simple Image Viewer for now
                             Image.network(story['media_url']),
                             Positioned(
                               top: 40, right: 20,
                               child: IconButton(
                                 icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                 onPressed: () => Navigator.pop(c),
                               )
                             )
                          ],
                        ),
                      )
                    );
                 }
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
            if (isAdd)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1, style: BorderStyle.none), // Dotted border hard in Flutter without package, using thin opacity for now
                ),
                child: Container(
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     border: Border.all(color: Colors.grey.shade800, width: 2),
                     color: Colors.transparent
                   ),
                   child: Center(child: Icon(Icons.add, color: FfigTheme.primaryBrown, size: 24)),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFF8B4513)], // Gold to Brown
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF0D1117), // Obsidian
                  ),
                  child: UserAvatar(
                    imageUrl: imageUrl, 
                    radius: 30,
                    username: name,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(
                  color: isAdd ? Colors.grey[500] : Colors.white, 
                  fontSize: 10, 
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
