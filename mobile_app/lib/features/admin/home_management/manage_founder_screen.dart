import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/utils/dialog_utils.dart';

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
  dynamic _selectedImageBytes; 
  File? _selectedImageFile;
  String? _existingPhotoUrl; 
  String? _editingId; 

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
      if (mounted) DialogUtils.showError(context, "Load Failed", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(StateSetter setModalState) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setModalState(() {
        _selectedImageBytes = bytes;
        if (!kIsWeb) {
          _selectedImageFile = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _showUserPicker(StateSetter setModalState) async {
    await showDialog(
      context: context,
      builder: (context) => _UserPickerDialog(
        onUserSelected: (user) {
          setModalState(() {
            final String first = user['first_name'] ?? '';
            final String last = user['last_name'] ?? '';
            _nameController.text = first.isNotEmpty ? "$first $last".trim() : (user['username'] ?? '');

            if (user['business_name'] != null && user['business_name'].isNotEmpty) {
              _businessController.text = user['business_name'];
            } else {
              _businessController.text = user['industry_label'] ?? user['industry'] ?? '';
            }

            if (user['location'] != null) {
              _countryController.text = user['location'];
            }

            if (user['bio'] != null) {
              _bioController.text = user['bio'];
            }
            // Warning about image
          });
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Details populated. Please upload a high-res photo if needed.")),
          );
        },
      ),
    );
  }

  void _showEditor(Map<String, dynamic>? item) {
    if (item != null) {
      _editingId = item['id'].toString();
      _nameController.text = item['name'] ?? '';
      _businessController.text = item['business_name'] ?? '';
      _countryController.text = item['country'] ?? '';
      _bioController.text = item['bio'] ?? '';
      _isPremium = item['is_premium'] ?? false;
      _existingPhotoUrl = item['photo'];
      _selectedImageBytes = null;
    } else {
      _editingId = null;
      _nameController.clear();
      _businessController.clear();
      _countryController.clear();
      _bioController.clear();
      _isPremium = false;
      _existingPhotoUrl = null;
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
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text(
                              _editingId != null ? "Edit Founder" : "Add Founder", 
                              style: Theme.of(context).textTheme.titleLarge
                            ),
                            TextButton.icon(
                                onPressed: () => _showUserPicker(setModalState),
                                icon: const Icon(Icons.search),
                                label: const Text("Pick Existing User"),
                            )
                        ],
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
                              : (_existingPhotoUrl != null
                                    ? Image.network(_existingPhotoUrl!, fit: BoxFit.cover)
                                    : const Icon(Icons.person_add, size: 40, color: Colors.grey)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
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
                    
                    GestureDetector(
                      onTap: () {
                        showCountryPicker(
                          context: context,
                          showPhoneCode: false,
                          onSelect: (Country country) {
                            setModalState(() {
                              _countryController.text = country.name;
                            });
                          },
                        );
                      },
                      child: AbsorbPointer(
                        child: TextFormField(
                          controller: _countryController,
                          decoration: const InputDecoration(
                            labelText: 'Country',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    SwitchListTile(
                      title: const Text("Is Premium Member?"),
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
                            child: OutlinedButton.icon(
                              onPressed: () {
                                 Navigator.pop(ctx);
                                 _toggleActive(item!);
                              },
                              icon: Icon(
                                (item!['is_active'] ?? true) ? Icons.visibility_off : Icons.visibility,
                                color: (item['is_active'] ?? true) ? Colors.grey : Colors.green
                              ),
                              label: Text((item['is_active'] ?? true) ? "Deactivate" : "Activate"),
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
                            child: Text(_editingId != null ? "Save Changes" : "Create Founder"),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a photo')));
      return;
    }
    
    Navigator.pop(context);
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

      dynamic imageToUpload;
      if (_selectedImageBytes != null) {
        imageToUpload = kIsWeb ? _selectedImageBytes : _selectedImageFile;
      }

      if (_editingId != null) {
        await _apiService.updateFounderProfile(_editingId!, fields, imageToUpload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated!')));
      } else {
        await _apiService.createFounderProfile(fields, imageToUpload);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Created!')));
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
      await _apiService.updateFounderProfile(item['id'].toString(), {
        'is_active': newState.toString(),
      }, null);

      _fetchItems();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newState ? "Spotlight Activated" : "Spotlight Deactivated")),
      );
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Update Failed", e.toString());
      setState(() => _isLoading = false);
    }
  }
  
  void _confirmDelete(int id) {
      showDialog(
          context: context, 
          builder: (c) => AlertDialog(
              title: const Text("Delete Profile?"),
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
      await _apiService.deleteItem('founder', id);
       _fetchItems();
    } catch (e) {
       if (mounted) DialogUtils.showError(context, "Delete Failed", e.toString());
       setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Founder Spotlight")),
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
                                    hintText: "Search founders...",
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
                    : _filteredProfiles.isEmpty 
                        ? Center(child: Text("No items found. Add one above.", style: TextStyle(color: Colors.grey[600])))
                        : ListView.builder(
                              itemCount: _filteredProfiles.length,
                              itemBuilder: (context, index) {
                                final item = _filteredProfiles[index];
                                final isActive = item['is_active'] ?? true;
                                
                                return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        leading: CircleAvatar(
                                            backgroundImage: item['photo'] != null ? NetworkImage(item['photo']) : null,
                                            child: item['photo'] == null ? const Icon(Icons.person) : null,
                                        ),
                                        title: Text(
                                            item['name'] ?? 'No Name', 
                                            style: const TextStyle(fontWeight: FontWeight.bold)
                                        ),
                                        subtitle: Text(
                                          "${item['business_name']} • ${item['country']}",
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

class _UserPickerDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onUserSelected;
  const _UserPickerDialog({required this.onUserSelected});

  @override
  State<_UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<_UserPickerDialog> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;
  Timer? _debounce;
  final _api = AdminApiService();

  @override
  void initState() {
    super.initState();
    _search(''); 
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (mounted) setState(() => _loading = true);
      try {
        final results = await _api.searchUsers(query);
        if (mounted) setState(() => _results = results);
      } catch (e) {
        if (kDebugMode) print("User Search Error: $e");
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Select User"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: "Search by name or email...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? const Text("No users found", style: TextStyle(color: Colors.grey))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (context, index) {
                        final user = _results[index];
                        final name = user['username'] ?? 'Unknown';
                        final sub = user['email'] ?? '';
                        return ListTile(
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(sub),
                          onTap: () {
                            widget.onUserSelected(user);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
      ],
    );
  }
}
