import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; 
import '../../core/services/admin_api_service.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/utils/dialog_utils.dart';

/// Screen for creating and uploading a new Story.
///
/// **Features:**
/// - Pick image from Gallery.
/// - Required Cropping (9:16 aspect ratio) for consistency.
/// - Uploads to backend via `AdminApiService`.
/// - Supports both Mobile (File) and Web (Bytes) uploads.
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _api = AdminApiService();
  dynamic _selectedFile; // File for Mobile, Uint8List for Web
  bool _isLoading = false;

  /// Picks and crops an image from the gallery.
  /// Picks and crops an image from the gallery.
  /// - Uses `ImagePicker` to select an image.
  /// - Uses `ImageCropper` to enforce 9:16 aspect ratio.
  /// - Sets `_selectedFile` for display and upload.
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
           if (kIsWeb) {
             final bytes = await croppedFile.readAsBytes();
             setState(() => _selectedFile = bytes);
           } else {
             setState(() => _selectedFile = File(croppedFile.path));
           }
        }
    }
  }

  /// Uploads the selected story to the backend.
  /// - Uses `AdminApiService.createStory`.
  /// - Shows loading state during upload.
  /// - Navigates back on success.
  Future<void> _postStory() async {
      if (_selectedFile == null) return;
      
      setState(() => _isLoading = true);
      try {
          await _api.createStory(_selectedFile);
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
             
             // Image Preview Area
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
                                onTap: _pickImage,
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
                            child: kIsWeb 
                                ? Image.memory(_selectedFile, fit: BoxFit.contain)
                                : Image.file(_selectedFile, fit: BoxFit.contain),
                        ),
                ),
             ),
             
             if (_selectedFile != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.refresh, color: Colors.white54),
                      label: const Text("Change Photo", style: TextStyle(color: Colors.white54))
                  ),
                )
          ],
        ),
      ),
    );
  }
}

