import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/admin_api_service.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/api/constants.dart';
import 'share_to_chat_sheet.dart';

class VVIPReelsScreen extends StatefulWidget {
  const VVIPReelsScreen({super.key});

  @override
  State<VVIPReelsScreen> createState() => _VVIPReelsScreenState();
}

class _VVIPReelsScreenState extends State<VVIPReelsScreen> {
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
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: FfigTheme.primaryBrown)),
      );
    }

    if (_reels.isEmpty) {
        return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
            body: const Center(child: Text("No VVIP content yet.", style: TextStyle(color: Colors.white))),
        );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            itemCount: _reels.length,
            itemBuilder: (context, index) {
              return _ReelItem(item: _reels[index]);
            },
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}


class _ReelItem extends StatefulWidget {
  final Map<String, dynamic> item;
  const _ReelItem({required this.item});

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  final _api = AdminApiService();
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInit = false;
  
  // Social State
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;

  @override
  void initState() {
    super.initState();
    _initMedia();
    _initSocial();
  }
  
  void _initSocial() {
      _isLiked = widget.item['is_liked'] ?? false;
      _likesCount = widget.item['likes_count'] ?? 0;
      _commentsCount = widget.item['comments_count'] ?? 0;
  }

  Future<void> _initMedia() async {
    var videoUrl = widget.item['video'];
    if (videoUrl != null && videoUrl.toString().isNotEmpty) {
      if (videoUrl.toString().startsWith('/')) {
         final domain = baseUrl.replaceAll('/api/', '');
         videoUrl = '$domain$videoUrl';
      }
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: true,
        aspectRatio: _videoController!.value.aspectRatio,
        showControls: false, // Clean look like Reels/TikTok
      );
      if (mounted) setState(() => _isInit = true);
    } else {
        if (mounted) setState(() => _isInit = true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
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
          if (mounted) setState(() {
               _isLiked = res['status'] == 'liked';
               _likesCount = res['count'];
          });
      } catch (e) {
          // Revert
          if (mounted) setState(() {
               _isLiked = prevLiked;
               _likesCount += _isLiked ? 1 : -1;
          });
      }
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
      showModalBottomSheet(
          context: context, 
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20))
              ),
              child: SafeArea(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          ListTile(
                              leading: const Icon(Icons.share),
                              title: const Text("Share Externally"),
                              onTap: () {
                                  Navigator.pop(context);
                                  final text = "Check out this ${widget.item['type']} on FFig: ${widget.item['title']}\n${widget.item['link'] ?? ''}";
                                  Share.share(text);
                              },
                          ),
                          ListTile(
                              leading: const Icon(Icons.send),
                              title: const Text("Send in App"),
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
    if (imageUrl != null && imageUrl.toString().startsWith('/')) {
        final domain = baseUrl.replaceAll('/api/', '');
        imageUrl = '$domain$imageUrl';
    }

    final bool hasVideo = _chewieController != null;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Content Layer
        if (hasVideo)
          Chewie(controller: _chewieController!)
        else if (imageUrl != null)
          Image.network(imageUrl, fit: BoxFit.cover)
        else
          Container(color: Colors.grey[900], child: const Center(child: Icon(Icons.broken_image, color: Colors.white))),
          
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
            bottom: 100,
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
            bottom: 40,
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
            if (mounted) setState(() => _loading = false);
        }
    }
    
    Future<void> _post() async {
        if (_controller.text.trim().isEmpty) return;
        final content = _controller.text;
        _controller.clear(); 
        // optimistic update?
        try {
            await _api.postMarketingComment(widget.requestId, content);
            _load(); // reload
        } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
        }
    }

    @override
    Widget build(BuildContext context) {
        return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
                children: [
                    const SizedBox(height: 10),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    const Padding(padding: EdgeInsets.all(16), child: Text("Comments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                    Expanded(
                        child: _loading 
                         ? const Center(child: CircularProgressIndicator()) 
                         : ListView.builder(
                             itemCount: _comments.length,
                             itemBuilder: (c, i) {
                                 final com = _comments[i];
                                 var photoUrl = com['photo_url'];
                                 if (photoUrl != null && photoUrl.toString().startsWith('/')) {
                                     final domain = baseUrl.replaceAll('/api/', '');
                                     photoUrl = '$domain$photoUrl';
                                 }
                                 return ListTile(
                                     leading: CircleAvatar(
                                         backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                         child: photoUrl == null || photoUrl.isEmpty ? Text(com['username'][0].toUpperCase()) : null,
                                     ),
                                     title: Text(com['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                     subtitle: Text(com['content']),
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
                                    decoration: InputDecoration(
                                        hintText: "Add a comment...",
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
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
