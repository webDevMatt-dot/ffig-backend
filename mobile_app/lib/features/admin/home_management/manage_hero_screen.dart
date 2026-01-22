import 'dart:typed_data';
import 'dart:io'; 
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/utils/dialog_utils.dart';

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
    if (_searchQuery.isEmpty) {
      _filteredHeroItems = _heroItems;
    } else {
      _filteredHeroItems = _heroItems.where((i) => 
        (i['title'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
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
            toolbarColor: FfigTheme.primaryBrown,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false),
        IOSUiSettings(
          title: 'Crop Hero Image',
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
                    Text(
                      _editingId != null ? "Edit Hero Item" : "Add New Hero Item", 
                      style: Theme.of(context).textTheme.titleLarge
                    ),
                    const SizedBox(height: 20),
                    
                    // Image Picker
                    GestureDetector(
                        onTap: () => _pickImage(setModalState),
                        child: Container(
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade100,
                            border: Border.all(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _selectedImageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _selectedImageBytes is Uint8List
                                      ? Image.memory(_selectedImageBytes as Uint8List, fit: BoxFit.cover)
                                      : Image.network(_selectedImageBytes as String, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 50)),
                                )
                              : (item != null && item['image'] != null 
                                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item['image'], fit: BoxFit.cover))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                        const SizedBox(height: 8),
                                        Text(_editingId != null ? "Tap to replace image" : "Tap to upload image"),
                                      ],
                                    )),
                        ),
                      ),
                    const SizedBox(height: 16),
                    
                    TextField(
                        decoration: const InputDecoration(
                            labelText: "Or Image URL",
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
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
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                      items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setModalState(() => _selectedType = v!),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(labelText: 'Action URL (Optional)', border: OutlineInputBorder()),
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
        'action_url': _urlController.text,
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
      appBar: AppBar(title: const Text("Manage Hero Carousel")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            children: [
                // 1. Search + Add
                Row(
                    children: [
                        Expanded(
                            child: TextField(
                                decoration: InputDecoration(
                                    hintText: "Search items...",
                                    prefixIcon: const Icon(Icons.search),
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
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                            onPressed: () => _showEditor(null),
                            icon: const Icon(Icons.add),
                            label: const Text("Add New"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: FfigTheme.primaryBrown,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                            ),
                        )
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
                                return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        leading: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: item['image'] != null
                                                ? Image.network(item['image'], width: 60, height: 60, fit: BoxFit.cover)
                                                : Container(color: Colors.grey[200], width: 60, height: 60, child: const Icon(Icons.image)),
                                        ),
                                        title: Text(
                                            item['title'] ?? 'No Title', 
                                            style: const TextStyle(fontWeight: FontWeight.bold)
                                        ),
                                        subtitle: Text(item['type'] ?? ''),
                                        trailing: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                        onTap: () => _showEditor(item),
                                    ),
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
