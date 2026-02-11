import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; 
import '../../core/theme/ffig_theme.dart';
import '../../core/utils/dialog_utils.dart';
import 'preview_marketing_post_screen.dart'; 

/// Screen for creating a new Marketing Request (Ad or Promotion).
///
/// **Features:**
/// - Supports Image and Video uploads.
/// - Integrated Image Cropper (16:9 ratio for consistency).
/// - Form for Title, Link, and Category (Ad vs Promotion).
/// - Navigates to `PreviewMarketingPostScreen` for final review.
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
  
  late String _selectedType;
  dynamic _selectedFile; // File or CroppedFile
  dynamic _selectedBytes; // Uint8List? for Web preview
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.type;
  }

  /// Picks media (Image or Video) from the gallery.
  /// - **Images:** Enforces 16:9 cropping to ensure high-quality feed display.
  /// - **Videos:** Selected as-is (no cropping supported yet).
  Future<void> _pickMedia(bool pickVideo) async {
    final picker = ImagePicker();
    final xfile = pickVideo 
      ? await picker.pickVideo(source: ImageSource.gallery)
      : await picker.pickImage(source: ImageSource.gallery);
      
    if (xfile != null) {
      if (!pickVideo) {
        if (!mounted) return;
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
             'type': _selectedType,
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
      appBar: AppBar(title: const Text("Make a Post")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
                // Media Selection (First)
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (BuildContext context) {
                        return SafeArea(
                          child: Wrap(
                            children: <Widget>[
                              ListTile(
                                leading: const Icon(Icons.image),
                                title: const Text('Image'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickMedia(false);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.videocam),
                                title: const Text('Video'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickMedia(true);
                                },
                              ),
                            ],
                          ),
                        );
                      }
                    );
                  },
                  child: Container(
                    height: 400, // Taller, like story creation
                    width: double.infinity,
                    decoration: BoxDecoration(
                       color: Colors.grey[900],
                       borderRadius: BorderRadius.circular(20),
                       border: Border.all(color: Colors.grey[800]!)
                    ),
                    alignment: Alignment.center,
                    child: _selectedBytes != null || _selectedFile != null
                       ? ClipRRect(
                           borderRadius: BorderRadius.circular(20),
                           child: _isVideo 
                             ? const Icon(Icons.play_circle_outline, size: 80, color: Colors.white)
                             : Image.memory(_selectedBytes!, fit: BoxFit.contain) 
                           // Note: simplified to just use memory bytes for preview as logic sets it for both
                         )
                       : Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Container(
                               padding: const EdgeInsets.all(20),
                               decoration: BoxDecoration(
                                   color: Colors.white.withValues(alpha: 0.1),
                                   shape: BoxShape.circle
                               ),
                               child: const Icon(Icons.add_a_photo, color: Colors.white, size: 40)
                           ),
                           const SizedBox(height: 12),
                           const Text("Tap to add Media", style: TextStyle(color: Colors.white54))
                         ]
                       ),
                  ),
                ),
                if (_selectedBytes != null)
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Center(
                       child: TextButton.icon(
                         onPressed: () {
                             setState(() {
                               _selectedFile = null;
                               _selectedBytes = null;
                               _isVideo = false;
                             });
                         },
                         icon: const Icon(Icons.delete, color: Colors.red),
                         label: const Text("Remove Media", style: TextStyle(color: Colors.red))
                       ),
                     ),
                   ),

                const SizedBox(height: 24),

                // TYPE SELECTION
                _buildSection("Post Type", [
                   SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'Ad',
                        label: Text('Business Ad'),
                        icon: Icon(Icons.campaign),
                      ),
                      ButtonSegment<String>(
                        value: 'Promotion', 
                        label: Text('Promotion'), 
                        icon: Icon(Icons.discount)
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedType = newSelection.first;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        return states.contains(WidgetState.selected) 
                            ? FfigTheme.primaryBrown 
                            : Colors.transparent;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                        return states.contains(WidgetState.selected) 
                            ? Colors.white 
                            : Colors.white70;
                      }),
                    ),
                  )
                ]),

                const SizedBox(height: 16),

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
              onPressed: _goToPreview, 
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: FfigTheme.primaryBrown,
                  foregroundColor: Colors.white,
              ),
              child: const Text("PREVIEW REQUEST"), 
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
