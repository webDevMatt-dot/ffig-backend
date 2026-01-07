import 'dart:typed_data';
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
  
  bool _isLoading = false;
  List<dynamic> _profiles = [];

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _apiService.fetchItems('founder');
      setState(() => _profiles = items);
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a photo')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _apiService.createFounderProfile({
        'name': _nameController.text,
        'business_name': _businessController.text,
        'country': _countryController.text,
        'bio': _bioController.text,
        'is_premium': _isPremium.toString(),
        'is_active': 'true',
      }, _selectedImageBytes);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Founder Profile Published!')));
      _clearForm();
      _fetchItems();
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
    setState(() => _selectedImageBytes = null);
  }

  Future<void> _deleteItem(int id) async {
    // Simple confirm
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
                        Text("Publish Founder Profile", style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 24),
                        
                        // Photo
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            height: 150, width: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _selectedImageBytes != null
                                ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                                : const Icon(Icons.person_add, size: 50, color: Colors.grey),
                          ),
                        ),
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
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("PUBLISH PROFILE"),
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
                  Text("Past Spotlights", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                   if (_isLoading && _profiles.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _profiles.length,
                        itemBuilder: (context, index) {
                          final item = _profiles[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              leading: item['photo'] != null
                                  ? CircleAvatar(backgroundImage: NetworkImage(item['photo']))
                                  : const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(item['name'] ?? 'No Name'),
                              subtitle: Text("${item['business_name']} • ${item['country']}"),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteItem(item['id']),
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
