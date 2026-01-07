import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/constants.dart';
import '../../core/theme/ffig_theme.dart';

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
  String? _editingId;

  // Form Fields
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEditing(Map<String, dynamic> item) {
    setState(() {
      _editingId = item['id'].toString();
      _titleController.text = item['title'] ?? '';
      _descController.text = item['description'] ?? '';
      _urlController.text = item['url'] ?? '';
      _thumbController.text = item['thumbnail_url'] ?? '';
      _selectedCategory = item['category'] ?? 'MAG';
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingId = null;
      _titleController.clear();
      _descController.clear();
      _urlController.clear();
      _thumbController.clear();
      _selectedCategory = 'MAG';
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: 'access_token');
      
      var urlInput = _urlController.text.trim();
      if (urlInput.isNotEmpty && !urlInput.startsWith('http')) urlInput = 'https://\$urlInput';

      var thumbInput = _thumbController.text.trim();
      if (thumbInput.isNotEmpty && !thumbInput.startsWith('http')) thumbInput = 'https://\$thumbInput';

      final body = jsonEncode({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'url': urlInput,
        'thumbnail_url': thumbInput.isEmpty ? null : thumbInput,
        'category': _selectedCategory,
      });

      final uri = _editingId != null 
          ? Uri.parse('${baseUrl}admin/resources/\$_editingId/')
          : Uri.parse('${baseUrl}admin/resources/');

      final response = _editingId != null
          ? await http.put(uri, headers: {'Authorization': 'Bearer \$token', 'Content-Type': 'application/json'}, body: body)
          : await http.post(uri, headers: {'Authorization': 'Bearer \$token', 'Content-Type': 'application/json'}, body: body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_editingId != null ? 'Resource Updated' : 'Resource Created')));
        _cancelEditing();
        _fetchResources();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: \${response.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteResource(int id) async {
    try {
      final token = await _storage.read(key: 'access_token');
      await http.delete(Uri.parse('${baseUrl}admin/resources/\$id/'), headers: {'Authorization': 'Bearer \$token'});
      _fetchResources();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Resources")),
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
                            Text(_editingId != null ? "Edit Resource" : "Add Resource", style: Theme.of(context).textTheme.titleLarge),
                            if (_editingId != null)
                              TextButton(onPressed: _cancelEditing, child: const Text("Cancel"))
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        _buildField(_titleController, "Title", Icons.title),
                        const SizedBox(height: 16),
                        _buildField(_descController, "Description", Icons.description, maxLines: 3),
                        const SizedBox(height: 16),
                        _buildField(_urlController, "Content URL", Icons.link),
                        const SizedBox(height: 16),
                        _buildField(_thumbController, "Thumbnail URL", Icons.image, required: false),
                        const SizedBox(height: 16),
                        
                         DropdownButtonFormField<String>(
                           value: _selectedCategory,
                           decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                           items: const [
                             DropdownMenuItem(value: 'MAG', child: Text("Magazine")),
                             DropdownMenuItem(value: 'CLASS', child: Text("Masterclass")),
                             DropdownMenuItem(value: 'NEWS', child: Text("Newsletter")),
                             DropdownMenuItem(value: 'GEN', child: Text("General")),
                           ],
                           onChanged: (v) => setState(() => _selectedCategory = v!),
                         ),
                        
                        const SizedBox(height: 24),
                         SizedBox(
                           width: double.infinity,
                           height: 50,
                           child: ElevatedButton(
                             onPressed: _isLoading ? null : _submitForm,
                             style: ElevatedButton.styleFrom(backgroundColor: FfigTheme.primaryBrown, foregroundColor: Colors.white),
                             child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_editingId != null ? "UPDATE" : "PUBLISH"),
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
                  Text("Existing Resources", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  
                  TextField(
                     decoration: const InputDecoration(
                       hintText: "Search Resources...",
                       prefixIcon: Icon(Icons.search),
                       border: OutlineInputBorder(),
                       isDense: true,
                     ),
                     onChanged: (val) {
                       setState(() {
                         _searchQuery = val;
                         _filterResources();
                       });
                     },
                  ),
                  const SizedBox(height: 16),

                  if (_isLoading && _resources.isEmpty)
                     const Center(child: CircularProgressIndicator())
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredResources.length,
                        itemBuilder: (context, index) {
                          final item = _filteredResources[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: item['thumbnail_url'] != null 
                                  ? Image.network(item['thumbnail_url'], width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.broken_image))
                                  : const Icon(Icons.article),
                              title: Text(item['title']),
                              subtitle: Text(item['category'] ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _startEditing(item)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteResource(item['id'])),
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
