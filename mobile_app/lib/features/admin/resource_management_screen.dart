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

class _ResourceManagementScreenState extends State<ResourceManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storage = const FlutterSecureStorage();
  bool _isLoading = false;
  List<dynamic> _resources = [];

  // Mapping for API
  final Map<int, String> _tabToCategory = {
    0: 'MAG',   // Magazines
    1: 'CLASS', // Masterclass
    2: 'NEWS',  // Newsletter
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchResources();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _fetchResources();
    }
  }

  Future<void> _fetchResources() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final category = _tabToCategory[_tabController.index];
      
      final url = Uri.parse('${baseUrl}admin/resources/?category=$category');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        setState(() => _resources = json.decode(response.body));
      } else {
        _showError("Failed to load resources: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteResource(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).cardTheme.color,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Delete Resource", style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.displayMedium?.color)),
              const SizedBox(height: 16),
              Text("Are you sure you want to remove this resource permanently? This action cannot be undone.", 
                   textAlign: TextAlign.center,
                   style: GoogleFonts.lato(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                   Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                      child: Text("CANCEL", style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(vertical: 14),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         elevation: 0,
                      ),
                      child: Text("DELETE", style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.delete(
        Uri.parse('${baseUrl}admin/resources/$id/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 204) {
        _fetchResources(); // Refresh
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Resource deleted")));
      } else {
        _showError("Failed to delete");
      }
    } catch (e) {
      _showError("Error: $e");
    }
  }

  void _showResourceDialog({Map<String, dynamic>? resource}) {
    showDialog(
      context: context,
      builder: (context) => _ResourceEditorDialog(
        resource: resource,
        initialCategory: _tabToCategory[_tabController.index]!,
        onSave: _fetchResources,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("RESOURCES", style: FfigTheme.textTheme.displaySmall?.copyWith(fontSize: 20)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: FfigTheme.gold,
          unselectedLabelColor: Colors.grey,
          indicatorColor: FfigTheme.gold,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "MAGAZINES"),
            Tab(text: "MASTERCLASS"),
            Tab(text: "NEWSLETTERS"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: FfigTheme.gold))
          : _resources.isEmpty
              ? Center(child: Text("No resources found.", style: GoogleFonts.inter(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _resources.length,
                  itemBuilder: (context, index) {
                    final item = _resources[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      color: Theme.of(context).cardTheme.color,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            color: FfigTheme.paleGold.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            image: item['thumbnail_url'] != null && item['thumbnail_url'].toString().isNotEmpty
                                ? DecorationImage(image: NetworkImage(item['thumbnail_url']), fit: BoxFit.cover)
                                : null,
                          ),
                          child: item['thumbnail_url'] == null || item['thumbnail_url'].toString().isEmpty
                              ? const Icon(Icons.article, color: FfigTheme.gold)
                              : null,
                        ),
                        title: Text(item['title'], style: FfigTheme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                        subtitle: Text(item['description'] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey),
                              onPressed: () => _showResourceDialog(resource: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                              onPressed: () => _deleteResource(item['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: FfigTheme.matteBlack,
        onPressed: () => _showResourceDialog(),
        child: const Icon(Icons.add, color: FfigTheme.gold),
      ),
    );
  }
}

class _ResourceEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? resource;
  final String initialCategory;
  final VoidCallback onSave;

  const _ResourceEditorDialog({this.resource, required this.initialCategory, required this.onSave});

  @override
  State<_ResourceEditorDialog> createState() => _ResourceEditorDialogState();
}

class _ResourceEditorDialogState extends State<_ResourceEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _urlController;
  late TextEditingController _thumbController;
  late String _category;
  bool _isSaving = false;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.resource?['title'] ?? '');
    _descController = TextEditingController(text: widget.resource?['description'] ?? '');
    _urlController = TextEditingController(text: widget.resource?['url'] ?? '');
    _thumbController = TextEditingController(text: widget.resource?['thumbnail_url'] ?? '');
    _category = widget.resource?['category'] ?? widget.initialCategory;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final token = await _storage.read(key: 'access_token');
      final isEdit = widget.resource != null;
      final endpoint = isEdit
          ? '${baseUrl}admin/resources/${widget.resource!['id']}/'
          : '${baseUrl}admin/resources/';
      
      var urlInput = _urlController.text.trim();
      if (urlInput.isNotEmpty && !urlInput.startsWith('http')) {
        urlInput = 'https://$urlInput';
      }

      var thumbInput = _thumbController.text.trim();
      if (thumbInput.isNotEmpty && !thumbInput.startsWith('http')) {
        thumbInput = 'https://$thumbInput';
      }

      final body = json.encode({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'url': urlInput,
        'thumbnail_url': thumbInput.isEmpty ? null : thumbInput,
        'category': _category,
      });

      final response = isEdit
          ? await http.put(Uri.parse(endpoint), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: body)
          : await http.post(Uri.parse(endpoint), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        widget.onSave();
        Navigator.pop(context);
      } else {
        // Try to decode error message
        String errorMsg = "Error: ${response.statusCode}";
        try {
          final errorData = json.decode(response.body);
          errorMsg = "Error: $errorData";
          // If it's a map, make it cleaner
          if (errorData is Map) {
            final firstKey = errorData.keys.first;
            final firstVal = errorData[firstKey];
             errorMsg = "$firstKey: $firstVal";
          }
        } catch (_) {}
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Custom Premium Dialog
    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
       backgroundColor: Theme.of(context).cardTheme.color,
       elevation: 10,
       child: Container(
         padding: const EdgeInsets.all(24),
         constraints: const BoxConstraints(maxWidth: 400),
         child: SingleChildScrollView(
           child: Form(
             key: _formKey,
             child: Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: [
                 // Header
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Expanded(child: Text(widget.resource == null ? "New Resource" : "Edit Resource", 
                        style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.displayMedium?.color))
                     ),
                     IconButton(
                       icon: const Icon(Icons.close, color: Colors.grey), 
                       onPressed: () => Navigator.pop(context),
                       padding: EdgeInsets.zero,
                       constraints: const BoxConstraints(),
                     )
                   ],
                 ),
                 const SizedBox(height: 24),
                 
                 // Fields
                 _buildPremiumField(_titleController, "Title", Icons.title),
                 const SizedBox(height: 16),
                 _buildPremiumField(_descController, "Description", Icons.description, maxLines: 3),
                 const SizedBox(height: 16),
                 _buildPremiumField(_urlController, "Link / File URL", Icons.link),
                 const SizedBox(height: 16),
                 _buildPremiumField(_thumbController, "Thumbnail URL (Optional)", Icons.image, required: false),
                 const SizedBox(height: 16),
                 
                 DropdownButtonFormField<String>(
                   value: _category,
                   dropdownColor: Theme.of(context).cardTheme.color,
                   decoration: InputDecoration(
                     filled: true,
                     fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                     labelText: "Category",
                     labelStyle: GoogleFonts.lato(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
                     prefixIcon: Icon(Icons.category_outlined, color: FfigTheme.gold, size: 20),
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                   ),
                   items: const [
                     DropdownMenuItem(value: 'MAG', child: Text("Magazine")),
                     DropdownMenuItem(value: 'CLASS', child: Text("Masterclass")),
                     DropdownMenuItem(value: 'NEWS', child: Text("Newsletter")),
                   ],
                   onChanged: (v) => setState(() => _category = v!),
                 ),
                 
                 const SizedBox(height: 32),
                 
                 // Save Button
                 ElevatedButton(
                   onPressed: _isSaving ? null : _save,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Theme.of(context).colorScheme.primary,
                     foregroundColor: Theme.of(context).colorScheme.onPrimary,
                     padding: const EdgeInsets.symmetric(vertical: 16),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     elevation: 5,
                     shadowColor: Colors.black26,
                   ),
                   child: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: FfigTheme.gold))
                      : Text("SAVE RESOURCE", style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                 ),
               ],
             ),
           ),
         ),
       ),
    );
  }

  Widget _buildPremiumField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, bool required = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.lato(fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        labelText: label,
        labelStyle: GoogleFonts.lato(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey),
        prefixIcon: Icon(icon, color: FfigTheme.gold, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FfigTheme.gold, width: 1)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: required ? (v) => v!.isEmpty ? "Required" : null : null,
    );
  }
}
