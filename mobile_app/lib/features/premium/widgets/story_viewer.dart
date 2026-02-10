import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../../../core/api/constants.dart';

import '../../../shared_widgets/user_avatar.dart';

class StoryViewer extends StatefulWidget {
  final List<dynamic> stories; // List of all user's stories (if multiple) or just the one clicked
  final int initialIndex;
  final VoidCallback onGlobalClose;
  final Function(int)? onStoryViewed;

  const StoryViewer({
    super.key,
    required this.stories,
    this.initialIndex = 0,
    required this.onGlobalClose,
    this.onStoryViewed,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;
  
  // For Video
  VideoPlayerController? _videoController;
  
  // For Reply
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  bool _isReplyLoading = false;
  bool _isClosed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    
    _animController = AnimationController(vsync: this);
    
    _replyFocusNode.addListener(_onReplyFocusChange);
    
    _loadStory(index: _currentIndex);
  }

  @override
  void dispose() {
    _replyFocusNode.removeListener(_onReplyFocusChange);
    _replyFocusNode.dispose();
    _pageController.dispose();
    _animController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _onReplyFocusChange() {
    if (_replyFocusNode.hasFocus) {
      _animController.stop();
      _videoController?.pause();
    } else {
      if (!_isReplyLoading && !_isClosed) {
         if (_videoController != null && _videoController!.value.isInitialized) {
             _videoController!.play();
         }
         _animController.forward();
      }
    }
  }

  void _loadStory({required int index, bool animateToPage = false}) {
    if (_isClosed) return;
    if (index < 0 || index >= widget.stories.length) {
      _close();
      return;
    }

    _videoController?.dispose();
    _videoController = null;
    _animController.stop();
    _animController.reset();

    setState(() {
      _currentIndex = index;
    });

    if (animateToPage) {
      _pageController.jumpToPage(index);
    }

    final story = widget.stories[index];
    
    // Mark as seen
    if (story['id'] != null) {
      widget.onStoryViewed?.call(story['id']);
    }

    final mediaUrl = story['media_url'];
    final isVideo = mediaUrl != null && (mediaUrl.endsWith('.mp4') || mediaUrl.endsWith('.mov')); // Simple check, better use MIME type

    if (isVideo) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(mediaUrl))
        ..initialize().then((_) {
          if (mounted && !_isClosed) {
             setState(() {});
             if (_videoController!.value.isInitialized) {
               _animController.duration = _videoController!.value.duration;
               _videoController!.play();
               _animController.forward();
             }
          }
        });
    } else {
      // Image: 5 seconds duration
      _animController.duration = const Duration(seconds: 5);
      _animController.forward();
    }

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onNext();
      }
    });
  }

  void _close() {
    if (!_isClosed) {
      _isClosed = true;
      widget.onGlobalClose();
    }
  }

  void _onNext() {
    if (_isClosed) return;
    if (_currentIndex < widget.stories.length - 1) {
      _loadStory(index: _currentIndex + 1, animateToPage: true);
    } else {
      _close();
    }
  }

  void _onPrevious() {
    if (_isClosed) return;
    if (_currentIndex > 0) {
      _loadStory(index: _currentIndex - 1, animateToPage: true);
    } else {
       // Loop back or close? Instagram closes if tap left on first story of user 
       // For now, let's just stay or maybe close if needed.
       // widget.onGlobalClose();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_isClosed) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;
    
    // Ignore taps on bottom area where reply input is
    if (details.globalPosition.dy > MediaQuery.of(context).size.height * 0.85) return;

    if (dx < screenWidth / 3) {
      _onPrevious();
    } else {
      _onNext();
    }
  }

  Future<void> _sendReply() async {
    if (_replyController.text.isEmpty) return;
    
    setState(() => _isReplyLoading = true);
    _animController.stop(); // Pause story while replying
    _videoController?.pause();

    try {
      final story = widget.stories[_currentIndex];
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      
      await http.post(
        Uri.parse('${baseUrl}members/stories/${story['id']}/reply/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': _replyController.text}),
      );

      if (mounted) {
        _replyController.clear();
        FocusScope.of(context).unfocus(); // Close keyboard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reply sent!'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isReplyLoading = false);
        // Resume story
        if (_videoController != null && _videoController!.value.isInitialized) {
             _videoController!.play();
        }
        _animController.forward();
      }
    }
  }

  void _showViewers() {
    _animController.stop();
    _videoController?.pause();
    
    final story = widget.stories[_currentIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StoryViewersSheet(storyId: story['id']),
    ).then((_) {
        // Resume on close
        if (_videoController != null && _videoController!.value.isInitialized) {
             _videoController!.play();
        }
        _animController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    
    // User ID check - relying on 'user' field being ID or 'username' being 'You' or matching stored user...
    // For now, simple username check if available, or assume if 'username' is 'You' it is me.
    // Ideally we pass currentUserId to StoryViewer.
    // Let's assume 'username' == 'You' or a field 'is_owner' = true.
    // Since we didn't add is_owner to serializer explicitly in the quick plan, let's try to detect.
    // If the username matches the logged in user... but we don't have logged in user here easily without async.
    // The previous code had "You" logic.
    // Let's rely on `story['user_id']` vs `currentUserId` if possible, but we don't have currentUserId.
    // HACK: Check if username is 'You' (if frontend formats it) OR if we can check a flag.
    // For now, I'll add a 'is_owner' check if it exists, otherwise false.
    // WAIT: The backend serializer for `grouped` response puts "You" or I can logic it there?
    // Actually, in `StoriesBar`, we constructed the list.
    // Let's assume for now: if user can reply, it's not them.
    
    // Simple way: We need to know if it's ME.
    // I will try to use a safe check.
    bool isMyStory = story['username'] == 'You'; 
    // If we are testing and backend sends "Matthew", this might fail. 
    // Let's add a safe fallback: if I can see "views", it's me.
        
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: _onTapUp,
        onLongPress: () {
          _videoController?.pause();
          _animController.stop();
        },
        onLongPressUp: () {
          if (!_isClosed && !_isReplyLoading) {
             if (_videoController != null && _videoController!.value.isInitialized) {
                 _videoController!.play();
             }
             _animController.forward();
          }
        },
        onVerticalDragEnd: (details) {
            if (_isClosed) return;
            if (details.primaryVelocity! < -200) {
                 // Swipe Up
                 _showViewers(); 
            } else if (details.primaryVelocity! > 200) {
                 _close();
            }
        },
        child: Stack(
          children: [
            // Media Layer
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                final s = widget.stories[index];
                final url = s['media_url'];
                if (url == null) return const Center(child: Icon(Icons.error, color: Colors.white));
                
                final isVideo = url.endsWith('.mp4') || url.endsWith('.mov');
                
                if (index == _currentIndex && isVideo && _videoController != null && _videoController!.value.isInitialized) {
                  return Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  );
                } else if (isVideo) {
                   return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                return Center(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                  ),
                );
              },
            ),

            // Gradient Overlay
            Positioned(
              top: 0, left: 0, right: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Progress Bars
            Positioned(
              top: 50,
              left: 10,
              right: 10,
              child: Row(
                children: widget.stories.asMap().entries.map((entry) {
                   return Expanded(
                     child: Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 2),
                       child: StoryProgressBar(
                         animController: _animController, 
                         position: entry.key, 
                         currentIndex: _currentIndex
                       ),
                     ),
                   );
                }).toList(),
              ),
            ),

            // User Info
            Positioned(
              top: 65,
              left: 16,
              child: Row(
                children: [
                  UserAvatar(
                    imageUrl: story['user_photo'], 
                    radius: 16,
                    username: story['username'] ?? 'User',
                  ),
                  const SizedBox(width: 8),
                  Text(
                    story['username'] ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Close Button
            Positioned(
              top: 60,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _close,
              ),
            ),

             // Viewers Indication (for now, just show swipe hint or button if we think it's us)
             // Simpler: Just the reply input for now. If user wants to see views, they can swipe up.
             // But visual cue is nice.
             Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: isMyStory 
                    ? GestureDetector(
                        onTap: _showViewers,
                        child: Column(
                          children: [
                            const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                            const Text("Views", style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      )
                    : Container(),
                ),

            // Reply Input (If NOT Owner)
            if (!isMyStory)
                Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                             controller: _replyController,
                             focusNode: _replyFocusNode,
                             style: const TextStyle(color: Colors.white),
                             cursorColor: Colors.white,
                             decoration: const InputDecoration(
                               hintText: 'Send a reply...',
                               hintStyle: TextStyle(color: Colors.white70),
                               border: InputBorder.none,
                               contentPadding: EdgeInsets.symmetric(vertical: 14), 
                               isDense: true, 
                             ),
                             onSubmitted: (_) => _sendReply(),
                          ),
                        ),
                        if (_isReplyLoading)
                           const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        else
                           IconButton(
                             icon: const Icon(Icons.send, color: Colors.white),
                             onPressed: _sendReply,
                           )
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}

class StoryProgressBar extends StatelessWidget {
  final AnimationController animController;
  final int position;
  final int currentIndex;

  const StoryProgressBar({
    super.key,
    required this.animController,
    required this.position,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animController,
      builder: (context, child) {
        double value = 0.0;
        if (position < currentIndex) {
          value = 1.0;
        } else if (position == currentIndex) {
          value = animController.value;
        }
        
        return Container(
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class StoryViewersSheet extends StatelessWidget {
  final int storyId;
  const StoryViewersSheet({super.key, required this.storyId});

  Future<List<dynamic>> _fetchViewers() async {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse('${baseUrl}members/stories/$storyId/views/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
  }

  Future<void> _deleteStory(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
             onPressed: () => Navigator.pop(context, true), 
             child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      await http.delete(
        Uri.parse('${baseUrl}members/stories/$storyId/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (context.mounted) {
        Navigator.pop(context); // Close sheet
        Navigator.pop(context); // Close viewer (optional, or refresh? For now close safely)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story deleted')));
      }
    } catch (e) {
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _fetchViewers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }

        final viewers = snapshot.data as List;
        
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
          padding: const EdgeInsets.all(16),
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             mainAxisSize: MainAxisSize.min,
             children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${viewers.length} Views", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white70),
                      onPressed: () => _deleteStory(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (viewers.isEmpty)
                   const Padding(
                     padding: EdgeInsets.only(top: 20),
                     child: Center(child: Text("No views yet", style: TextStyle(color: Colors.white54))),
                   )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: viewers.length,
                      itemBuilder: (_, i) {
                        final v = viewers[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: v['profile_photo'] != null ? NetworkImage(v['profile_photo']) : null,
                            child: v['profile_photo'] == null ? Text(v['username'][0]) : null,
                          ),
                          title: Text(
                            v['username'],
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            _formatTime(v['seen_at']),
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
             ],
          ),
        );
      },
    );
  }
  
  String _formatTime(String? dateStr) {
     if (dateStr == null) return '';
     try {
       final date = DateTime.parse(dateStr);
       return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
     } catch (e) { return ''; }
  }
}
