import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/admin_api_service.dart';
import '../../../core/theme/ffig_theme.dart';
import '../../../core/api/constants.dart';
import '../share_to_chat_sheet.dart';
import 'stories_bar.dart'; // Import local widget
import '../../../shared_widgets/user_avatar.dart';
import 'full_screen_media_viewer.dart';

/// The main feed for VVIP content, styled like TikTok/Reels.
///
/// **Features:**
/// - Vertical scrolling PageView.
/// - Autoplays videos using `Chewie` and `VideoPlayer`.
/// - Integrated Social features: Like, Comment, Share.
/// - Auto-hiding Stories Bar on scroll.
/// - "Caught Up" page at the end of the feed.
class VVIPFeed extends StatefulWidget {
  final PageController? controller;
  const VVIPFeed({super.key, this.controller});

  @override
  State<VVIPFeed> createState() => _VVIPFeedState();
}

class _VVIPFeedState extends State<VVIPFeed> {
  final _api = AdminApiService();
  late PageController _pageController;
  List<dynamic> _reels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = widget.controller ?? PageController();
    _loadReels();
  }

  /// Fetches the marketing feed (Reels) from the backend.
  /// - Uses `AdminApiService.fetchMarketingFeed`.
  /// - Updates UI state variables.
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

    return Stack(
      children: [
        PageView.builder(
          scrollDirection: Axis.vertical,
          controller: _pageController,
          itemCount: _reels.length + 1,
          itemBuilder: (context, index) {
            if (index == _reels.length) {
                return _CaughtUpPage(onRefresh: () {
                  _loadReels();
                  _pageController.animateToPage(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                });
            }
            return _ReelItem(item: _reels[index], index: index, key: ValueKey(_reels[index]['id']));
          },
        ),
        
        // Stories Bar (Scrolls away)
        // Uses AnimatedBuilder to listen to the main page controller.
        // As the user scrolls down to the first reel, the stories bar fades out and moves up.
        Positioned(
            // CHANGED: Moved up to 70 to condense space
            top: 70, 
            left: 0, 
            right: 0,
            child: AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                    double offset = 0;
                    try {
                        if (_pageController.hasClients && _pageController.position.haveDimensions) {
                             offset = _pageController.page ?? 0;
                        }
                    } catch (e) {
                        // ignore
                    }
                    
                    // Hide after 1 page scroll
                    if (offset > 1) return const SizedBox.shrink();

                    return Transform.translate(
                        offset: Offset(0, -offset * 300), // Move up faster than scroll
                        child: Opacity(
                            opacity: (1 - offset).clamp(0.0, 1.0), // Fade out
                            child: child
                        ),
                    );
                },
                child: const StoriesBar(),
            )
        )
      ],
    );
  }


  @override
  void dispose() {
    if (widget.controller == null) {
      _pageController.dispose();
    }
    super.dispose();
  }
}

class _CaughtUpPage extends StatelessWidget {
    final VoidCallback onRefresh;
    const _CaughtUpPage({required this.onRefresh});
    
    @override
    Widget build(BuildContext context) {
        return GestureDetector(
            onVerticalDragEnd: (details) {
                if (details.primaryVelocity! < 0) { // Swipe Up
                    onRefresh();
                }
            },
            child: Container(
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
                                "Swipe up to refresh",
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                            ), 
                             SizedBox(height: 48),
                             Icon(Icons.keyboard_double_arrow_up, color: Colors.white54, size: 40)
                        ],
                    ),
                ),
            ),
        );
    }
}


/// Individual Reel Item Widget.
///
/// Handles video initialization, playback control, double-tap to like, and social overlay.
class _ReelItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final int index;
  const _ReelItem({super.key, required this.item, required this.index});

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

  /// Initializes the media player (Video or Image).
  /// - Handles URL correction (relative paths, localhost for Android emulator).
  /// - Initializes `VideoPlayerController` and `ChewieController` for videos.
  /// - Sets auto-play and looping for immersive experience.
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
         if (mounted) {
           setState(() => _isInit = true);
           HapticFeedback.lightImpact(); // Haptic on new video load
         }
      } catch (e) {
         debugPrint("Video Init Error: $e");
         _videoController = null; // Fallback to image
         if (mounted) {
           setState(() => _isInit = true);
           HapticFeedback.lightImpact();
         }
      }
    } else {
        if (mounted) {
          setState(() => _isInit = true);
          HapticFeedback.lightImpact();
        }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _heartAnimationController.dispose();
    super.dispose();
  }
  
  /// Toggles the 'Like' status of the reel.
  /// - Optimistically updates UI.
  /// - Sends request to backend via `AdminApiService`.
  /// - Reverts on failure.
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
            if (_isLiked) HapticFeedback.mediumImpact();
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
  
  /// Handles double-tap interaction.
  /// - Triggers 'Like' if not already liked.
  /// - Shows a floating heart animation overlay.
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
  
  /// Opens the Comments Sheet.
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
  
  /// Opens the Share Sheet.
  /// - Options: External Share (system) or In-App Share (Chat).
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
        return const Center(child: CircularProgressIndicator(color: FfigTheme.primaryBrown));
    }

    var imageUrl = widget.item['image'];
    if (imageUrl != null) {
        String urlString = imageUrl.toString();
        if (urlString.startsWith('/')) {
            final domain = baseUrl.replaceAll('/api/', '');
            imageUrl = '$domain$urlString';
        } else if (baseUrl.contains('onrender')) {
           final domain = baseUrl.replaceAll('/api/', '');
           if (urlString.contains('localhost')) {
              imageUrl = urlString.replaceAll(RegExp(r'http://localhost:\d+'), domain);
           } else if (urlString.contains('127.0.0.1')) {
              imageUrl = urlString.replaceAll(RegExp(r'http://127.0.0.1:\d+'), domain);
           }
        }
    }

    final bool hasVideo = _chewieController != null;
    
    // CHANGED: Reduced top padding to clear the StoriesBar
    // The first item needs more padding to push it below the fixed StoriesBar and Header.
    // Subsequent items are full screen.
    return Padding( 
      // CHANGED: Reduced top padding to 180 (Header + Stories Bar space)
      padding: EdgeInsets.only(bottom: 24, left: 0, right: 0, top: widget.index == 0 ? 180 : 0), 
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22), // Obsidian lighter
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 0, offset: const Offset(0, -5))
          ]
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media Layer
            Positioned.fill(
                child: IgnorePointer(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: hasVideo
                          ? Chewie(key: ValueKey('video_${widget.item['id']}'), controller: _chewieController!)
                          : (imageUrl != null
                              ? Image.network(imageUrl, key: ValueKey('image_${widget.item['id']}'), fit: BoxFit.contain)
                              : Container(key: const ValueKey('broken_image'), color: Colors.grey[900], child: const Center(child: Icon(Icons.broken_image, color: Colors.white)))),
                    )
                )
            ),

            // Touch Layer
            GestureDetector(
              onDoubleTap: _onDoubleTap,
              onTap: () {
                 // Navigate to Full Screen
                 Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenMediaViewer(
                     url: hasVideo ? widget.item['video'] : imageUrl, 
                     isVideo: hasVideo
                 )));
              },
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
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
                    child: AnimatedScale(
                      scale: _showHeartAnimation ? 1.4 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(Icons.favorite, color: Colors.redAccent, size: 100), // Premium red heart
                    ),
                  ),
                ),
              ),
            Positioned(
                top: 24,
                left: 24,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.1))
                        ),
                        child: Row(
                            children: [
                                Container(width: 8, height: 8, decoration: const BoxDecoration(color: FfigTheme.primaryBrown, shape: BoxShape.circle)), // Gold dot
                                const SizedBox(width: 8),
                                Text((widget.item['type'] ?? 'EXCLUSIVE').toUpperCase(),
                                 style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)
                                ),
                            ],
                        ),
                    ),
                  ),
                ),
            ),

            // Bottom Gradient & Info
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 90),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.85), Colors.transparent], 
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  )
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        widget.item['title'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2),
                    ),
                    const SizedBox(height: 12),
                    Row(
                        children: [
                             ClipRRect(
                               borderRadius: BorderRadius.circular(12),
                               child: BackdropFilter(
                                 filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                   decoration: BoxDecoration(
                                     color: Colors.black.withOpacity(0.35),
                                     borderRadius: BorderRadius.circular(12),
                                   ),
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       Text((widget.item['username'] ?? 'VVIP Member').toUpperCase(), style: const TextStyle(color: FfigTheme.primaryBrown, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                                       const SizedBox(width: 6),
                                       const Icon(Icons.verified, color: Color(0xFFD4AF37), size: 14), // VVIP Gold Check
                                     ]
                                   ),
                                 ),
                               ),
                             ),
                             Container(margin: const EdgeInsets.symmetric(horizontal: 12), width: 4, height: 4, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                             Text(() {
                                 final dateStr = widget.item['created_at'];
                                 if (dateStr == null) return "";
                                 try {
                                     final d = DateTime.parse(dateStr);
                                     return "${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}";
                                 } catch (e) { return ""; }
                             }(), style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Social Hub (Integrated Action Bar)
                    Container(
                        padding: const EdgeInsets.only(top: 24),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1)))),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                Row(
                                    children: [
                                        _SocialButton(
                                            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                                            label: "$_likesCount",
                                            isActive: _isLiked,
                                            onTap: _toggleLike
                                        ),
                                        const SizedBox(width: 24),
                                        _SocialButton(
                                            icon: Icons.chat_bubble_outline,
                                            label: "$_commentsCount",
                                            onTap: _showComments
                                        ),
                                        const SizedBox(width: 24),
                                        _SocialButton(
                                            icon: Icons.send_outlined,
                                            label: "",
                                            onTap: _share
                                        ),
                                    ],
                                ),
                                const Icon(Icons.bookmark_outline, color: FfigTheme.primaryBrown, size: 28)
                            ],
                        ),
                    ),
                    // Link Button if exists
                    if (widget.item['link'] != null && widget.item['link'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                                onPressed: () => launchUrl(Uri.parse(widget.item['link'])),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: FfigTheme.primaryBrown, side: const BorderSide(color: FfigTheme.primaryBrown),
                                     padding: const EdgeInsets.symmetric(vertical: 16),
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ),
                                child: const Text("VIEW DETAILS", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            ),
                          ),
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
}

class _SocialButton extends StatelessWidget {
    final IconData icon;
    final String label;
    final VoidCallback onTap;
    final bool isActive;
    
    const _SocialButton({
      required this.icon, 
      required this.label, 
      required this.onTap, 
      this.isActive = false
    });
    
    @override
    Widget build(BuildContext context) {
        return GestureDetector(
            onTap: onTap,
            child: Row(
                children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(color: Colors.white24),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: AnimatedScale(
                        scale: isActive ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(icon, color: isActive ? Colors.redAccent : Colors.white, size: 22)
                      ),
                    ),
                    if (label.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))
                    ]
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
