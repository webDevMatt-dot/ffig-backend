import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/utils/dialog_utils.dart';

class ManageBusinessScreen extends StatefulWidget {
  const ManageBusinessScreen({super.key});

  @override
  State<ManageBusinessScreen> createState() => _ManageBusinessScreenState();
}

class _ManageBusinessScreenState extends State<ManageBusinessScreen> {
  final _apiService = AdminApiService();
  final _formKey = GlobalKey<FormState>();

  // Form Fields
  final _nameController = TextEditingController();
  final _websiteController = TextEditingController(); // Website
  final _locationController = TextEditingController(); // Location
  final _descriptionController = TextEditingController();
  
  bool _isPremium = false;
  dynamic _selectedImageBytes; 
  File? _selectedImageFile;
  String? _existingImageUrl; 
  String? _editingId; 

  bool _isLoading = false;
  List<dynamic> _items = [];
  List<dynamic> _filteredItems = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  void _filterItems() {
    if (_searchQuery.isEmpty) {
      _filteredItems = _items;
    } else {
      _filteredItems = _items.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        return name.contains(q);
      }).toList();
    }
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _apiService.fetchItems('business');
      setState(() {
        _items = items;
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
        // Web fallthrough (Cropping not supported on web by default)
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
          toolbarTitle: 'Crop Business Logo',
          toolbarColor: FfigTheme.primaryBrown,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Business Logo',
        ),
      ],
    );
    if (croppedFile != null) return File(croppedFile.path);
    return null;
  }

  void _showEditor(Map<String, dynamic>? item) {
    if (item != null) {
      _editingId = item['id'].toString();
      _nameController.text = item['name'] ?? '';
      _websiteController.text = item['website'] ?? '';
      _locationController.text = item['location'] ?? item['country'] ?? '';
      _descriptionController.text = item['description'] ?? item['bio'] ?? '';
      _isPremium = item['is_premium'] ?? false;
      _existingImageUrl = item['image_url'] ?? item['photo_url'];
      _selectedImageBytes = null;
    } else {
      _editingId = null;
      _nameController.clear();
      _websiteController.clear();
      _locationController.clear();
      _descriptionController.clear();
      _isPremium = false;
      _existingImageUrl = null;
      _selectedImageBytes = null;
      _selectedImageFile = null;
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
                      _editingId != null ? "Edit Business" : "Add Business", 
                      style: Theme.of(context).textTheme.titleLarge
                    ),
                    const SizedBox(height: 20),
                    
                    // Photo
                    Center(
                      child: GestureDetector(
                        onTap: () => _pickImage(setModalState),
                        child: Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _selectedImageBytes != null
                              ? (_selectedImageBytes is Uint8List
                                    ? Image.memory(_selectedImageBytes as Uint8List, fit: BoxFit.cover)
                                    : Image.network(_selectedImageBytes as String, fit: BoxFit.cover))
                              : (_existingImageUrl != null
                                    ? Image.network(_existingImageUrl!, fit: BoxFit.cover)
                                    : const Icon(Icons.add_business, size: 40, color: Colors.grey)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Business Name', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(labelText: 'Website', border: OutlineInputBorder()),
                      // validator: (v) => v!.isEmpty ? 'Required' : null, // Optional
                    ),
                    const SizedBox(height: 16),
                    
                    GestureDetector(
                      onTap: () {
                        showCountryPicker(
                          context: context,
                          showPhoneCode: false,
                          onSelect: (Country country) {
                            setModalState(() {
                              _locationController.text = country.name;
                            });
                          },
                        );
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: 'Location/Country',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    SwitchListTile(
                      title: const Text("Is Verified/Premium?"),
                      value: _isPremium,
                      onChanged: (v) => setModalState(() => _isPremium = v),
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
                            child: Text(_editingId != null ? "Save Changes" : "Create Business"),
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
    
    // Validation: Image optional if editing
    if (_editingId == null && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a logo/image')));
      return;
    }
    
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final fields = {
        'name': _nameController.text,
        'website': _websiteController.text,
        'location': _locationController.text,
        'description': _descriptionController.text,
        'is_premium': _isPremium.toString(),
        'is_active': 'true',
      };

      dynamic imageToUpload;
      if (_selectedImageBytes != null) {
        imageToUpload = kIsWeb ? _selectedImageBytes : _selectedImageFile;
      }

      if (_editingId != null) {
        await _apiService.updateHomepageBusiness(_editingId!, fields, imageToUpload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business Updated!')));
      } else {
        await _apiService.createHomepageBusiness(fields, imageToUpload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business Created!')));
      }
      _fetchItems();
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Upload Failed", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    setState(() => _isLoading = true);
    try {
      final newState = !(item['is_active'] ?? true);
      await _apiService.updateHomepageBusiness(item['id'].toString(), {
        'is_active': newState.toString(),
      }, null);

      _fetchItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newState ? "Business Activated" : "Business Deactivated")),
      );
      }
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Update Failed", e.toString());
      setState(() => _isLoading = false);
    }
  }
  
  void _confirmDelete(int id) {
      showDialog(
          context: context, 
          builder: (c) => AlertDialog(
              title: const Text("Delete Business?"),
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
      await _apiService.deleteItem('business', id);
       _fetchItems();
    } catch (e) {
       if (mounted) DialogUtils.showError(context, "Delete Failed", e.toString());
       setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Business of Month")),
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
                                    hintText: "Search businesses...",
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
                    : _filteredItems.isEmpty 
                        ? Center(child: Text("No items found. Add one above.", style: TextStyle(color: Colors.grey[600])))
                        : ListView.builder(
                              itemCount: _filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = _filteredItems[index];
                                final isActive = item['is_active'] ?? true;
                                
                                return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        leading: CircleAvatar(
                                            backgroundImage: item['image_url'] != null ? NetworkImage(item['image_url']) : null,
                                            child: item['image_url'] == null ? const Icon(Icons.business) : null,
                                        ),
                                        title: Text(
                                            item['name'] ?? 'No Name', 
                                            style: const TextStyle(fontWeight: FontWeight.bold)
                                        ),
                                        subtitle: Text(
                                          "${item['website'] ?? ''} • ${item['location'] ?? ''}",
                                          maxLines: 1, overflow: TextOverflow.ellipsis
                                        ),
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
