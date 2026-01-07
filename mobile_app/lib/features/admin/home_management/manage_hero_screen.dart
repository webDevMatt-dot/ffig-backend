import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';

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
  Uint8List? _selectedImageBytes;
  
  String? _editingId; // If null, we are creating. If set, we are updating.
  
  bool _isLoading = false;
  List<dynamic> _heroItems = [];

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

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _apiService.fetchItems('hero');
      setState(() => _heroItems = items);
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
      });
    }
  }

  void _startEditing(Map<String, dynamic> item) {
     setState(() {
       _editingId = item['id'].toString();
       _titleController.text = item['title'] ?? '';
       _urlController.text = item['action_url'] ?? '';
       _selectedType = _types.contains(item['type']) ? item['type'] : _types.first;
       _selectedImageBytes = null; // Reset image (optional to update)
     });
  }

  void _cancelEditing() {
    setState(() {
      _editingId = null;
      _titleController.clear();
      _urlController.clear();
      _selectedImageBytes = null;
      _selectedType = _types.first;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validation: Image is required for CREATE, but optional for UPDATE
    if (_editingId == null && _selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fields = {
        'title': _titleController.text,
        'action_url': _urlController.text,
        'type': _selectedType,
        'is_active': 'true',
      };

      if (_editingId != null) {
         // UPDATE
         await _apiService.updateHeroItem(_editingId!, fields, _selectedImageBytes);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hero Item Updated!')));
         _cancelEditing();
      } else {
         // CREATE
         await _apiService.createHeroItem(fields, _selectedImageBytes); // Sending bytes for Web
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hero Item Added!')));
         _titleController.clear();
         _urlController.clear();
         setState(() => _selectedImageBytes = null);
      }
      
      _fetchItems(); // Refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Operation Failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(int id) async {
    // In a real app this would be a dialog
    if (!confirm('Are you sure you want to delete this item?')) return; 
    
    try {
      await _apiService.deleteItem('hero', id);
       _fetchItems();
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete Failed: $e')));
    }
  }
  
  bool confirm(String message) {
    return true; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Hero Carousel")),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Form
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
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
                            Text(_editingId != null ? "Edit Hero Item" : "Add New Hero Item", 
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
                        
                        // Image Picker
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _selectedImageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                      const SizedBox(height: 8),
                                      Text(_editingId != null ? "Click to change image (optional)" : "Click to upload image"),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                          items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setState(() => _selectedType = v!),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _urlController,
                          decoration: const InputDecoration(labelText: 'Action URL (Optional)', border: OutlineInputBorder()),
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
                                : Text(_editingId != null ? "UPDATE ITEM" : "PUBLISH ITEM"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Right: List
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Current Items", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  if (_isLoading && _heroItems.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _heroItems.length,
                        itemBuilder: (context, index) {
                          final item = _heroItems[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              leading: item['image'] != null
                                  ? Image.network(item['image'], width: 60, height: 60, fit: BoxFit.cover)
                                  : const Icon(Icons.image),
                              title: Text(item['title'] ?? 'No Title'),
                              subtitle: Text(item['type'] ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _startEditing(item),
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
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
