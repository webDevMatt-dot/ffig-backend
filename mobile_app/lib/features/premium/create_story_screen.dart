import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; 
import 'package:video_player/video_player.dart';
import '../../core/services/admin_api_service.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/utils/dialog_utils.dart';

/// Screen for creating and uploading a new Story.
///
/// **Features:**
/// - Pick image from Gallery.
/// - Pick video from Gallery (max 60 seconds).
/// - Required Cropping (9:16 aspect ratio) for images.
/// - Preview for both images and video.
/// - Uploads to backend via `AdminApiService`.
/// - Supports both Mobile (File) and Web (Bytes/Blob) uploads.
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _api = AdminApiService();
  dynamic _selectedFile; // File for Mobile, Uint8List for Web
  bool _isLoading = false;
  bool _isVideo = false; // Track if selected media is video
  VideoPlayerController? _videoController;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  /// Shows a modal to choose between Photo and Video.
  Future<void> _pickMedia() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo, color: Colors.white),
              title: const Text('Photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: const Text('Video', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Picks and crops an image from the gallery.
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
      
    if (xfile != null) {
        // Crop full screen 9:16
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: xfile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Story',
              toolbarColor: Colors.black,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Story',
              aspectRatioLockEnabled: false,
            ),
             WebUiSettings(
              context: context,
            ),
          ],
        );

        if (croppedFile != null) {
           _disposeVideo();
           if (kIsWeb) {
             final bytes = await croppedFile.readAsBytes();
             setState(() {
               _selectedFile = bytes;
               _isVideo = false;
             });
           } else {
             setState(() {
               _selectedFile = File(croppedFile.path);
               _isVideo = false;
             });
           }
        }
    }
  }

  /// Picks a video from the gallery.
  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    // Allow picking video, limited to 60 seconds
    final xfile = await picker.pickVideo(
        source: ImageSource.gallery, 
        maxDuration: const Duration(seconds: 60)
    );
    
    if (xfile != null) {
       _disposeVideo();
       
       if (kIsWeb) {
          final bytes = await xfile.readAsBytes();
           // Initialize video controller for web
           _videoController = VideoPlayerController.networkUrl(Uri.parse(xfile.path));
           
           await _videoController!.initialize();
           setState(() {
             _selectedFile = bytes;
             _isVideo = true;
           });
       } else {
           final file = File(xfile.path);
           _videoController = VideoPlayerController.file(file);
           await _videoController!.initialize();
           setState(() {
             _selectedFile = file;
             _isVideo = true;
           });
       }
       _videoController!.play();
       _videoController!.setLooping(true);
    }
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
  }

  /// Uploads the selected story to the backend.
  Future<void> _postStory() async {
      if (_selectedFile == null) return;
      
      setState(() => _isLoading = true);
      try {
          // Pass _isVideo flag to API
          await _api.createStory(_selectedFile, isVideo: _isVideo);
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Story Posted!")));
              Navigator.pop(context);
          }
      } catch (e) {
           if (mounted) DialogUtils.showError(context, "Error", e.toString());
           setState(() => _isLoading = false);
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
             // Top Bar
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text("New Story", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      TextButton(
                          onPressed: _isLoading || _selectedFile == null ? null : _postStory,
                          child: _isLoading 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                            : const Text("POST", style: TextStyle(color: FfigTheme.primaryBrown, fontWeight: FontWeight.bold))
                      )
                  ],
               ),
             ),
             
             // Preview Area
             Expanded(
                child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(20)
                    ),
                    child: _selectedFile == null 
                        ? Center(
                            child: GestureDetector(
                                onTap: _pickMedia, 
                                child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        shape: BoxShape.circle
                                    ),
                                    child: const Icon(Icons.add_a_photo, color: Colors.white, size: 40)
                                ),
                            )
                        )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _isVideo 
                                ? (_videoController != null && _videoController!.value.isInitialized
                                    ? AspectRatio(
                                        aspectRatio: _videoController!.value.aspectRatio,
                                        child: VideoPlayer(_videoController!),
                                      )
                                    : const Center(child: CircularProgressIndicator()))
                                : (kIsWeb 
                                    ? Image.memory(_selectedFile, fit: BoxFit.contain)
                                    : Image.file(_selectedFile, fit: BoxFit.contain)),
                        ),
                ),
             ),
             
             if (_selectedFile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton.icon(
                      onPressed: _pickMedia,
                      icon: const Icon(Icons.refresh, color: Colors.white54),
                      label: const Text("Change Media", style: TextStyle(color: Colors.white54))
                  ),
                )
          ],
        ),
      ),
    );
  }
}


