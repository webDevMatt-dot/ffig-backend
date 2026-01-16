import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/admin_api_service.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/utils/dialog_utils.dart';

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
  final _urlInputController = TextEditingController();
  
  bool _isLoading = false;
  File? _selectedFile;
  dynamic _selectedBytes; // Uint8List?
  bool _isVideo = false;

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
        _urlInputController.clear(); // Clear manual URL if file picked
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate media
    if (_selectedBytes == null && _urlInputController.text.isEmpty) {
      DialogUtils.showError(context, "Media Required", "Please pick an image/video or enter a URL.");
      return;
    }

    setState(() => _isLoading = true);
    
    try {
       final api = AdminApiService();
       final fields = {
         'type': widget.type == 'Ad' ? 'AD' : 'PROMOTION',
         'title': _titleController.text,
         'link': _linkController.text,
       };

       // Determine media payload
       dynamic mediaPayload;
       if (_urlInputController.text.isNotEmpty) {
          mediaPayload = _urlInputController.text;
          // Auto-detect video from URL if possible, but the API service handles string detection
          if (mediaPayload.toLowerCase().endsWith('.mp4') || mediaPayload.toLowerCase().endsWith('.mov')) {
             _isVideo = true;
          }
       } else {
          mediaPayload = kIsWeb ? _selectedBytes : _selectedFile;
       }

       await api.createMarketingRequestWithMedia(
          fields,
          imageFile: !_isVideo ? mediaPayload : null,
          videoFile: _isVideo ? mediaPayload : null,
       );

       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Submitted Successfully!")));
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
                             : (_selectedBytes is Uint8List 
                                  ? Image.memory(_selectedBytes, fit: BoxFit.cover)
                                  : Image.network(_urlInputController.text, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image))
                                )
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
                          icon: const Icon(Icons.image),
                          label: const Text("Pick Image"),
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
                   const Text("- OR -", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 16),
                   TextFormField(
                      controller: _urlInputController,
                      decoration: const InputDecoration(labelText: "Media URL", prefixIcon: Icon(Icons.link), border: OutlineInputBorder()),
                      onChanged: (val) {
                         setState(() {
                            // Clear picked file if user types URL
                            _selectedFile = null;
                            _selectedBytes = null; 
                            if (val.isNotEmpty) {
                               _selectedBytes = val; // Hack to trigger preview logic if I reused it, but better explicit
                               // Logic above uses _selectedBytes != null check. 
                               // Let's set _selectedBytes TO the string if it's a URL for preview?
                               // Or just handle separately.
                               
                               // Actually, for simplicity, I'll rely on Image.network in preview if _selectedBytes is string?
                            }
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
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
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
              child: Text(_isLoading ? "Submitting..." : "SUBMIT REQUEST"),
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
