import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _apiService.fetchItems('ticker');
      setState(() => _tickerItems = items);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _apiService.createTickerItem({
        'text': _textController.text,
        'url': _urlController.text,
        'is_active': true,
        'order': 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('News Item Added!')));
      _textController.clear();
      _urlController.clear();
      _fetchItems();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      await _apiService.deleteItem('ticker', id);
       _fetchItems();
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage News Ticker")),
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
                        Text("Add Ticker Item", style: Theme.of(context).textTheme.titleLarge),
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
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("ADD TO TICKER"),
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
                  Text("Current News", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  if (_isLoading && _tickerItems.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _tickerItems.length,
                        itemBuilder: (context, index) {
                          final item = _tickerItems[index];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              leading: const Icon(Icons.abc, size: 40),
                              title: Text(item['text'] ?? ''),
                              subtitle: item['url'] != null && item['url'].toString().isNotEmpty 
                                ? Text(item['url']) 
                                : null,
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
