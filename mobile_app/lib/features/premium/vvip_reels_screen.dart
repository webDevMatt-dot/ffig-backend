import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/admin_api_service.dart';
import '../../core/theme/ffig_theme.dart';

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
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  Future<void> _initMedia() async {
    final videoUrl = widget.item['video'];
    if (videoUrl != null && videoUrl.toString().isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: true,
        aspectRatio: _videoController!.value.aspectRatio,
        showControls: false, // Clean look like Reels/TikTok
      );
      setState(() => _isInit = true);
    } else {
        setState(() => _isInit = true);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
        return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final imageUrl = widget.item['image'];
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
               colors: [Colors.transparent, Colors.black54],
               stops: [0.6, 1.0],
             ),
           ),
        ),

        // Info Layer
        Positioned(
            bottom: 40,
            left: 16,
            right: 16,
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
