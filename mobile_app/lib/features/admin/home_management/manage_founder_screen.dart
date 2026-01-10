import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';

class ManageFounderScreen extends StatefulWidget {
  const ManageFounderScreen({super.key});

  @override
  State<ManageFounderScreen> createState() => _ManageFounderScreenState();
}

class _ManageFounderScreenState extends State<ManageFounderScreen> {
  final _apiService = AdminApiService();
  final _formKey = GlobalKey<FormState>();

  // Form Fields
  final _nameController = TextEditingController();
  final _businessController = TextEditingController();
  final _countryController = TextEditingController();
  final _bioController = TextEditingController();
  
  bool _isPremium = false;
  Uint8List? _selectedImageBytes;
  File? _selectedImageFile;
  String? _editingId; // If null, we are creating. If set, we are updating.
  
  bool _isLoading = false;
  List<dynamic> _profiles = [];
  List<dynamic> _filteredProfiles = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }
  
  void _filterItems() {
    if (_searchQuery.isEmpty) {
      _filteredProfiles = _profiles;
    } else {
      _filteredProfiles = _profiles.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final biz = (p['business_name'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        return name.contains(q) || biz.contains(q);
      }).toList();
    }
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _apiService.fetchItems('founder');
      setState(() {
        _profiles = items;
        _filterItems();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        if (!kIsWeb) {
            _selectedImageFile = File(pickedFile.path); 
        }
      });
    }
  }

  void _startEditing(Map<String, dynamic> item) {
     setState(() {
       _editingId = item['id'].toString();
       _nameController.text = item['name'] ?? '';
       _businessController.text = item['business_name'] ?? '';
       _countryController.text = item['country'] ?? '';
       _bioController.text = item['bio'] ?? '';
       _isPremium = item['is_premium'] ?? false;
       _selectedImageBytes = null; // Reset image
     });
  }

  void _cancelEditing() {
    setState(() {
      _editingId = null;
      _clearForm();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validation: Image optional if editing
    if (_editingId == null && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a photo')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fields = {
        'name': _nameController.text,
        'business_name': _businessController.text,
        'country': _countryController.text,
        'bio': _bioController.text,
        'is_premium': _isPremium.toString(),
        'is_active': 'true',
      };

      // Prepare Image Object (File or Bytes)
      dynamic imageToUpload;
      if (_selectedImageBytes != null) {
          imageToUpload = kIsWeb ? _selectedImageBytes : _selectedImageFile;
      }

      if (_editingId != null) {
         // UPDATE
         await _apiService.updateFounderProfile(_editingId!, fields, imageToUpload);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Founder Profile Updated!')));
         _cancelEditing();
         _fetchItems();
      } else {
         // CREATE
         await _apiService.createFounderProfile(fields, imageToUpload);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Founder Profile Published!')));
         _clearForm();
         _fetchItems();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _clearForm() {
    _nameController.clear();
    _businessController.clear();
    _countryController.clear();
    _bioController.clear();
    setState(() { 
      _selectedImageBytes = null;
      _selectedImageFile = null;
    });
    // Do NOT reset editingId here, handled by cancelEditing/submit
  }

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    try {
      final newState = !(item['is_active'] ?? true);
      // We only update the 'is_active' field
      await _apiService.updateFounderProfile(item['id'].toString(), {
        'is_active': newState.toString(),
        // We must re-send required fields if the API is strict, but usually PATCH is partial.
        // If ModelSerializer is used with partial=True (PATCH), this works.
        // FounderProfile view usually supports partial update.
      }, null);
      
      _fetchItems();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newState ? "Spotlight Activated" : "Spotlight Deactivated")));
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update Failed: $e')));
    }
  }

  Future<void> _deleteItem(int id) async {
    // In a real app this would be a dialog
    // if (!confirm('Are you sure you want to delete this item?')) return; 
    
    try {
      await _apiService.deleteItem('founder', id);
       _fetchItems();
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Founder Spotlight")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildForm()),
                Expanded(flex: 3, child: _buildList()),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildForm(),
                  const Divider(height: 1),
                  _buildList(),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_editingId != null ? "Edit Founder Profile" : "Publish Founder Profile", 
                         style: Theme.of(context).textTheme.titleLarge),
                    if (_editingId != null)
                      TextButton.icon(
                        onPressed: _cancelEditing,
                        icon: const Icon(Icons.close),
                        label: const Text("Cancel"),
                      )
                  ],
                ),
                const SizedBox(height: 24),
                
                // Photo
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150, width: 150,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedImageBytes != null
                        ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                        : const Icon(Icons.person_add, size: 50, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                if (_editingId != null)
                   const Text("Tap to change photo (Optional)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 24),
                
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                 TextFormField(
                  controller: _businessController,
                  decoration: const InputDecoration(labelText: 'Business Name', border: OutlineInputBorder()),
                   validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                 TextFormField(
                  controller: _countryController,
                  decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                   validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                 TextFormField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
                   validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                 const SizedBox(height: 16),
                 SwitchListTile(
                   title: const Text("Is Premium Member?"),
                   value: _isPremium,
                   onChanged: (v) => setState(() => _isPremium = v),
                 ),
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FfigTheme.primaryBrown,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(_editingId != null ? "UPDATE PROFILE" : "PUBLISH PROFILE"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Past Spotlights", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          
          TextField(
             decoration: const InputDecoration(
               hintText: "Search Founders...",
               prefixIcon: Icon(Icons.search),
               border: OutlineInputBorder(),
               isDense: true,
             ),
             onChanged: (val) {
               setState(() {
                 _searchQuery = val;
                 _filterItems();
               });
             },
          ),
          const SizedBox(height: 16),

           if (_isLoading && _profiles.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredProfiles.length,
              itemBuilder: (context, index) {
                final item = _filteredProfiles[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: item['photo'] != null
                        ? CircleAvatar(backgroundImage: NetworkImage(item['photo']))
                        : const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(item['name'] ?? 'No Name'),
                    subtitle: Text("${item['business_name']} • ${item['country']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _startEditing(item),
                        ),
                        IconButton(
                          icon: Icon(item['is_active'] == true ? Icons.visibility : Icons.visibility_off, color: item['is_active'] == true ? Colors.green : Colors.grey),
                          onPressed: () => _toggleActive(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteItem(item['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );

  }
}
