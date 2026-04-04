import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../shared_widgets/user_avatar.dart';
import '../../home/models/founder_profile.dart';
import '../../home/widgets/founder_spotlight_card.dart';
import '../widgets/user_picker_dialog.dart';
import '../widgets/admin_dark_list_item.dart';

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
  String _tier = 'FREE'; // NEW
  dynamic _selectedImageBytes; 
  File? _selectedImageFile;
  String? _existingPhotoUrl; 
  String? _editingId; 
  int? _linkedUserId;

  bool _isLoading = false;
  List<dynamic> _profiles = [];
  List<dynamic> _filteredProfiles = [];
  String _searchQuery = "";
  Map<String, dynamic>? _initialData; // For Undo feature

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  void _filterItems() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredProfiles = List.from(_profiles);
    } else {
      final terms = query.split(' ').where((t) => t.isNotEmpty).toList();
      _filteredProfiles = _profiles.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final biz = (p['business_name'] ?? '').toString().toLowerCase();
        final country = (p['country'] ?? '').toString().toLowerCase();
        final bio = (p['bio'] ?? '').toString().toLowerCase();
        
        return terms.every((term) => 
          name.contains(term) || 
          biz.contains(term) || 
          country.contains(term) || 
          bio.contains(term)
        );
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
      if (mounted) DialogUtils.showError(context, "Load Failed", DialogUtils.getFriendlyMessage(e));
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
    final double screenWidth = MediaQuery.of(context).size.width;
    // Match exactly the dashboard's padding (24 on each side)
    final double cardWidth = screenWidth - 48; 
    final double cardHeight = 340.0; // Updated from 300 to match live card

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatio: CropAspectRatio(ratioX: cardWidth, ratioY: cardHeight),
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Founder Photo',
          toolbarColor: FfigTheme.primaryBrown,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Founder Photo',
          aspectRatioPickerButtonHidden: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (croppedFile != null) return File(croppedFile.path);
    return null;
  }

  Future<void> _cropExistingImage(StateSetter setModalState) async {
    // Determine the source
    dynamic source = _selectedImageBytes ?? _existingPhotoUrl;
    if (source == null) return;

    setState(() => _isLoading = true);
    try {
      File? imageFile;
      if (source is String && source.startsWith('http')) {
        // Download existing URL
        final response = await http.get(Uri.parse(source));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          imageFile = File('${tempDir.path}/temp_crop_image.jpg');
          await imageFile.writeAsBytes(response.bodyBytes);
        }
      } else if (source is Uint8List) {
        // Use existing bytes
        final tempDir = await getTemporaryDirectory();
        imageFile = File('${tempDir.path}/temp_crop_image.jpg');
        await imageFile.writeAsBytes(source);
      } else if (_selectedImageFile != null) {
        imageFile = _selectedImageFile;
      }

      if (imageFile != null) {
        final croppedFile = await _cropImage(imageFile);
        if (croppedFile != null) {
          final bytes = await croppedFile.readAsBytes();
          setModalState(() {
            _selectedImageBytes = bytes;
            _selectedImageFile = croppedFile;
          });
        }
      }
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Adjustment Failed", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _undoChanges(StateSetter setModalState) {
    setModalState(() {
      if (_initialData != null) {
        _nameController.text = _initialData!['name'] ?? '';
        _businessController.text = _initialData!['business_name'] ?? '';
        _countryController.text = _initialData!['country'] ?? '';
        _bioController.text = _initialData!['bio'] ?? '';
        _isPremium = _initialData!['is_premium'] ?? false;
        _tier = _initialData!['tier'] ?? 'FREE';
        _existingPhotoUrl = _initialData!['photo'];
        _selectedImageBytes = null;
        _selectedImageFile = null;
        _linkedUserId = _initialData!['user'] is int ? _initialData!['user'] : null;
      } else {
        _nameController.clear();
        _businessController.clear();
        _countryController.clear();
        _bioController.clear();
        _isPremium = false;
        _tier = 'FREE';
        _existingPhotoUrl = null;
        _selectedImageBytes = null;
        _selectedImageFile = null;
        _linkedUserId = null;
      }
    });
  }

  Future<void> _showUserPicker(StateSetter setModalState) async {
    await showDialog(
      context: context,
      builder: (context) => UserPickerDialog(
        onUserSelected: (user) {
          setModalState(() {
            _linkedUserId = user['user_id'] ?? user['id']; // user['id'] usually or user_id mapping
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
            
            _isPremium = user['is_premium'] ?? false;
            _tier = user['tier'] ?? 'FREE';
            
            String? photoUrl = user['photo_url'] ?? user['photo'];
            if (photoUrl != null && photoUrl.isNotEmpty && photoUrl != "null" && !photoUrl.contains("ui-avatars.com")) {
              _selectedImageBytes = photoUrl;
              _selectedImageFile = null;
            }
            
          });
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_selectedImageBytes != null ? "Details and photo populated!" : "Details populated. Please upload a high-res photo if needed.")),
          );
        },
      ),
    );
  }

  void _showEditor(Map<String, dynamic>? item) {
    _initialData = item; // Capture for undo
    
    if (item != null) {
      _editingId = item['id'].toString();
      _nameController.text = item['name'] ?? '';
      _businessController.text = item['business_name'] ?? '';
      _countryController.text = item['country'] ?? '';
      _bioController.text = item['bio'] ?? '';
      _isPremium = item['is_premium'] ?? false;
      _tier = item['tier'] ?? 'FREE';
      _existingPhotoUrl = item['photo_url'] ?? item['photo'];
      _editingId = item['id'].toString();
      _linkedUserId = item['user'] is int ? item['user'] : null;
      _selectedImageBytes = null;
      _selectedImageFile = null;
    } else {
      _editingId = null;
      _nameController.clear();
      _businessController.clear();
      _countryController.clear();
      _bioController.clear();
      _isPremium = false;
      _tier = 'FREE';
      _existingPhotoUrl = null;
      _selectedImageBytes = null;
      _selectedImageFile = null;
      _linkedUserId = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, 
              top: 10, left: 20, right: 20
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 20),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[400]!,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Flexible(
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
                                    Flexible(
                                      child: Row(
                                        children: [
                                          IconButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            icon: const Icon(Icons.close),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: "Close",
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _editingId != null ? "Edit Founder" : "Add Founder", 
                                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton.icon(
                                            onPressed: () => _showUserPicker(setModalState),
                                            icon: const Icon(Icons.search, size: 18),
                                            label: const Text("User", style: TextStyle(fontSize: 12)),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                            ),
                                        )
                                      ],
                                    )
                                ],
                            ),
                            const SizedBox(height: 20),
                            
                            // LIVE PREVIEW
                            const Text("LIVE PREVIEW", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                            const SizedBox(height: 12),
                            FounderSpotlightCard(
                              isPreview: true,
                              localImageBytes: _selectedImageBytes is Uint8List ? _selectedImageBytes as Uint8List : null,
                              profile: FounderProfile(
                                id: _editingId ?? 'preview',
                                name: _nameController.text,
                                businessName: _businessController.text,
                                bio: _bioController.text,
                                country: _countryController.text,
                                photoUrl: _existingPhotoUrl ?? '',
                                isPremium: _isPremium,
                                tier: _tier,
                                userId: _linkedUserId,
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            Text("DETAILS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                            const SizedBox(height: 16),
                            
                            // Photo
                            Center(
                              child: GestureDetector(
                                onTap: () async {
                                  if (_selectedImageBytes != null || _existingPhotoUrl != null) {
                                    // Show options
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (c) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(Icons.photo_library),
                                              title: const Text("Select New Photo"),
                                              onTap: () {
                                                Navigator.pop(c);
                                                _pickImage(setModalState);
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.crop_rotate),
                                              title: const Text("Adjust Current Photo"),
                                              onTap: () {
                                                Navigator.pop(c);
                                                _cropExistingImage(setModalState);
                                              },
                                            ),
                                            if (_selectedImageBytes is Uint8List || (_selectedImageBytes != null && _initialData != null && _selectedImageBytes != _initialData!['photo']))
                                              ListTile(
                                                leading: const Icon(Icons.history),
                                                title: const Text("Reset to Original Photo"),
                                                onTap: () {
                                                  Navigator.pop(c);
                                                  setModalState(() {
                                                    if (_initialData != null && _initialData!['photo'] != null) {
                                                      _selectedImageBytes = _initialData!['photo'];
                                                    } else {
                                                      _selectedImageBytes = null;
                                                    }
                                                    _selectedImageFile = null;
                                                  });
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  } else {
                                    _pickImage(setModalState);
                                  }
                                },
                                child: Stack(
                                  children: [
                                    Container(
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
                                                : Image.network(_selectedImageBytes as String, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildImageError()))
                                          : (_existingPhotoUrl != null
                                                ? Image.network(_existingPhotoUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildImageError())
                                                : const Icon(Icons.person_add, size: 40, color: Colors.grey)),
                                    ),
                                    if (_selectedImageBytes != null || _existingPhotoUrl != null)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: FfigTheme.primaryBrown,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.crop, size: 16, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                              onChanged: (v) => setModalState(() {}),
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _businessController,
                              decoration: const InputDecoration(labelText: 'Business Name', border: OutlineInputBorder()),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                              onChanged: (v) => setModalState(() {}),
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
                              onChanged: (v) => setModalState(() {}),
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
                                    child: Text(_editingId != null ? "Save Changes" : "Create Founder"),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      )
    );
  }
  
  Widget _buildImageError() {
    return Container(
      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey.shade300,
      alignment: Alignment.center,
      child: const Icon(Icons.person, size: 40, color: Colors.grey),
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
        'tier': _tier,
        'is_active': _editingId != null ? 'true' : 'false', // NEW: Default to Draft for new creations
      };
      
      if (_linkedUserId != null) {
        fields['user'] = _linkedUserId.toString();
      }

      dynamic imageToUpload;
      if (_selectedImageBytes is String && _selectedImageBytes.toString().startsWith('http')) {
        // IF CREATING NEW: We MUST download the URL to bytes because POST requires a file.
        // IF EDITING: We can keep it as a string, and AdminApiService will skip it (preserving existing).
        if (_editingId == null) {
          try {
            final response = await http.get(Uri.parse(_selectedImageBytes));
            if (response.statusCode == 200) {
              imageToUpload = response.bodyBytes;
            }
          } catch (e) {
            print("Failed to auto-download profile photo: $e");
            // Fallback to null, API might fail with "photo required" but better than "not a file"
          }
        } else {
          imageToUpload = _selectedImageBytes;
        }
      } else if (_selectedImageBytes != null) {
        imageToUpload = kIsWeb ? _selectedImageBytes : (_selectedImageFile ?? _selectedImageBytes);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newState ? "Spotlight Activated" : "Spotlight Deactivated")),
      );
      }
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Update Failed", DialogUtils.getFriendlyMessage(e));
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
    final now = DateTime.now();
    _filteredProfiles.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
      final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
      return bDate.compareTo(aDate);
    });

    // --- SUMMARY COUNTS ---
    int liveCount = 0;
    int draftCount = 0;
    int expiredCount = 0;

    for (var p in _profiles) {
      final active = p['is_active'] ?? false;
      final expires = p['expires_at'] != null ? DateTime.tryParse(p['expires_at']) : null;
      if (active) {
        if (expires != null && expires.isBefore(now)) expiredCount++; else liveCount++;
      } else draftCount++;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Founder Spotlight"),
        actions: [
          IconButton(
            onPressed: () => _showEditor(null),
            icon: const Icon(Icons.add, size: 34),
            tooltip: "Add Founder Spotlight",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // --- HEADER SUMMARY ---
                Row(
                  children: [
                    _buildSummaryStat("LIVE", liveCount.toString(), Colors.green),
                    const SizedBox(width: 12),
                    _buildSummaryStat("DRAFT", draftCount.toString(), Colors.grey),
                    const SizedBox(width: 12),
                    _buildSummaryStat("EXPIRED", expiredCount.toString(), Colors.red),
                  ],
                ),
                const SizedBox(height: 24),

                // --- SEARCH ---
                TextField(
                    controller: TextEditingController.fromValue(
                      TextEditingValue(
                        text: _searchQuery,
                        selection: TextSelection.collapsed(offset: _searchQuery.length),
                      ),
                    ),
                    decoration: InputDecoration(
                        hintText: "Search founders...",
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
                
                const SizedBox(height: 24),
                
                // --- LIST ---
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator()) 
                    : _filteredProfiles.isEmpty 
                        ? Center(child: Text("No items found. Add one above.", style: TextStyle(color: Colors.grey[600])))
                        : ListView.builder(
                              itemCount: _filteredProfiles.length,
                              itemBuilder: (context, index) {
                                  final item = _filteredProfiles[index];
                                  final isActive = item['is_active'] ?? false;
                                  final expiresAtStr = item['expires_at'];
                                  final expiresAt = expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;
                                  final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
                                  
                                  String statusText = "DRAFT";
                                  Color statusColor = Colors.grey;
                                  
                                  if (isActive) {
                                    if (isExpired) {
                                      statusText = "EXPIRED";
                                      statusColor = Colors.red;
                                    } else {
                                      statusText = "LIVE";
                                      statusColor = Colors.green;
                                    }
                                  }

                                  return AdminDarkListItem(
                                    title: item['name'] ?? 'No Name',
                                    subtitle: "${item['business_name'] ?? ''} • ${item['country'] ?? ''}",
                                    imageUrl: item['photo'],
                                    fallbackIcon: Icons.person_outline,
                                    onTap: () => _showEditor(item),
                                    statusChip: _statusChip(statusText, statusColor),
                                    trailing: !isActive ? OutlinedButton(
                                      onPressed: () => _toggleActive(item),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green,
                                        side: const BorderSide(color: Colors.green),
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                      child: const Text("GO LIVE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                                    ) : null,
                                  );
                                },
                        ),
                ),
            ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}
