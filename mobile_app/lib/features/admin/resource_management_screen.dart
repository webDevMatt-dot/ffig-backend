import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/constants.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/url_utils.dart';
import '../../core/services/admin_api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

/// Screen to manage VIP Resources (Magazines, Masterclasses, etc).
///
/// **Features:**
/// - List existing resources with search and filter.
/// - Add/Edit resources via a bottom sheet form.
/// - Toggle visibility (active/inactive) or delete resources.
class ResourceManagementScreen extends StatefulWidget {
  const ResourceManagementScreen({super.key});

  @override
  State<ResourceManagementScreen> createState() => _ResourceManagementScreenState();
}

class _ResourceManagementScreenState extends State<ResourceManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  
  // Model & State
  List<dynamic> _resources = [];
  List<dynamic> _filteredResources = [];
  String _searchQuery = "";
  bool _isLoading = false;
  
  // Form Fields
  String? _editingId;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _urlController = TextEditingController();
  final _thumbController = TextEditingController();
  String _selectedCategory = 'MAG'; // Default
  File? _selectedPdf;
  String? _pdfName;
  File? _selectedThumbnail;

  @override
  void initState() {
    super.initState();
    _fetchResources();
  }
  
  void _filterResources() {
    if (_searchQuery.isEmpty) {
      _filteredResources = _resources;
    } else {
      _filteredResources = _resources.where((r) {
        final title = (r['title'] ?? '').toString().toLowerCase();
        final cat = (r['category'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        return title.contains(q) || cat.contains(q);
      }).toList();
    }
  }

  /// Fetches resources from all categories.
  /// - Iterates through ['MAG', 'CLASS', 'NEWS', 'GEN'].
  /// - Aggregates results into `_resources`.
  Future<void> _fetchResources() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final cats = ['MAG', 'CLASS', 'NEWS', 'GEN'];
      List<dynamic> all = [];
      
      for (var cat in cats) {
         final res = await http.get(Uri.parse('${baseUrl}admin/resources/?category=$cat'), headers: {'Authorization': 'Bearer $token'});
         if (res.statusCode == 200) {
           all.addAll(jsonDecode(res.body));
         }
      }
      
      if (mounted) {
        setState(() {
          _resources = all;
          _filterResources();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditor(Map<String, dynamic>? item) {
    if (item != null) {
        _editingId = item['id'].toString();
        _titleController.text = item['title'] ?? '';
        _descController.text = item['description'] ?? '';
        _urlController.text = item['url'] ?? '';
        _thumbController.text = item['thumbnail_url'] ?? '';
        _selectedCategory = item['category'] ?? 'MAG';
    } else {
        _editingId = null;
        _titleController.clear();
        _descController.clear();
        _urlController.clear();
        _thumbController.clear();
        _selectedCategory = 'MAG';
    }
    _selectedPdf = null;
    _selectedThumbnail = null;
    _pdfName = item?['file'] != null ? item!['file'].toString().split('/').last : null;

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
                              _editingId != null ? "Edit Resource" : "Add Resource", 
                              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                    ),
                    const SizedBox(height: 24),
                    
                    // --- PREMIUM HEADER IMAGE PREVIEW ---
                    Builder(
                      builder: (context) {
                        final hasImage = _selectedThumbnail != null || _thumbController.text.isNotEmpty;
                        return GestureDetector(
                          onTap: () async {
                             FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                             if (result != null) setModalState(() => _selectedThumbnail = File(result.files.single.path!));
                          },
                          child: Container(
                            height: 180,
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _selectedThumbnail != null ? FfigTheme.accentBrown : Colors.white.withOpacity(0.1),
                                width: _selectedThumbnail != null ? 2 : 1,
                              ),
                              image: hasImage 
                                ? DecorationImage(
                                    image: _selectedThumbnail != null 
                                      ? FileImage(_selectedThumbnail!) as ImageProvider
                                      : NetworkImage(_thumbController.text), 
                                    fit: BoxFit.cover
                                  )
                                : null,
                            ),
                            child: !hasImage 
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.grey[600]),
                                      const SizedBox(height: 12),
                                      Text("Tap to Upload Thumbnail", style: GoogleFonts.inter(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                                      Text("(Recommended: 1200x800)", style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11)),
                                    ],
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  alignment: Alignment.bottomLeft,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: FfigTheme.accentBrown, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        _selectedThumbnail != null ? "New Image Selected" : "Current Thumbnail",
                                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.edit, color: Colors.white70, size: 18),
                                    ],
                                  ),
                                ),
                          ),
                        );
                      }
                    ),
                    
                    _buildField(_titleController, "Title", Icons.title),
                    const SizedBox(height: 16),
                    _buildField(_descController, "Description", Icons.description, maxLines: 3),
                    const SizedBox(height: 16),
                    _buildField(_urlController, "Content URL", Icons.link),
                    const SizedBox(height: 16),
                    _buildField(_thumbController, "Thumbnail URL (Override)", Icons.link_rounded, required: false),
                    const SizedBox(height: 16),
                    
                    const Text("CONTENT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    
                    // PDF Picker
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedPdf != null ? FfigTheme.accentBrown : Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedPdf != null 
                                    ? _selectedPdf!.path.split('/').last 
                                    : (_pdfName ?? "No PDF Selected"),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontWeight: (_selectedPdf != null || _pdfName != null) ? FontWeight.bold : FontWeight.normal,
                                    color: (_selectedPdf == null && _pdfName == null) ? Colors.grey : null,
                                  ),
                                ),
                                if (_selectedPdf != null || _pdfName != null)
                                  Text(
                                    _selectedPdf != null ? "New file ready to upload" : "Stored on server",
                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              FilePickerResult? result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf'],
                              );
                              if (result != null) {
                                setModalState(() => _selectedPdf = File(result.files.single.path!));
                              }
                            }, 
                            style: TextButton.styleFrom(
                              foregroundColor: FfigTheme.accentBrown,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            child: Text(_selectedPdf != null || _pdfName != null ? "CHANGE" : "PICK PDF")
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    const Text("DETAILS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    
                    if (_editingId != null) ...[
                        const Divider(),
                        const Text("Image Gallery", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (item?['images'] != null)
                           ...(item!['images'] as List).map((img) => ListTile(
                             leading: Image.network(img['image'], width: 40, height: 40, fit: BoxFit.cover),
                             title: Text(img['description'] ?? 'No description', maxLines: 1, overflow: TextOverflow.ellipsis),
                             trailing: IconButton(
                               icon: const Icon(Icons.delete_outline, color: Colors.red),
                               onPressed: () async {
                                 await AdminApiService().deleteResourceGalleryImage(img['id']);
                                 _fetchResources();
                                 Navigator.pop(ctx);
                               },
                             ),
                           )),
                        TextButton.icon(
                          onPressed: () => _showAddGalleryImageDialog(int.parse(_editingId!)), 
                          icon: const Icon(Icons.add_a_photo), 
                          label: const Text("ADD GALLERY IMAGE")
                        ),
                        const Divider(),
                    ],
                    
                    DropdownButtonFormField<String>(
                         initialValue: _selectedCategory,
                         decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                         items: const [
                           DropdownMenuItem(value: 'MAG', child: Text("Magazine")),
                           DropdownMenuItem(value: 'CLASS', child: Text("Masterclass")),
                           DropdownMenuItem(value: 'NEWS', child: Text("Newsletter")),
                           DropdownMenuItem(value: 'GEN', child: Text("General")),
                         ],
                         onChanged: (v) => setModalState(() => _selectedCategory = v!),
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
                                 _toggleResourceActive(item);
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
                            child: Text(_editingId != null ? "Save Changes" : "Publish"),
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

  /// Submits the add/edit form.
  /// - Validates input.
  /// - Determines if creating (POST) or updating (PUT).
  /// - Refreshes list on success.
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'url': normalizeUrl(_urlController.text),
        'thumbnail_url': _thumbController.text.trim().isEmpty ? null : normalizeUrl(_thumbController.text),
        'category': _selectedCategory,
      };

      if (_editingId != null) {
        await AdminApiService().updateAdminResource(int.parse(_editingId!), data, pdfFile: _selectedPdf, imageFile: _selectedThumbnail);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resource Updated')));
      } else {
        await AdminApiService().createAdminResource(data, pdfFile: _selectedPdf, imageFile: _selectedThumbnail);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resource Created')));
      }
      _fetchResources();
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddGalleryImageDialog(int resourceId) {
    final desc = TextEditingController();
    File? img;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: FfigTheme.primaryBrown.withOpacity(0.05),
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined, color: FfigTheme.accentBrown, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              "Add Gallery Image",
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: Column(
                          children: [
                            // Aesthetic Image Picker Area
                            GestureDetector(
                              onTap: () async {
                                FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
                                if (result != null) setDialogState(() => img = File(result.files.single.path!));
                              },
                              child: Container(
                                height: 180,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: img != null ? FfigTheme.accentBrown : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
                                    width: img != null ? 2 : 1.5,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: img != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.file(img!, fit: BoxFit.cover),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                                              ),
                                            ),
                                          ),
                                          const Center(
                                            child: CircleAvatar(
                                              backgroundColor: Colors.white24,
                                              child: Icon(Icons.auto_fix_high, color: Colors.white),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 12,
                                            left: 0,
                                            right: 0,
                                            child: Text(
                                              "Tap to Change Image",
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.cloud_upload_outlined, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                          const SizedBox(height: 12),
                                          Text(
                                            "Tap to select image",
                                            style: GoogleFonts.inter(
                                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            "Supports JPG, PNG, WEBP",
                                            style: GoogleFonts.inter(
                                              color: Colors.grey[500],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Description Field
                            TextField(
                              controller: desc,
                              style: GoogleFonts.inter(fontSize: 15),
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: "Description",
                                alignLabelWithHint: true,
                                hintText: "Enter a brief caption...",
                                prefixIcon: const Icon(Icons.short_text_rounded, size: 20),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0D1117) : Colors.white,
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Actions
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: Text(
                                      "CANCEL",
                                      style: GoogleFonts.inter(
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      if (img == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Please select an image first")),
                                        );
                                        return;
                                      }
                                      await AdminApiService().addResourceGalleryImage(resourceId, img!, description: desc.text);
                                      Navigator.pop(ctx);
                                      _fetchResources();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: FfigTheme.primaryBrown,
                                      foregroundColor: Colors.white,
                                      elevation: 8,
                                      shadowColor: FfigTheme.primaryBrown.withOpacity(0.5),
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: Text(
                                      "ADD TO GALLERY",
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleResourceActive(Map<String, dynamic> item) async {
    final id = item['id'];
    final isActive = item['is_active'] ?? true;
    final newState = !isActive;
    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: 'access_token');
      final uri = Uri.parse('${baseUrl}admin/resources/$id/');
      final response = await http.patch(uri, 
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'is_active': newState})
      );
      
      if (response.statusCode == 200) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newState ? "Resource Activated" : "Resource Deactivated")));
         _fetchResources();
      } else {
         throw Exception(response.body);
      }
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Toggle Failed", e.toString());
      setState(() => _isLoading = false);
    }
  }

  void _confirmDelete(int id) {
      showDialog(
          context: context, 
          builder: (c) => AlertDialog(
              title: const Text("Delete Resource?"),
              content: const Text("This action cannot be undone."),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
                  TextButton(
                      onPressed: () {
                          Navigator.pop(c);
                          _deleteResource(id);
                      }, 
                      child: const Text("Delete", style: TextStyle(color: Colors.red))
                  )
              ],
          )
      );
  }

  Future<void> _deleteResource(int id) async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'access_token');
      await http.delete(Uri.parse('${baseUrl}admin/resources/$id/'), headers: {'Authorization': 'Bearer $token'});
      _fetchResources();
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Delete Failed", e.toString());
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Resources")),
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
                                    hintText: "Search resources...",
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16)
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                    _filterResources();
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
                    : _filteredResources.isEmpty 
                        ? Center(child: Text("No resources found. Add one above.", style: TextStyle(color: Colors.grey[600])))
                        : ListView.builder(
                              itemCount: _filteredResources.length,
                              itemBuilder: (context, index) {
                                final item = _filteredResources[index];
                                final isActive = item['is_active'] ?? true;
                                return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: item['thumbnail_url'] != null 
                                            ? Image.network(item['thumbnail_url'], width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.broken_image))
                                            : Container(color: Colors.grey[200], width: 60, height: 60, child: const Icon(Icons.article)),
                                        ),
                                        title: Text(
                                            item['title'] ?? 'No Title', 
                                            style: const TextStyle(fontWeight: FontWeight.bold)
                                        ),
                                        subtitle: Text(item['category'] ?? ''),
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

  Widget _buildField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, bool required = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: required ? (v) => v!.isEmpty ? "Required" : null : null,
    );
  }
}
