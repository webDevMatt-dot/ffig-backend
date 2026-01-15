import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../../core/services/admin_api_service.dart';

class MarketingRequestsScreen extends StatefulWidget {
  const MarketingRequestsScreen({super.key});

  @override
  State<MarketingRequestsScreen> createState() => _MarketingRequestsScreenState();
}

class _MarketingRequestsScreenState extends State<MarketingRequestsScreen> {
  bool _isLoading = false;

  Future<void> _submitRequest(String type) async {
    final titleController = TextEditingController();
    final linkController = TextEditingController();
    
    // File State
    File? selectedFile; 
    Uint8List? selectedBytes;
    bool isVideo = false;

    await showDialog(context: context, builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
                title: Text("Submit $type"),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        TextField(controller: titleController, decoration: const InputDecoration(labelText: "Description/Headline")),
                        TextField(controller: linkController, decoration: const InputDecoration(labelText: "Link URL (CTA)")),
                        const SizedBox(height: 16),
                        
                        // Media Picker
                        GestureDetector(
                            onTap: () async {
                                final picker = ImagePicker();
                                // Show options: Image or Video
                                await showModalBottomSheet(context: context, builder: (c) => SafeArea(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            ListTile(leading: const Icon(Icons.image), title: const Text("Pick Image"), onTap: () async {
                                                Navigator.pop(c);
                                                final xfile = await picker.pickImage(source: ImageSource.gallery);
                                                if (xfile != null) {
                                                    final bytes = await xfile.readAsBytes();
                                                    setDialogState(() {
                                                        selectedFile = kIsWeb ? null : File(xfile.path);
                                                        selectedBytes = bytes;
                                                        isVideo = false;
                                                    });
                                                }
                                            }),
                                            ListTile(leading: const Icon(Icons.videocam), title: const Text("Pick Video (Reel)"), onTap: () async {
                                                Navigator.pop(c);
                                                final xfile = await picker.pickVideo(source: ImageSource.gallery);
                                                if (xfile != null) {
                                                    final bytes = await xfile.readAsBytes();
                                                    setDialogState(() {
                                                        selectedFile = kIsWeb ? null : File(xfile.path);
                                                        selectedBytes = bytes;
                                                        isVideo = true;
                                                    });
                                                }
                                            }),
                                        ],
                                    ),
                                ));
                            },
                            child: Container(
                                height: 150, width: double.infinity,
                                decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: selectedBytes != null 
                                    ? (isVideo 
                                        ? const Icon(Icons.videocam, size: 50, color: Colors.red) 
                                        : Image.memory(selectedBytes!, fit: BoxFit.cover))
                                    : const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                            Icon(Icons.add_a_photo, color: Colors.grey, size: 40),
                                            Text("Add Image or Video (Reel)", style: TextStyle(color: Colors.grey))
                                        ],
                                    ),
                            ),
                        ),
                        if (selectedBytes != null && isVideo)
                            const Padding(padding: EdgeInsets.only(top:8), child: Text("Video Selected", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                    ],
                ),
                actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                    ElevatedButton(
                        onPressed: () async {
                            if (titleController.text.isEmpty) return;
                            Navigator.pop(context); // Close dialog
                            setState(() => _isLoading = true);
                            try {
                                final api = AdminApiService();
                                final fields = {
                                    'type': type == 'Ad' ? 'AD' : 'PROMOTION',
                                    'title': titleController.text,
                                    'link': linkController.text,
                                };
                                
                                dynamic fileToUpload = kIsWeb ? selectedBytes : selectedFile;
                                
                                await api.createMarketingRequestWithMedia(
                                    fields, 
                                    imageFile: !isVideo ? fileToUpload : null,
                                    videoFile: isVideo ? fileToUpload : null,
                                );
                                
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Submitted!")));
                            } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                            } finally {
                                if (mounted) setState(() => _isLoading = false);
                            }
                        },
                        child: const Text("Submit"),
                    )
                ],
            );
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Marketing Center")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _buildBenefitCard("Business Ad", "Launch high-visibility ads in the community feed.", Icons.campaign, () => _submitRequest("Ad")),
             const SizedBox(height: 16),
             _buildBenefitCard("Promotion", "Submit a special offer or discount for members.", Icons.discount, () => _submitRequest("Promotion")),
             const SizedBox(height: 32),
             const Text("My Requests", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
             const SizedBox(height: 16),
             const Center(child: Text("No active requests.", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitCard(String title, String desc, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.amber, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
        trailing: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
          child: const Text("Create"),
        ),
      ),
    );
  }
}
