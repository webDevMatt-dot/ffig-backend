import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import 'package:intl/intl.dart';

class ManageAlertsScreen extends StatefulWidget {
  const ManageAlertsScreen({super.key});

  @override
  State<ManageAlertsScreen> createState() => _ManageAlertsScreenState();
}

class _ManageAlertsScreenState extends State<ManageAlertsScreen> {
  final _apiService = AdminApiService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _urlController = TextEditingController();
  
  String _selectedType = 'Alert';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 12, minute: 0);
  String? _editingId;
  
  bool _isLoading = false;
  List<dynamic> _alerts = [];
  List<dynamic> _filteredAlerts = [];
  String _searchQuery = "";

  final List<String> _types = [
    'Happening Soon',
    'Tickets Closing',
    'Flash Sale',
    'Alert',
  ];

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }
  
  void _filterItems() {
    if (_searchQuery.isEmpty) {
      _filteredAlerts = _alerts;
    } else {
      _filteredAlerts = _alerts.where((a) {
        final title = (a['title'] ?? '').toString().toLowerCase();
        final msg = (a['message'] ?? '').toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        return title.contains(q) || msg.contains(q);
      }).toList();
    }
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _apiService.fetchItems('alerts');
      setState(() {
        _alerts = items;
        _filterItems();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
        });
      }
    }
  }

  void _startEditing(Map<String, dynamic> item) {
    setState(() {
      _editingId = item['id'].toString();
      _titleController.text = item['title'] ?? '';
      _messageController.text = item['message'] ?? '';
      _urlController.text = item['action_url'] ?? '';
      _selectedType = item['type'] ?? 'Alert';
      // Parse expiry
      try {
        final expiry = DateTime.parse(item['expiry_time']);
        _selectedDate = expiry;
        _selectedTime = TimeOfDay.fromDateTime(expiry);
      } catch (_) {}
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingId = null;
      _titleController.clear();
      _messageController.clear();
      _urlController.clear();
      _selectedType = 'Alert';
      _selectedDate = DateTime.now().add(const Duration(days: 1));
      _selectedTime = const TimeOfDay(hour: 12, minute: 0);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // Combine Date and Time
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final data = {
      'title': _titleController.text,
      'message': _messageController.text,
      'action_url': _urlController.text,
      'type': _selectedType,
      'expiry_time': dateTime.toIso8601String(),
      'is_active': true,
    };

    try {
      if (_editingId != null) {
        await _apiService.updateFlashAlert(_editingId!, data);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert Updated!')));
        _cancelEditing();
      } else {
        await _apiService.createFlashAlert(data);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert Created!')));
        _titleController.clear();
        _messageController.clear();
        _urlController.clear();
      }
      _fetchItems();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      await _apiService.deleteItem('alerts', id);
       _fetchItems();
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Flash Alerts")),
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
                            Text(_editingId != null ? "Edit Alert" : "Create New Alert", style: Theme.of(context).textTheme.titleLarge),
                            if (_editingId != null)
                              TextButton(onPressed: _cancelEditing, child: const Text("Cancel"))
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                          items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (v) => setState(() => _selectedType = v!),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _messageController,
                          decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        ListTile(
                          title: const Text("Expiry Time"),
                          subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(
                             DateTime(
                                _selectedDate.year, _selectedDate.month, _selectedDate.day, 
                                _selectedTime.hour, _selectedTime.minute
                             )
                          )),
                          trailing: const Icon(Icons.calendar_today),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: Colors.grey)),
                          onTap: () => _selectDateTime(context),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _urlController,
                          decoration: const InputDecoration(labelText: 'Action URL', border: OutlineInputBorder()),
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
                            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_editingId != null ? "UPDATE ALERT" : "PUBLISH ALERT"),
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
                  Text("Active Alerts", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  
                  TextField(
                     decoration: const InputDecoration(
                       hintText: "Search Alerts...",
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

                  if (_isLoading && _alerts.isEmpty)
                    const Center(child: CircularProgressIndicator())
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredAlerts.length,
                        itemBuilder: (context, index) {
                          final item = _filteredAlerts[index];
                          // Check expiry
                          final expiry = DateTime.tryParse(item['expiry_time']) ?? DateTime.now();
                          final isExpired = expiry.isBefore(DateTime.now());
                          
                          // Dark mode friendly expired color
                          final expiredColor = Theme.of(context).brightness == Brightness.dark 
                              ? Colors.grey.withOpacity(0.2) 
                              : Colors.grey.shade200;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: isExpired ? expiredColor : null,
                            child: ListTile(
                              leading: Icon(Icons.notifications_active, color: isExpired ? Colors.grey : Colors.amber),
                              title: Text(item['title'] ?? 'No Title'),
                              subtitle: Text("${item['message']}\nExpires: ${DateFormat('MM/dd HH:mm').format(expiry.toLocal())}"),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _startEditing(item),
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
