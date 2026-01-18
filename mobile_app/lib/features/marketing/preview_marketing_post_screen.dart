import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/services/admin_api_service.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/utils/dialog_utils.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class PreviewMarketingPostScreen extends StatefulWidget {
  final Map<String, dynamic> formData; // title, link, type
  final dynamic mediaFile; // File, CroppedFile, Uint8List (web), or String (URL)
  final bool isVideo;

  const PreviewMarketingPostScreen({
    super.key,
    required this.formData,
    required this.mediaFile,
    required this.isVideo,
  });

  @override
  State<PreviewMarketingPostScreen> createState() => _PreviewMarketingPostScreenState();
}

class _PreviewMarketingPostScreenState extends State<PreviewMarketingPostScreen> {
  bool _isLoading = false;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      if (widget.mediaFile is File) {
        _videoController = VideoPlayerController.file(widget.mediaFile);
      } else if (widget.mediaFile is String) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaFile));
      } else if (kIsWeb && widget.mediaFile is Uint8List) {
         // Video bytes on web not easily supported by standard video_player without blob URL
         // For now, assume network URL for web video or skip preview
      }

      if (_videoController != null) {
        await _videoController!.initialize();
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
          aspectRatio: _videoController!.value.aspectRatio,
        );
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Video init error: $e");
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _submitFormat() async {
    setState(() => _isLoading = true);
    try {
       final api = AdminApiService();
       final fields = {
         'type': widget.formData['type'] == 'Ad' ? 'AD' : 'PROMOTION',
         'title': widget.formData['title'].toString(),
         'link': widget.formData['link'].toString(),
       };

       // Prepare media payload
       dynamic finalMedia = widget.mediaFile;
       
       // If CroppedFile, get File path or bytes
       if (finalMedia is CroppedFile) {
          if (kIsWeb) {
             finalMedia = await finalMedia.readAsBytes();
          } else {
             finalMedia = File(finalMedia.path);
          }
       }

       await api.createMarketingRequestWithMedia(
          fields,
          imageFile: !widget.isVideo ? finalMedia : null,
          videoFile: widget.isVideo ? finalMedia : null,
       );

       if (mounted) {
          // Success!
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Submitted Successfully!")));
          // Pop twice to go back to list (Preview -> Form -> List)
          Navigator.of(context)..pop()..pop(); 
       }
    } catch (e) {
       if (mounted) DialogUtils.showError(context, "Submission Failed", e.toString());
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // This UI attempts to mimic the feed card logic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(title: const Text("Preview Post")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              width: double.infinity,
              child: const Text(
                "This is how your post will appear in the community feed.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            
            // The Card
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: FfigTheme.primaryBrown,
                      child: const Text("ME", style: TextStyle(color: Colors.white)),
                    ),
                    title: const Text("You (Preview)", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        widget.formData['type'] == 'Ad' ? 'Sponsored • Just now' : 'Promotion • Just now'
                    ),
                    trailing: const Icon(Icons.more_vert),
                  ),
                  
                  // Text Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      widget.formData['title'] ?? '',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  
                  // Media
                  if (widget.mediaFile != null)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: Colors.black,
                        child: widget.isVideo 
                           ? _chewieController != null 
                              ? Chewie(controller: _chewieController!)
                              : const Center(child: CircularProgressIndicator())
                           : _buildImageWidget(),
                      ),
                    ),

                  // Footer Actions
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.favorite_border, color: isDark ? Colors.white70 : Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text("0", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600])),
                            const SizedBox(width: 16),
                            Icon(Icons.comment_outlined, color: isDark ? Colors.white70 : Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text("0", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600])),
                          ],
                        ),
                        if (widget.formData['link'] != null && widget.formData['link'].toString().isNotEmpty)
                           ElevatedButton(
                              onPressed: () {}, // Dummy
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                                foregroundColor: isDark ? Colors.white : Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              child: const Text("Visit Link")
                           )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
             children: [
               Expanded(
                 child: OutlinedButton(
                   onPressed: () => Navigator.pop(context),
                   style: OutlinedButton.styleFrom(
                     padding: const EdgeInsets.symmetric(vertical: 16),
                     side: BorderSide(color: Theme.of(context).dividerColor)
                   ),
                   child: const Text("EDIT"),
                 ),
               ),
               const SizedBox(width: 16),
               Expanded(
                 flex: 2,
                 child: ElevatedButton(
                   onPressed: _isLoading ? null : _submitFormat,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: FfigTheme.primaryBrown,
                     foregroundColor: Colors.white,
                     padding: const EdgeInsets.symmetric(vertical: 16),
                   ),
                   child: Text(_isLoading ? "POSTING..." : "CONFIRM & POST"),
                 ),
               )
             ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
     final media = widget.mediaFile;
     if (media is File) return Image.file(media, fit: BoxFit.cover);
     if (media is CroppedFile) return Image.file(File(media.path), fit: BoxFit.cover);
     if (media is String) return Image.network(media, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image));
     if (media is Uint8List) return Image.memory(media, fit: BoxFit.cover);
     return const SizedBox(); 
  }
}
