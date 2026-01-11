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
      DialogUtils.showError(context, "Error", e.toString());
    } finally {
      setState(() => _isLoading = false);
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

  void _editItem(Map<String, dynamic> item) {
    setState(() {
      _editingId = item['id'];
      _textController.text = item['text'] ?? '';
      _urlController.text = item['url'] ?? '';
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _textController.clear();
      _urlController.clear();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_editingId != null) {
        // UPDATE
        await _apiService.updateTickerItem(_editingId.toString(), {
           'text': _textController.text,
           'url': _urlController.text,
           'is_active': true,
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('News Item Updated!')));
        _cancelEdit(); // Reset form
      } else {
        // CREATE
        await _apiService.createTickerItem({
          'text': _textController.text,
          'url': _urlController.text,
          'is_active': true,
          'order': 0,
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('News Item Added!')));
        _textController.clear();
        _urlController.clear();
      }
      
      _fetchItems();
    } catch (e) {
      DialogUtils.showError(context, "Error", e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    try {
      final newState = !(item['is_active'] ?? true);
      await _apiService.updateTickerItem(item['id'].toString(), {
         'is_active': newState,
      });
      _fetchItems();
    } catch (e) {
      DialogUtils.showError(context, "Failed", e.toString());
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      await _apiService.deleteItem('ticker', id);
       _fetchItems();
    } catch (e) {
       DialogUtils.showError(context, "Delete Failed", e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage News Ticker")),
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
                ],
              ),
            );
          }
        }
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
                    Text(_editingId != null ? "Edit Ticker Item" : "Add Ticker Item", style: Theme.of(context).textTheme.titleLarge),
                    if (_editingId != null)
                      TextButton(onPressed: _cancelEdit, child: const Text("Cancel"))
                  ],
                ),
                const SizedBox(height: 24),
                
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
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FfigTheme.primaryBrown,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_editingId != null ? "UPDATE" : "ADD TO TICKER"),
                  ),
                ),
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
          Text("Current News", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          
          // Search
          TextField(
             decoration: const InputDecoration(
               hintText: "Search News...",
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

          if (_isLoading && _tickerItems.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredTickerItems.length,
              itemBuilder: (context, index) {
                final item = _filteredTickerItems[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: const Icon(Icons.abc, size: 40),
                    title: Text(item['text'] ?? ''),
                    subtitle: item['url'] != null && item['url'].toString().isNotEmpty 
                      ? Text(item['url']) 
                      : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editItem(item),
                        ),
                         IconButton(
                          icon: Icon(Icons.power_settings_new, color: (item['is_active'] ?? true) ? Colors.green : Colors.grey),
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
