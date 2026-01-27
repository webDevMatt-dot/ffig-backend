import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/admin_api_service.dart';
import '../../../core/theme/ffig_theme.dart';
import '../../../core/api/constants.dart';
import '../share_to_chat_sheet.dart';
import '../../../shared_widgets/user_avatar.dart';

class VVIPFeed extends StatefulWidget {
  const VVIPFeed({super.key});

  @override
  State<VVIPFeed> createState() => _VVIPFeedState();
}

class _VVIPFeedState extends State<VVIPFeed> {
  final _api = AdminApiService();
  final PageController _pageController = PageController();
  List<dynamic> _reels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  Future<void> _loadReels() async {
    try {
      final data = await _api.fetchMarketingFeed();
      if (mounted) {
        setState(() {
          _reels = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error loading reels: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: FfigTheme.primaryBrown));
    }

    if (_reels.isEmpty) {
        return const Center(child: Text("No VVIP content yet.", style: TextStyle(color: Colors.white)));
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      itemCount: _reels.length + 1,
      itemBuilder: (context, index) {
        if (index == _reels.length) {
            return const _CaughtUpPage();
        }
        return _ReelItem(item: _reels[index], key: ValueKey(_reels[index]['id']));
      },
    );
  }
}

class _CaughtUpPage extends StatelessWidget {
    const _CaughtUpPage();
    
    @override
    Widget build(BuildContext context) {
        return Container(
            color: Colors.black,
            child: const Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
                        SizedBox(height: 24),
                        Text(
                            "You're all caught up!",
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                            "Check back later for more.",
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                    ],
                ),
            ),
        );
    }
}


class _ReelItem extends StatefulWidget {
  final Map<String, dynamic> item;
  const _ReelItem({super.key, required this.item});

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> with SingleTickerProviderStateMixin {
  final _api = AdminApiService();
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInit = false;
  
  // Social State
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  
  // Double-tap like animation
  late AnimationController _heartAnimationController;
  bool _showHeartAnimation = false;

  @override
  void initState() {
    super.initState();
    _initMedia();
    _initSocial();
    _heartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }
  
  void _initSocial() {
      _isLiked = widget.item['is_liked'] ?? false;
      _likesCount = widget.item['likes_count'] ?? 0;
      _commentsCount = widget.item['comments_count'] ?? 0;
  }

  Future<void> _initMedia() async {
    var videoUrl = widget.item['video'];
    if (videoUrl != null && videoUrl.toString().isNotEmpty) {
      String urlString = videoUrl.toString();
      // Fix relative URLs
      if (urlString.startsWith('/')) {
         final domain = baseUrl.replaceAll('/api/', '');
         videoUrl = '$domain$urlString';
      } 
      // Fix mixed content (Production app getting localhost URL)
      else if (baseUrl.contains('onrender')) {
           final domain = baseUrl.replaceAll('/api/', '');
           if (urlString.contains('localhost')) {
              videoUrl = urlString.replaceAll(RegExp(r'http://localhost:\d+'), domain);
           } else if (urlString.contains('127.0.0.1')) {
              videoUrl = urlString.replaceAll(RegExp(r'http://127.0.0.1:\d+'), domain);
           }
      }

      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      try {
        await _videoController!.initialize();
        _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: true,
            looping: true,
            aspectRatio: _videoController!.value.aspectRatio,
            showControls: false, // Clean look like Reels/TikTok
        );
         if (mounted) setState(() => _isInit = true);
      } catch (e) {
         debugPrint("Video Init Error: $e");
         _videoController = null; // Fallback to image
         if (mounted) setState(() => _isInit = true);
      }
    } else {
        if (mounted) setState(() => _isInit = true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _heartAnimationController.dispose();
    super.dispose();
  }
  
  Future<void> _toggleLike() async {
      final prevLiked = _isLiked;
      setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
      });
      
      try {
          final res = await _api.toggleMarketingLike(widget.item['id']);
          if (mounted) {
            setState(() {
               _isLiked = res['status'] == 'liked';
               _likesCount = res['count'];
          });
          }
      } catch (e) {
          // Revert
          if (mounted) {
            setState(() {
               _isLiked = prevLiked;
               _likesCount += _isLiked ? 1 : -1;
          });
          }
      }
  }
  
  void _onDoubleTap() {
    // Only trigger like if not already liked
    if (!_isLiked) {
      _toggleLike();
    }
    
    // Show heart animation
    setState(() => _showHeartAnimation = true);
    _heartAnimationController.forward().then((_) {
      if (mounted) {
        setState(() => _showHeartAnimation = false);
        _heartAnimationController.reset();
      }
    });
  }
  
  void _showComments() {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _CommentsSheet(requestId: widget.item['id'])
      ).then((_) {
          // Refresh comments count if needed, or rely on future builder inside sheet?
          // For now, simple.
      });
  }
  
  void _share() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      final textColor = isDark ? Colors.white : Colors.black;

      showModalBottomSheet(
          context: context, 
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
              decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
              ),
              child: SafeArea(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Container(margin: const EdgeInsets.only(top: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                          ListTile(
                              leading: Icon(Icons.share, color: textColor),
                              title: Text("Share Externally", style: TextStyle(color: textColor)),
                              onTap: () {
                                  Navigator.pop(context);
                                  final text = "Check out this ${widget.item['type']} on FFig: ${widget.item['title']}\n${widget.item['link'] ?? ''}";
                                  Share.share(text);
                              },
                          ),
                          ListTile(
                              leading: Icon(Icons.send, color: textColor),
                              title: Text("Send in App", style: TextStyle(color: textColor)),
                              onTap: () {
                                  Navigator.pop(context);
                                  showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (c) => ShareToChatSheet(item: widget.item)
                                  );
                              },
                          ),
                      ],
                  ),
              ),
          )
      );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
        return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    var imageUrl = widget.item['image'];
    if (imageUrl != null) {
        String urlString = imageUrl.toString();
        if (urlString.startsWith('/')) {
            final domain = baseUrl.replaceAll('/api/', '');
            imageUrl = '$domain$urlString';
        } else if (baseUrl.contains('onrender')) {
           // Fix mixed content
           final domain = baseUrl.replaceAll('/api/', '');
           if (urlString.contains('localhost')) {
              imageUrl = urlString.replaceAll(RegExp(r'http://localhost:\d+'), domain);
           } else if (urlString.contains('127.0.0.1')) {
              imageUrl = urlString.replaceAll(RegExp(r'http://127.0.0.1:\d+'), domain);
           }
        }
    }

    final bool hasVideo = _chewieController != null;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Content Layer
        // Content Layer (Wrapped in IgnorePointer to prevent stealing taps)
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasVideo)
                Chewie(controller: _chewieController!)
              else if (imageUrl != null)
                Image.network(imageUrl, fit: BoxFit.contain)
              else
                Container(color: Colors.grey[900], child: const Center(child: Icon(Icons.broken_image, color: Colors.white))),
            ],
          ),
        ),

        // Touch Detection Layer (Overlay)
        GestureDetector(
          onDoubleTap: _onDoubleTap,
          onTap: () {
             if (_videoController != null && _videoController!.value.isInitialized) {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                     _videoController!.pause();
                  } else {
                     _videoController!.play();
                  }
                });
             }
          },
          behavior: HitTestBehavior.opaque, // Force capture
          child: Container(
            color: Colors.black.withOpacity(0.001), // Almost transparent but force hit test
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // Floating Heart Animation
        if (_showHeartAnimation)
          Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.3, end: 1.2).animate(
                CurvedAnimation(parent: _heartAnimationController, curve: Curves.easeOut),
              ),
              child: FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                  CurvedAnimation(parent: _heartAnimationController, curve: Curves.easeOut),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 100,
                ),
              ),
            ),
          ),
          
        // Overlay Gradient
        Container(
           decoration: const BoxDecoration(
             gradient: LinearGradient(
               begin: Alignment.topCenter,
               end: Alignment.bottomCenter,
               colors: [Colors.transparent, Colors.black87],
               stops: [0.6, 1.0],
             ),
           ),
        ),

        // Side Action Bar (Right)
        Positioned(
            right: 16,
            bottom: 140, // Increased from 100 to avoid GlassNavBar
            child: Column(
                children: [
                    _ActionButton(
                        icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : Colors.white,
                        label: "$_likesCount",
                        onTap: _toggleLike
                    ),
                    const SizedBox(height: 20),
                    _ActionButton(
                        icon: Icons.comment, 
                        label: "$_commentsCount",
                        onTap: _showComments
                    ),
                    const SizedBox(height: 20),
                    _ActionButton(
                        icon: Icons.share, 
                        label: "Share",
                        onTap: _share
                    ),
                ],
            ),
        ),

        // Info Layer
        Positioned(
            bottom: 110, // Increased from 40 to avoid GlassNavBar
            left: 16,
            right: 80, // Space for buttons
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: FfigTheme.primaryBrown, borderRadius: BorderRadius.circular(4)),
                        child: Text(widget.item['type'] ?? 'PROMOTION', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.item['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (widget.item['link'] != null && widget.item['link'].toString().isNotEmpty)
                        ElevatedButton(
                            onPressed: () => launchUrl(Uri.parse(widget.item['link'])),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white, 
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                            ),
                            child: const Text("View Offer"),
                        ),
                     const SizedBox(height: 40), // Bottom padding
                ],
            ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
    final IconData icon;
    final String label;
    final VoidCallback onTap;
    final Color color;
    
    const _ActionButton({required this.icon, required this.label, required this.onTap, this.color = Colors.white});
    
    @override
    Widget build(BuildContext context) {
        return GestureDetector(
            onTap: onTap,
            child: Column(
                children: [
                    Icon(icon, color: color, size: 30),
                    const SizedBox(height: 4),
                    Text(label, style: const TextStyle(color: Colors.white, fontSize: 12))
                ],
            ),
        );
    }
}

class _CommentsSheet extends StatefulWidget {
    final int requestId;
    const _CommentsSheet({required this.requestId});
    @override
    State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
    final _api = AdminApiService();
    final _controller = TextEditingController();
    List<dynamic> _comments = [];
    bool _loading = true;

    @override
    void initState() {
        super.initState();
        _load();
    }
    
    Future<void> _load() async {
        try {
            final data = await _api.fetchMarketingComments(widget.requestId);
            if (mounted) setState(() { _comments = data; _loading = false; });
        } catch (e) {
            debugPrint("Error loading comments: $e");
            if (mounted) setState(() => _loading = false);
        }
    }
    
    Future<void> _post() async {
        if (_controller.text.trim().isEmpty) return;
        final content = _controller.text;
        _controller.clear(); 
        try {
            await _api.postMarketingComment(widget.requestId, content);
            _load(); // reload
        } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
        }
    }

    @override
    Widget build(BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;
        final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
        final inputFill = isDark ? Colors.grey[800] : Colors.grey[100];

        return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
                children: [
                    const SizedBox(height: 10),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    Padding(padding: const EdgeInsets.all(16), child: Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor))),
                    Expanded(
                        child: _loading 
                         ? const Center(child: CircularProgressIndicator()) 
                         : _comments.isEmpty
                            ? Center(child: Text("No comments yet.", style: TextStyle(color: subTextColor)))
                            : ListView.builder(
                             itemCount: _comments.length,
                             itemBuilder: (c, i) {
                                 final com = _comments[i];
                                 var photoUrl = com['photo_url'];
                                 if (photoUrl != null) {
                                    String urlString = photoUrl.toString();
                                    if (urlString.startsWith('/')) {
                                        final domain = baseUrl.replaceAll('/api/', '');
                                        photoUrl = '$domain$urlString';
                                    } else if (baseUrl.contains('onrender')) {
                                       final domain = baseUrl.replaceAll('/api/', '');
                                       if (urlString.contains('localhost')) {
                                          photoUrl = urlString.replaceAll(RegExp(r'http://localhost:\d+'), domain);
                                       } else if (urlString.contains('127.0.0.1')) {
                                          photoUrl = urlString.replaceAll(RegExp(r'http://127.0.0.1:\d+'), domain);
                                       }
                                    }
                                 }

                                 return ListTile(
                                     leading: UserAvatar(
                                       radius: 20,
                                       imageUrl: photoUrl, // already corrected above
                                       username: com['username'],
                                     ),
                                     title: Text(com['username'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                                     subtitle: Text(com['content'], style: TextStyle(color: subTextColor)),
                                 );
                             },
                         )
                    ),
                    Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                            children: [
                                Expanded(child: TextField(
                                    controller: _controller,
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                        hintText: "Add a comment...",
                                        hintStyle: TextStyle(color: subTextColor),
                                        filled: true,
                                        fillColor: inputFill,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16)
                                    ),
                                )),
                                IconButton(icon: const Icon(Icons.send, color: FfigTheme.primaryBrown), onPressed: _post)
                            ],
                        ),
                    )
                ],
            ),
        );
    }
}
