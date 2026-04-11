import 'dart:typed_data';
import 'dart:io'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/url_utils.dart';
import '../../home/models/hero_item.dart';
import '../../home/widgets/hero_banner.dart';
import '../widgets/admin_dark_list_item.dart';

class ManageHeroScreen extends StatefulWidget {
  const ManageHeroScreen({super.key});

  @override
  State<ManageHeroScreen> createState() => _ManageHeroScreenState();
}

class _ManageHeroScreenState extends State<ManageHeroScreen> {
  final _apiService = AdminApiService();
  final _formKey = GlobalKey<FormState>();
  
  // Form Fields
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();
  String _selectedType = 'Announcement';
  dynamic _selectedImageBytes; 
  File? _selectedImageFile;
  
  String? _editingId; 
  bool _isLoading = false;
  List<dynamic> _heroItems = [];
  List<dynamic> _filteredHeroItems = [];
  String _searchQuery = "";

  final List<String> _types = [
    'Announcement',
    'Sponsorship',
    'Update',
    'Opportunity',
    'Community',
  ];

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }
  
  void _filterItems() {
     final query = _searchQuery.trim().toLowerCase();
     if (query.isEmpty) {
       _filteredHeroItems = List.from(_heroItems);
     } else {
       final terms = query.split(' ').where((t) => t.isNotEmpty).toList();
       _filteredHeroItems = _heroItems.where((i) {
          final title = (i['title'] ?? '').toString().toLowerCase();
          final type = (i['type'] ?? '').toString().toLowerCase();
          final url = (i['action_url'] ?? '').toString().toLowerCase();
          
          return terms.every((term) => 
            title.contains(term) || 
            type.contains(term) || 
            url.contains(term)
          );
       }).toList();
     }
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _apiService.fetchItems('hero');
      setState(() {
        _heroItems = items;
        _filterItems();
      });

    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Load Failed", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(StateSetter setModalState) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      if (!kIsWeb) {
        // Crop logic for Mobile
        final croppedFile = await _cropImage(File(pickedFile.path));
        if (croppedFile != null) {
             final bytes = await croppedFile.readAsBytes();
             setModalState(() {
                _selectedImageBytes = bytes;
                _selectedImageFile = croppedFile;
             });
        }
      } else {
        // Web fallthrough (Cropping not supported on web by default easily without setup, or use standard bytes)
        final bytes = await pickedFile.readAsBytes();
        setModalState(() {
            _selectedImageBytes = bytes;
        });
      }
    }
  }

  Future<File?> _cropImage(File imageFile) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Hero Image',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
            activeControlsWidgetColor: FfigTheme.primaryBrown,
        ),
        IOSUiSettings(
          title: 'Crop Hero Image',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );
    if (croppedFile != null) return File(croppedFile.path);
    return null;
  }

  void _showEditor(Map<String, dynamic>? item) {
    if (item != null) {
        _editingId = item['id'].toString();
        _titleController.text = item['title'] ?? '';
        _urlController.text = item['action_url'] ?? '';
        _selectedType = _types.contains(item['type']) ? item['type'] : _types.first;
        _selectedImageBytes = null; // Don't pre-fill with downloaded bytes, just show current URL in UI if no new bytes
    } else {
        _editingId = null;
        _titleController.clear();
        _urlController.clear();
        _selectedImageBytes = null;
        _selectedImageFile = null;
        _selectedType = _types.first;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, 
              top: 20, left: 20, right: 20
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: "Close",
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _editingId != null ? "Edit Hero Item" : "Add Hero Item", 
                              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                    ),
                    const SizedBox(height: 24),
                    
                    const Text("PREVIEW & IMAGE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _pickImage(setModalState),
                      child: Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: HeroBanner(
                              isPreview: true,
                              localImageBytes: _selectedImageBytes is Uint8List ? _selectedImageBytes as Uint8List : null,
                              item: HeroItem(
                                id: _editingId ?? 'preview',
                                title: _titleController.text,
                                type: _selectedType,
                                imageUrl: _selectedImageBytes is String ? _selectedImageBytes as String : (item?['image'] ?? ''),
                                actionUrl: _urlController.text,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: FfigTheme.accentBrown,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                                ],
                              ),
                              child: const Icon(Icons.edit, size: 20, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Text("CONTENT DETAILS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Hero Title', 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.title),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      onChanged: (v) => setModalState(() {}),
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Category / Type', 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.category),
                      ),
                      items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setModalState(() => _selectedType = v!),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: 'Action Link (Optional)', 
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.link),
                      ),
                      onChanged: (v) => setModalState(() {}),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                        decoration: InputDecoration(
                            labelText: "Or External Image URL",
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.image_search, size: 20),
                        ),
                        onChanged: (val) {
                            setModalState(() {
                                if (val.isNotEmpty) {
                                    _selectedImageBytes = val;
                                    _selectedImageFile = null;
                                } else {
                                    _selectedImageBytes = null;
                                }
                            });
                        },
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        if (_editingId != null) ...[
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                               Navigator.pop(ctx);
                               _confirmDelete(int.parse(_editingId!));
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                 Navigator.pop(ctx);
                                 _toggleActive(item);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Icon(
                                (item!['is_active'] ?? true) ? Icons.visibility_off : Icons.visibility,
                                color: (item['is_active'] ?? true) ? Colors.grey : Colors.green
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FfigTheme.primaryBrown,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(_editingId != null ? "Save Changes" : "Create Item"),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        }
      )
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validation: Image is required for CREATE, but optional for UPDATE
    if (_editingId == null && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }
    
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final fields = {
        'title': _titleController.text,
        'action_url': normalizeUrl(_urlController.text),
        'type': _selectedType,
        'is_active': 'true',
      };

      dynamic imageToUpload;
      if (_selectedImageBytes != null) {
          imageToUpload = kIsWeb ? _selectedImageBytes : _selectedImageFile;
      }

      if (_editingId != null) {
         await _apiService.updateHeroItem(_editingId!, fields, imageToUpload);
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hero Item Updated!')));
      } else {
         await _apiService.createHeroItem(fields, imageToUpload); 
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hero Item Added!')));
      }
      
      _fetchItems();
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Action Failed", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    final id = item['id'];
    final isActive = item['is_active'] ?? true; 
    final newState = !isActive;

    setState(() => _isLoading = true);
    try {
      final Map<String, String> fields = {
         'title': (item['title'] ?? '').toString(),
         'action_url': (item['action_url'] ?? '').toString(),
         'type': (item['type'] ?? 'Announcement').toString(),
         'is_active': newState.toString(),
      };
      
      await _apiService.updateHeroItem(id.toString(), fields, null);
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newState ? "Item Activated" : "Item Deactivated")));
      _fetchItems();
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Toggle Failed", e.toString());
      setState(() => _isLoading = false);
    }
  }
  
  void _confirmDelete(int id) {
      showDialog(
          context: context, 
          builder: (c) => AlertDialog(
              title: const Text("Delete Item?"),
              content: const Text("This action cannot be undone."),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
                  TextButton(
                      onPressed: () {
                          Navigator.pop(c);
                          _deleteItem(id);
                      }, 
                      child: const Text("Delete", style: TextStyle(color: Colors.red))
                  )
              ],
          )
      );
  }

  Future<void> _deleteItem(int id) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.deleteItem('hero', id);
       _fetchItems();
    } catch (e) {
       if (mounted) DialogUtils.showError(context, "Delete Failed", e.toString());
       setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Hero Carousel"),
        actions: [
          IconButton(
            onPressed: () => _showEditor(null),
            icon: const Icon(Icons.add, size: 34),
            tooltip: "Add Hero Item",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            children: [
                // 1. Search + Add
                Row(
                    children: [
                        Expanded(
                            child: TextField(
                                controller: TextEditingController.fromValue(
                                  TextEditingValue(
                                    text: _searchQuery,
                                    selection: TextSelection.collapsed(offset: _searchQuery.length),
                                  ),
                                ),
                                decoration: InputDecoration(
                                    hintText: "Search banners...",
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _searchQuery.isNotEmpty 
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 20),
                                            onPressed: () {
                                              setState(() {
                                                _searchQuery = "";
                                                _filterItems();
                                              });
                                            },
                                          )
                                        : null,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16)
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                    _filterItems();
                                  });
                                },
                            ),
                        ),
                    ],
                ),
                
                const SizedBox(height: 16),
                
                // 2. List
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator()) 
                    : _filteredHeroItems.isEmpty 
                        ? Center(child: Text("No items found. Add one above.", style: TextStyle(color: Colors.grey[600])))
                        : ListView.builder(
                              itemCount: _filteredHeroItems.length,
                              itemBuilder: (context, index) {
                                final item = _filteredHeroItems[index];
                                final isActive = item['is_active'] ?? true;
                                return AdminDarkListItem(
                                  title: item['title'] ?? 'No Title',
                                  subtitle: item['type'] ?? '',
                                  imageUrl: item['image'],
                                  fallbackIcon: Icons.image,
                                  onTap: () => _showEditor(item),
                                  statusChip: !isActive
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            "INACTIVE",
                                            style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      : null,
                                );
                              },
                        ),
                ),
            ],
        ),
      ),
    );
  }
}
