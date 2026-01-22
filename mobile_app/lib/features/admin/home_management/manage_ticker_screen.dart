import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/utils/dialog_utils.dart';

class ManageTickerScreen extends StatefulWidget {
  const ManageTickerScreen({super.key});

  @override
  State<ManageTickerScreen> createState() => _ManageTickerScreenState();
}

class _ManageTickerScreenState extends State<ManageTickerScreen> {
  final _apiService = AdminApiService();
  final _formKey = GlobalKey<FormState>();

  final _textController = TextEditingController();
  final _urlController = TextEditingController();
  
  bool _isLoading = false;
  List<dynamic> _tickerItems = [];
  List<dynamic> _filteredTickerItems = [];

  String _searchQuery = "";
  int? _editingId;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _apiService.fetchItems('ticker');
      setState(() {
        _tickerItems = items;
        _filterItems();
      });
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _filterItems() {
    if (_searchQuery.isEmpty) {
      _filteredTickerItems = _tickerItems;
    } else {
      _filteredTickerItems = _tickerItems.where((i) => 
         (i['text'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
  }

  void _showEditor(Map<String, dynamic>? item) {
    if (item != null) {
      _editingId = item['id'];
      _textController.text = item['text'] ?? '';
      _urlController.text = item['url'] ?? '';
    } else {
      _editingId = null;
      _textController.clear();
      _urlController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                  _editingId != null ? "Edit News Item" : "Add News Item", 
                  style: Theme.of(context).textTheme.titleLarge
                ),
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _textController,
                  decoration: const InputDecoration(labelText: 'News Text', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: 'Link URL (Optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    if (_editingId != null) ...[
                      // Delete
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                           Navigator.pop(ctx);
                           _confirmDelete(item!['id']);
                        },
                      ),
                      const SizedBox(width: 8),
                      // Toggle Active
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
                        child: Text(_editingId != null ? "Save Changes" : "Create Item"),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      )
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Close sheet first
    Navigator.pop(context);
    
    setState(() => _isLoading = true);

    try {
      if (_editingId != null) {
        // UPDATE
        await _apiService.updateTickerItem(_editingId.toString(), {
           'text': _textController.text,
           'url': _urlController.text,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('News Item Updated!')));
      } else {
        // CREATE
        await _apiService.createTickerItem({
          'text': _textController.text,
          'url': _urlController.text,
          'is_active': true,
          'order': 0,
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('News Item Added!')));
      }
      
      _fetchItems();
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    setState(() => _isLoading = true);
    try {
      final newState = !(item['is_active'] ?? true);
      await _apiService.updateTickerItem(item['id'].toString(), {
         'is_active': newState,
      });
      _fetchItems();
    } catch (e) {
     if (mounted)  DialogUtils.showError(context, "Failed", e.toString());
      setState(() => _isLoading = false);
    }
  }
  
  void _confirmDelete(int id) {
      showDialog(
          context: context, 
          builder: (c) => AlertDialog(
              title: const Text("Delete Item?"),
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
      await _apiService.deleteItem('ticker', id);
       _fetchItems();
    } catch (e) {
       if (mounted) DialogUtils.showError(context, "Delete Failed", e.toString());
       setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage News Ticker")),
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
                                    hintText: "Search news...",
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
                    : _filteredTickerItems.isEmpty 
                        ? Center(child: Text("No items found. Add one above.", style: TextStyle(color: Colors.grey[600])))
                        : ListView.builder(
                              itemCount: _filteredTickerItems.length,
                              itemBuilder: (context, index) {
                                final item = _filteredTickerItems[index];
                                final isActive = item['is_active'] ?? true;
                                
                                return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        leading: CircleAvatar(
                                            backgroundColor: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                            child: Icon(Icons.newspaper, color: isActive ? Colors.green : Colors.grey),
                                        ),
                                        title: Text(
                                            item['text'] ?? '', 
                                            style: const TextStyle(fontWeight: FontWeight.bold)
                                        ),
                                        subtitle: item['url'] != null && item['url'].toString().isNotEmpty
                                            ? Text(item['url'], maxLines: 1, overflow: TextOverflow.ellipsis)
                                            : null,
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
