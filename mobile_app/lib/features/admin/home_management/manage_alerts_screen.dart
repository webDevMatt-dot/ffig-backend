import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/dialog_utils.dart';

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
      if (mounted) DialogUtils.showError(context, "Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateTime(BuildContext context, StateSetter setModalState) async {
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
        setModalState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
        });
        // Also update parent state to persist if re-rendering
        setState(() {
           _selectedDate = pickedDate;
           _selectedTime = pickedTime;
        });
      }
    }
  }

  void _showEditor(Map<String, dynamic>? item) {
    if (item != null) {
      _editingId = item['id'].toString();
      _titleController.text = item['title'] ?? '';
      _messageController.text = item['message'] ?? '';
      _urlController.text = item['action_url'] ?? '';
      _selectedType = item['type'] ?? 'Alert';
      try {
        final expiry = DateTime.parse(item['expiry_time']);
        _selectedDate = expiry;
        _selectedTime = TimeOfDay.fromDateTime(expiry);
      } catch (_) {}
    } else {
      _editingId = null;
      _titleController.clear();
      _messageController.clear();
      _urlController.clear();
      _selectedType = 'Alert';
      _selectedDate = DateTime.now().add(const Duration(days: 1));
      _selectedTime = const TimeOfDay(hour: 12, minute: 0);
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
                      _editingId != null ? "Edit Alert" : "Create New Alert", 
                      style: Theme.of(context).textTheme.titleLarge
                    ),
                    const SizedBox(height: 20),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                      items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setModalState(() => _selectedType = v!),
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
                      subtitle: Text(DateFormat('dd-MM-yyyy HH:mm').format(
                         DateTime(
                            _selectedDate.year, _selectedDate.month, _selectedDate.day, 
                            _selectedTime.hour, _selectedTime.minute
                         )
                      )),
                      trailing: const Icon(Icons.calendar_today),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: Colors.grey)),
                      onTap: () => _selectDateTime(context, setModalState),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(labelText: 'Action URL (Optional)', border: OutlineInputBorder()),
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
                                 _toggleActive(item!);
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
                            child: Text(_editingId != null ? "UPDATE" : "PUBLISH"),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert Updated!')));
      } else {
        await _apiService.createFlashAlert(data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert Created!')));
      }
      _fetchItems();
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Failed", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    final id = item['id'];
    final isActive = item['is_active'] ?? true;
    final newState = !isActive;
    setState(() => _isLoading = true);
    
    try {
      await _apiService.updateFlashAlert(id.toString(), {'is_active': newState});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newState ? "Alert Activated" : "Alert Deactivated")));
      _fetchItems();
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Failed", e.toString());
      setState(() => _isLoading = false);
    }
  }

  void _confirmDelete(int id) {
      showDialog(
          context: context, 
          builder: (c) => AlertDialog(
              title: const Text("Delete Alert?"),
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
      await _apiService.deleteItem('alerts', id);
       _fetchItems();
    } catch (e) {
       if (mounted) DialogUtils.showError(context, "Delete Failed", e.toString());
       setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Flash Alerts")),
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
                                    hintText: "Search alerts...",
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
                    : _filteredAlerts.isEmpty 
                        ? Center(child: Text("No alerts found. Add one above.", style: TextStyle(color: Colors.grey[600])))
                        : ListView.builder(
                              itemCount: _filteredAlerts.length,
                              itemBuilder: (context, index) {
                                final item = _filteredAlerts[index];
                                final expiry = DateTime.tryParse(item['expiry_time'] ?? '') ?? DateTime.now();
                                final isExpired = expiry.isBefore(DateTime.now());
                                final isActive = item['is_active'] ?? true;
                                
                                return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    color: (isExpired || !isActive) ? Theme.of(context).cardColor.withOpacity(0.6) : null,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        leading: CircleAvatar(
                                            backgroundColor: isActive && !isExpired ? Colors.amber.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                            child: Icon(Icons.notifications_active, color: isActive && !isExpired ? Colors.amber : Colors.grey),
                                        ),
                                        title: Text(
                                            item['title'] ?? 'No Title', 
                                            style: const TextStyle(fontWeight: FontWeight.bold)
                                        ),
                                        subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Text(item['message'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                                                Text(
                                                    "Expires: ${DateFormat('dd MMM HH:mm').format(expiry.toLocal())}", 
                                                    style: TextStyle(fontSize: 12, color: isExpired ? Colors.red : Colors.grey)
                                                ),
                                            ],
                                        ),
                                        isThreeLine: true,
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
