import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/utils/dialog_utils.dart';
import 'edit_event_screen.dart';

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({super.key});

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  final _apiService = AdminApiService();
  
  bool _isLoading = false;
  List<dynamic> _events = [];
  List<dynamic> _filteredEvents = [];
  String _searchQuery = "";
  
  // Quick Edit Form Controllers
  final _formKey = GlobalKey<FormState>();
  String? _editingId;
  final _titleController = TextEditingController();
  final _locController = TextEditingController();
  final _dateController = TextEditingController(); 
  final _imgController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.fetchEvents(); 
      setState(() {
         _events = data; 
         _filterEvents();
      });
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _filterEvents() {
    if (_searchQuery.isEmpty) {
      _filteredEvents = _events;
    } else {
      _filteredEvents = _events.where((e) {
        final t = e['title'].toString().toLowerCase();
        final l = e['location'].toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        return t.contains(q) || l.contains(q);
      }).toList();
    }
  }

  void _showEditor(Map<String, dynamic>? event) {
    if (event != null) {
      _editingId = event['id'].toString();
      _titleController.text = event['title'] ?? '';
      _locController.text = event['location'] ?? '';
      final rawDate = event['date'] ?? '';
      if (rawDate.isNotEmpty) {
          try {
             final dt = DateTime.parse(rawDate);
             _dateController.text = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
          } catch (_) {
             _dateController.text = rawDate;
          }
      } else {
         _dateController.text = '';
      }
      _imgController.text = event['image_url'] ?? '';
    } else {
      _editingId = null;
      _titleController.clear();
      _locController.clear();
      _dateController.clear();
      _imgController.clear();
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
                      _editingId != null ? "Edit Event" : "Create New Event", 
                      style: Theme.of(context).textTheme.titleLarge
                    ),
                    const SizedBox(height: 20),
                    
                    _buildField(_titleController, "Event Title", Icons.event),
                    const SizedBox(height: 16),
                    _buildField(_locController, "Location", Icons.location_on),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: "Date",
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        onTap: () async {
                           DateTime? picked = await showDatePicker(
                             context: context,
                             initialDate: DateTime.now(),
                             firstDate: DateTime(2000),
                             lastDate: DateTime(2100),
                           );
                             if (picked != null) {
                               setModalState(() {
                                 _dateController.text = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
                               });
                             }
                        },
                        validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(_imgController, "Image URL", Icons.image, required: false),
                    const SizedBox(height: 24),
                    
                    if (_editingId != null)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: OutlinedButton.icon(
                                icon: const Icon(Icons.confirmation_number),
                                label: const Text("MANAGE TICKETS & SPEAKERS"),
                                onPressed: () {
                                    // Navigate to detailed edit screen
                                    Navigator.pop(ctx);
                                    _manageFullDetails(event!);
                                },
                                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                            ),
                        ),

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
                                 _toggleEventActive(event!);
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Icon(
                                (event!['is_active'] ?? true) ? Icons.visibility_off : Icons.visibility,
                                color: (event['is_active'] ?? true) ? Colors.grey : Colors.green
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
                            child: Text(_editingId != null ? "Save Changes" : "Create Event"),
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
        final data = {
         'title': _titleController.text,
         'location': _locController.text,
         'date': () {
             final parts = _dateController.text.split('-');
             if (parts.length == 3) {
                 return "${parts[2]}-${parts[1]}-${parts[0]}";
             }
             return _dateController.text;
         }(),
         'image_url': _imgController.text.isNotEmpty ? _imgController.text : "https://images.unsplash.com/photo-1542744173-8e7e53415bb0"
       };
       
       if (_editingId != null) {
         await _apiService.updateEvent(int.parse(_editingId!), data);
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event Updated')));
       } else {
         await _apiService.createEvent(data);
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event Created')));
       }
       _loadEvents();
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Failed", e.toString());
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleEventActive(Map<String, dynamic> event) async {
    final id = event['id'];
    final isActive = event['is_active'] ?? true;
    final newState = !isActive;
    setState(() => _isLoading = true);
    
    try {
      await _apiService.updateEvent(id, {'is_active': newState});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newState ? "Event Activated" : "Event Deactivated")));
      _loadEvents();
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Failed", e.toString());
       setState(() => _isLoading = false);
    }
  }

  void _manageFullDetails(Map<String, dynamic> event) async {
    await Navigator.push(context, MaterialPageRoute(builder: (c) => EditEventScreen(event: event)));
    _loadEvents();
  }
  
  void _confirmDelete(int id) {
      showDialog(
          context: context, 
          builder: (c) => AlertDialog(
              title: const Text("Delete Event?"),
              content: const Text("This action cannot be undone."),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
                  TextButton(
                      onPressed: () {
                          Navigator.pop(c);
                          _deleteEvent(id);
                      }, 
                      child: const Text("Delete", style: TextStyle(color: Colors.red))
                  )
              ],
          )
      );
  }

  Future<void> _deleteEvent(int id) async {
    setState(() => _isLoading = true);
     try {
       await _apiService.deleteEvent(id);
       _loadEvents();
     } catch (e) {
        if (mounted) DialogUtils.showError(context, "Delete Failed", e.toString());
        setState(() => _isLoading = false);
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Events")),
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
                                    hintText: "Search events...",
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16)
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                    _filterEvents();
                                  });
                                },
                            ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const EditEventScreen(event: null))),
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
                    : _filteredEvents.isEmpty 
                        ? Center(child: Text("No events found. Add one above.", style: TextStyle(color: Colors.grey[600])))
                        : ListView.builder(
                              itemCount: _filteredEvents.length,
                              itemBuilder: (context, index) {
                                final e = _filteredEvents[index];
                                final isActive = e['is_active'] ?? true;
                                final dateStr = e['date'];
                                DateTime? dt;
                                if (dateStr != null) {
                                  dt = DateTime.tryParse(dateStr);
                                }

                                return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                        contentPadding: const EdgeInsets.all(12),
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: e['image_url'] != null && e['image_url'].toString().isNotEmpty
                                            ? Image.network(e['image_url'], width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c,err,s) => const Icon(Icons.event, size: 40))
                                            : Container(
                                                color: Theme.of(context).brightness == Brightness.dark 
                                                    ? Colors.grey[800] 
                                                    : Colors.grey[200],
                                                width: 60, height: 60, 
                                                child: const Icon(Icons.event)
                                              ),
                                        ),
                                        title: Text(
                                            e['title'] ?? 'No Title', 
                                            style: const TextStyle(fontWeight: FontWeight.bold)
                                        ),
                                        subtitle: Text(
                                          dt != null 
                                            ? "${dt.day}/${dt.month}/${dt.year} • ${e['location']}"
                                            : e['location'] ?? ''
                                        ),
                                        trailing: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                        onTap: () => _showEditor(e),
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

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool required = true}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
      validator: required ? (v) => v!.isEmpty ? "Required" : null : null,
    );
  }
}
