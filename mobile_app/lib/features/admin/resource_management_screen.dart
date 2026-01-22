import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/constants.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/utils/dialog_utils.dart';

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
                      _editingId != null ? "Edit Resource" : "Add Resource", 
                      style: Theme.of(context).textTheme.titleLarge
                    ),
                    const SizedBox(height: 20),
                    
                    _buildField(_titleController, "Title", Icons.title),
                    const SizedBox(height: 16),
                    _buildField(_descController, "Description", Icons.description, maxLines: 3),
                    const SizedBox(height: 16),
                    _buildField(_urlController, "Content URL", Icons.link),
                    const SizedBox(height: 16),
                    _buildField(_thumbController, "Thumbnail URL", Icons.image, required: false),
                    const SizedBox(height: 16),
                    
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: 'access_token');
      
      var urlInput = _urlController.text.trim();
      if (urlInput.isNotEmpty && !urlInput.startsWith('http')) urlInput = 'https://$urlInput';

      var thumbInput = _thumbController.text.trim();
      if (thumbInput.isNotEmpty && !thumbInput.startsWith('http')) thumbInput = 'https://$thumbInput';

      final body = jsonEncode({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'url': urlInput,
        'thumbnail_url': thumbInput.isEmpty ? null : thumbInput,
        'category': _selectedCategory,
      });

      final uri = _editingId != null 
          ? Uri.parse('${baseUrl}admin/resources/$_editingId/')
          : Uri.parse('${baseUrl}admin/resources/');

      final response = _editingId != null
          ? await http.put(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: body)
          : await http.post(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_editingId != null ? 'Resource Updated' : 'Resource Created')));
        _fetchResources();
      } else {
        if (mounted) DialogUtils.showError(context, "Action Failed", response.body);
      }
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
