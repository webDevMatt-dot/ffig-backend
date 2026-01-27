import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // IMPORT ADDED
import '../../core/services/admin_api_service.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/utils/dialog_utils.dart';
import 'preview_marketing_post_screen.dart'; // IMPORT ADDED

class CreateMarketingRequestScreen extends StatefulWidget {
  final String type; // 'Ad' or 'Promotion'
  const CreateMarketingRequestScreen({super.key, required this.type});

  @override
  State<CreateMarketingRequestScreen> createState() => _CreateMarketingRequestScreenState();
}

class _CreateMarketingRequestScreenState extends State<CreateMarketingRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _linkController = TextEditingController();
  // removed urlInputController
  
  final bool _isLoading = false;
  dynamic _selectedFile; // File or CroppedFile
  dynamic _selectedBytes; // Uint8List? for Web preview
  bool _isVideo = false;

  Future<void> _pickMedia(bool pickVideo) async {
    final picker = ImagePicker();
    final xfile = pickVideo 
      ? await picker.pickVideo(source: ImageSource.gallery)
      : await picker.pickImage(source: ImageSource.gallery);
      
    if (xfile != null) {
      if (!pickVideo) {
        // CROP IMAGE
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: xfile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Edit Image',
              toolbarColor: Colors.black,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.ratio16x9,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Edit Image',
              aspectRatioLockEnabled: false,
            ),
            WebUiSettings(
              context: context,
            ),
          ],
        );

        if (croppedFile != null) {
           final bytes = await croppedFile.readAsBytes();
           setState(() {
             _selectedFile = croppedFile; 
             _selectedBytes = bytes;
             _isVideo = false;
             // _urlInputController.clear();
           });
        }
      } else {
        // VIDEO (No cropping)
        final bytes = await xfile.readAsBytes();
        setState(() {
          _selectedFile = kIsWeb ? null : File(xfile.path);
          _selectedBytes = bytes;
          _isVideo = true;
          // _urlInputController.clear();
        });
      }
    }
  }

  void _goToPreview() {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate media
    if (_selectedBytes == null && _selectedFile == null) {
      DialogUtils.showError(context, "Media Required", "Please pick an image/video.");
      return;
    }

    final media = _selectedFile ?? _selectedBytes;

    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (c) => PreviewMarketingPostScreen(
           formData: {
             'type': widget.type,
             'title': _titleController.text,
             'link': _linkController.text,
           },
           mediaFile: media,
           isVideo: _isVideo,
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Submit ${widget.type}")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
                _buildSection("Details", [
                   TextFormField(
                     controller: _titleController,
                     decoration: const InputDecoration(labelText: "Description / Headline", helperText: "What is this for?"),
                     validator: (v) => v!.isEmpty ? "Required" : null,
                     maxLines: 2,
                   ),
                   const SizedBox(height: 16),
                   TextFormField(
                     controller: _linkController,
                     decoration: const InputDecoration(labelText: "Link URL (CTA)", prefixIcon: Icon(Icons.link)),
                   ),
                ]),
                const SizedBox(height: 24),
                
                _buildSection("Media", [
                   // Preview
                   Container(
                     height: 200,
                     width: double.infinity,
                     decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[400]!)
                     ),
                     alignment: Alignment.center,
                     child: _selectedBytes != null 
                        ? (_isVideo 
                             ? const Icon(Icons.videocam, size: 60, color: Colors.red)
                             : Image.memory(_selectedBytes, fit: BoxFit.cover)
                           )
                        : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, size: 50, color: Colors.grey),
                             Text("No Media Selected", style: TextStyle(color: Colors.grey))
                          ]
                        ),
                   ),
                   const SizedBox(height: 16),
                   Row(
                     children: [
                       Expanded(child: OutlinedButton.icon(
                          onPressed: () => _pickMedia(false),
                          icon: const Icon(Icons.crop_original),
                          label: const Text("Pick & Crop Image"),
                       )),
                       const SizedBox(width: 12),
                       Expanded(child: OutlinedButton.icon(
                          onPressed: () => _pickMedia(true),
                          icon: const Icon(Icons.videocam),
                          label: const Text("Pick Video"),
                       )),
                     ],
                   ),
                   const SizedBox(height: 16),
                   const SizedBox(height: 16),
                   // Removed Media URL input
                ]),
                
                const SizedBox(height: 80),
             ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _goToPreview, // Changed from _submit
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: FfigTheme.primaryBrown,
                  foregroundColor: Colors.white,
              ),
              child: const Text("PREVIEW REQUEST"), // Changed Label
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            const SizedBox(height: 12),
            ...children
          ],
        ),
      ),
    );
  }
}
