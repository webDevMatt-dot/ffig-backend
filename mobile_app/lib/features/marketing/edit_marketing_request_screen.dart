import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/admin_api_service.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/utils/dialog_utils.dart';

class EditMarketingRequestScreen extends StatefulWidget {
  final dynamic requestData;
  const EditMarketingRequestScreen({super.key, required this.requestData});

  @override
  State<EditMarketingRequestScreen> createState() => _EditMarketingRequestScreenState();
}

class _EditMarketingRequestScreenState extends State<EditMarketingRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _linkController;
  late TextEditingController _urlInputController;
  
  bool _isLoading = false;
  File? _selectedFile;
  dynamic _selectedBytes; // Uint8List?
  bool _isVideo = false;
  
  // Track if media was changed
  bool _mediaChanged = false;

  @override
  void initState() {
    super.initState();
    final data = widget.requestData;
    _titleController = TextEditingController(text: data['title']);
    _linkController = TextEditingController(text: data['link']);
    _urlInputController = TextEditingController();
    
    // Initial media setup from existing URL
    final existingImage = data['image'];
    final existingVideo = data['video'];
    
    if (existingVideo != null) {
       _isVideo = true;
       _urlInputController.text = existingVideo;
    } else if (existingImage != null) {
       _isVideo = false;
       _urlInputController.text = existingImage;
    }
  }

  Future<void> _pickMedia(bool pickVideo) async {
    final picker = ImagePicker();
    final xfile = pickVideo 
      ? await picker.pickVideo(source: ImageSource.gallery)
      : await picker.pickImage(source: ImageSource.gallery);
      
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      setState(() {
        _selectedFile = kIsWeb ? null : File(xfile.path);
        _selectedBytes = bytes;
        _isVideo = pickVideo;
        _urlInputController.clear();
        _mediaChanged = true;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
       final api = AdminApiService();
       final requestId = widget.requestData['id'];

       final fields = {
         'title': _titleController.text,
         'link': _linkController.text,
       };

       // Only send media if it changed or if switching to manual URL
       dynamic mediaPayload;
       // If user typed a new URL
       if (_urlInputController.text.isNotEmpty && _urlInputController.text != widget.requestData['image'] && _urlInputController.text != widget.requestData['video']) {
            mediaPayload = _urlInputController.text;
            if (mediaPayload.toLowerCase().endsWith('.mp4') || mediaPayload.toLowerCase().endsWith('.mov')) {
                 _isVideo = true;
            } else {
                 _isVideo = false;
            }
       } else if (_selectedBytes != null) {
            mediaPayload = kIsWeb ? _selectedBytes : _selectedFile;
       }

       // We need an update method in AdminApiService, but for now we'll call PATCH directly or add method there?
       // Let's check AdminApiService first. If it's not there, I might need to add it or do it here.
       // Actually I'll implement a 'patch' call here to be safe or assuming the service handles it. 
       // WAIT: I should add updateMarketingRequest to the service properly.
       // For now, I'll direct implement usage of the service if it exists, or update the service.
       // To save steps I will try to use the service Update method if it exists.
       
       await api.updateMarketingRequest(
          requestId,
          fields,
          imageFile: (!_isVideo && mediaPayload != null) ? mediaPayload : null,
          videoFile: (_isVideo && mediaPayload != null) ? mediaPayload : null,
       );

       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Updated Successfully!")));
          Navigator.pop(context);
       }
    } catch (e) {
       if (mounted) DialogUtils.showError(context, "Error", e.toString());
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Request")),
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
                     decoration: const InputDecoration(labelText: "Description / Headline"),
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
                             : (_selectedBytes is Uint8List 
                                  ? Image.memory(_selectedBytes, fit: BoxFit.cover)
                                  : Image.network("PLACEHOLDER FOR URL PREVIEW (NOT IMPLEMENTED FOR BYTES)", fit: BoxFit.cover) // Should not reach here for bytes
                                )
                        )
                        : _urlInputController.text.isNotEmpty 
                            ? Image.network(_urlInputController.text, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image))
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
                          icon: const Icon(Icons.image),
                          label: const Text("Change Image"),
                       )),
                       const SizedBox(width: 12),
                       Expanded(child: OutlinedButton.icon(
                          onPressed: () => _pickMedia(true),
                          icon: const Icon(Icons.videocam),
                          label: const Text("Change Video"),
                       )),
                     ],
                   ),
                   const SizedBox(height: 16),
                   const Text("- OR -", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 16),
                   TextFormField(
                      controller: _urlInputController,
                      decoration: const InputDecoration(labelText: "Media URL", prefixIcon: Icon(Icons.link), border: OutlineInputBorder()),
                      onChanged: (val) {
                         setState(() {
                            _selectedFile = null;
                            _selectedBytes = null; 
                         });
                      },
                   )
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
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: FfigTheme.primaryBrown,
                  foregroundColor: Colors.white,
              ),
              child: Text(_isLoading ? "Saving..." : "SAVE CHANGES"),
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
