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
  dynamic _selectedImageBytes; // Can be Uint8List (Bytes) or String (URL)
  File? _selectedImageFile;
  String? _existingPhotoUrl; // Store existing URL for display
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
      DialogUtils.showError(context, "Load Failed", e.toString());
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
      _existingPhotoUrl = item['photo']; // Load existing photo
      _selectedImageBytes = null; // Reset new selection
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a photo')));
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
        await _apiService.updateFounderProfile(
          _editingId!,
          fields,
          imageToUpload,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Founder Profile Updated!')),
        );
        _cancelEditing();
        _fetchItems();
      } else {
        // CREATE
        await _apiService.createFounderProfile(fields, imageToUpload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Founder Profile Published!')),
        );
        _clearForm();
        _fetchItems();
      }
    } catch (e) {
      DialogUtils.showError(context, "Upload Failed", e.toString());
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
      _existingPhotoUrl = null;
    });
    // Do NOT reset editingId here, handled by cancelEditing/submit
  }

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    try {
      final newState = !(item['is_active'] ?? true);
      // We only update the 'is_active' field
      // NOTE: We pass null for image to avoid re-uploading or clearing it
      await _apiService.updateFounderProfile(item['id'].toString(), {
        'is_active': newState.toString(),
      }, null);

      _fetchItems();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState ? "Spotlight Activated" : "Spotlight Deactivated",
          ),
        ),
      );
    } catch (e) {
      DialogUtils.showError(context, "Update Failed", e.toString());
    }
  }

  Future<void> _showUserPicker() async {
    await showDialog(
      context: context,
      builder: (context) => _UserPickerDialog(
        onUserSelected: (user) {
          setState(() {
            // 1. Populate Name and Bio
            // If 'first_name'/'last_name' exist (MemberSerializer), use them.
            // Otherwise try 'username'.
            final String first = user['first_name'] ?? '';
            final String last = user['last_name'] ?? '';
            if (first.isNotEmpty) {
              _nameController.text = "$first $last".trim();
            } else {
              // Fallback
              _nameController.text = user['username'] ?? '';
            }

            // 2. Populate Business/Role
            // Priority: business_name > industry_label > industry
            if (user['business_name'] != null &&
                user['business_name'].isNotEmpty) {
              _businessController.text = user['business_name'];
            } else {
              _businessController.text =
                  user['industry_label'] ?? user['industry'] ?? '';
            }

            // 3. Populate Location
            if (user['location'] != null) {
              _countryController.text = user['location'];
            }

            // 4. Bio
            if (user['bio'] != null) {
              _bioController.text = user['bio'];
            }

            // 5. Image (Tricky: We have bytes and file, but this is a URL)
            // Ideally, the backend 'createFounderProfile' should accept a URL string too?
            // OR we download strictly for display?
            // Since 'createFounderProfile' expects Multipart, we can't easily send a URL unless we change backend.
            // Workaround: We can't pre-fill the *file* from a URL without downloading it.
            // For now, we WON'T set the image to avoid complexity, or we warn user.
            // Better: If we are just filling text, that's fine.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Details populated. Please upload a high-res photo if needed.",
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Future<void> _deleteItem(int id) async {
    // In a real app this would be a dialog
    // if (!confirm('Are you sure you want to delete this item?')) return;

    try {
      await _apiService.deleteItem('founder', id);
      _fetchItems();
    } catch (e) {
      DialogUtils.showError(context, "Delete Failed", e.toString());
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
                  const SizedBox(height: 100), // Safe scroll space
                ],
              ),
            );
          }
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: FfigTheme.primaryBrown,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _editingId != null ? "UPDATE PROFILE" : "PUBLISH PROFILE",
                    ),
            ),
          ),
        ),
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
                    Text(
                      _editingId != null
                          ? "Edit Founder Profile"
                          : "Publish Founder Profile",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_editingId != null)
                      TextButton.icon(
                        onPressed: _cancelEditing,
                        icon: const Icon(Icons.close),
                        label: const Text("Cancel"),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // Photo
                // Photo
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _selectedImageBytes != null
                              ? (_selectedImageBytes is Uint8List
                                    ? Image.memory(
                                        _selectedImageBytes as Uint8List,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
                                        _selectedImageBytes as String,
                                        fit: BoxFit.cover,
                                      )) // URL Support
                              : (_existingPhotoUrl != null
                                    ? Image.network(
                                        _existingPhotoUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(
                                        Icons.person_add,
                                        size: 40,
                                        color: Colors.grey,
                                      )),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // URL Input
                      SizedBox(
                        width: 200,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: "Or Image URL",
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link, size: 16),
                          ),
                          style: const TextStyle(fontSize: 12),
                          onChanged: (val) {
                            setState(() {
                              if (val.isNotEmpty) {
                                _selectedImageBytes =
                                    val as dynamic; // Store URL as dynamic
                                _selectedImageFile = null;
                              } else {
                                _selectedImageBytes = null;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showUserPicker,
                        icon: const Icon(Icons.search),
                        label: const Text("Pick Existing User"),
                        style: TextButton.styleFrom(
                          foregroundColor: FfigTheme.primaryBrown,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _businessController,
                  decoration: const InputDecoration(
                    labelText: 'Business Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                GestureDetector(
                  onTap: () {
                    showCountryPicker(
                      context: context,
                      showPhoneCode: false,
                      onSelect: (Country country) {
                        setState(() {
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
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text("Is Premium Member?"),
                  value: _isPremium,
                  onChanged: (v) => setState(() => _isPremium = v),
                ),
                const SizedBox(height: 24),

                // SizedBox(
                //   width: double.infinity,
                //   height: 50,
                //   child: ElevatedButton(
                //     onPressed: _isLoading ? null : _submitForm,
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: FfigTheme.primaryBrown,
                //       foregroundColor: Colors.white,
                //     ),
                //     child: _isLoading
                //         ? const CircularProgressIndicator(color: Colors.white)
                //         : Text(_editingId != null ? "UPDATE PROFILE" : "PUBLISH PROFILE"),
                //   ),
                // ),
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
          Text(
            "Past Spotlights",
            style: Theme.of(context).textTheme.titleLarge,
          ),
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
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(item['photo']),
                          )
                        : const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(item['name'] ?? 'No Name'),
                    subtitle: Text(
                      "${item['business_name']} • ${item['country']}",
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _startEditing(item),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.power_settings_new,
                            color: (item['is_active'] ?? true)
                                ? Colors.green
                                : Colors.grey,
                          ),
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
    _search(''); // Initial search
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
      if (query.isEmpty) {
        // Allow empty query to clear or reset?
        // If we want to show 'all users' when empty, we just search ''
      }
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
                  ? const Text(
                      "No users found",
                      style: TextStyle(color: Colors.grey),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (context, index) {
                        final user = _results[index];
                        final name = user['username'] ?? 'Unknown';
                        final sub = user['email'] ?? '';
                        return ListTile(
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
