import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';

/// A utility widget to view images and videos in full screen.
///
/// **Features:**
/// - Supports both Network URLs and Local Files.
/// - Zoomable Image View (using `PhotoView`).
/// - Video Playback with Controls (using `Chewie`).
class FullScreenMediaViewer extends StatefulWidget {
  final String? url;
  final File? file;
  final bool isVideo;

  const FullScreenMediaViewer({
    super.key,
    this.url,
    this.file,
    this.isVideo = false,
  });

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideo();
    } else {
      _isLoading = false;
    }
  }

  /// Initializes the video player controller.
  /// - Determines source (File vs Network).
  /// - Sets up `Chewie` for playback controls.
  Future<void> _initVideo() async {
    try {
      if (widget.file != null) {
        _videoController = VideoPlayerController.file(widget.file!);
      } else if (widget.url != null) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url!));
      }

      if (_videoController != null) {
        await _videoController!.initialize();
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: true,
          aspectRatio: _videoController!.value.aspectRatio,
          // Full screen controls
          allowFullScreen: false, // We ARE full screen
          allowMuting: true,
          showControls: true, 
        );
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Full Screen Video Error: $e");
      if (mounted) setState(() => _isLoading = false);
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: widget.isVideo
                ? _buildVideo()
                : _buildImage(),
          ),
          
          // Close Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildImage() {
    ImageProvider? provider;
    if (widget.file != null) {
      provider = FileImage(widget.file!);
    } else if (widget.url != null) {
      provider = NetworkImage(widget.url!);
    }

    if (provider == null) return const Icon(Icons.broken_image, color: Colors.white);

    return PhotoView(
      imageProvider: provider,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 2,
    );
  }

  Widget _buildVideo() {
    if (_isLoading) return const CircularProgressIndicator(color: Colors.white);
    if (_chewieController != null) {
       return SafeArea(child: Chewie(controller: _chewieController!));
    }
    return const Text("Failed to load video", style: TextStyle(color: Colors.white));
  }
}
