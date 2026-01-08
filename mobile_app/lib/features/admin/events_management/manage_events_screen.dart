import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/theme/ffig_theme.dart';
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
  
  // Quick Edit Form
  final _formKey = GlobalKey<FormState>();
  String? _editingId;
  final _titleController = TextEditingController();
  final _locController = TextEditingController();
  final _dateController = TextEditingController(); // Simple string for now
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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

  void _startEditing(Map<String, dynamic> e) {
    setState(() {
      _editingId = e['id'].toString();
      _titleController.text = e['title'] ?? '';
      _locController.text = e['location'] ?? '';
      _dateController.text = e['date'] ?? '';
      _imgController.text = e['image_url'] ?? '';
    });
  }
  
  void _cancelEditing() {
    setState(() {
      _editingId = null;
      _titleController.clear();
      _locController.clear();
      _dateController.clear();
      _imgController.clear();
    });
  }
  
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
       final data = {
         'title': _titleController.text,
         'location': _locController.text,
         'date': _dateController.text, // Backend expects YYYY-MM-DD usually
         'image_url': _imgController.text.isNotEmpty ? _imgController.text : "https://images.unsplash.com/photo-1542744173-8e7e53415bb0"
       };
       
       if (_editingId != null) {
         await _apiService.updateEvent(int.parse(_editingId!), data);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event Updated')));
       } else {
         await _apiService.createEvent(data);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event Created')));
       }
       _cancelEditing();
       _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action Failed: $e")));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEvent(int id) async {
     // Legacy Delete (Hidden or Administrative only if absolutely needed)
     // For now, we prefer Deactivation.
     await _apiService.deleteEvent(id);
     _loadEvents();
  }
  
  Future<void> _toggleEventActive(Map<String, dynamic> event) async {
    final id = event['id'];
    final isActive = event['is_active'] ?? true;
    final newState = !isActive;
    
    try {
      await _apiService.updateEvent(id, {'is_active': newState});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newState ? "Event Activated" : "Event Deactivated")));
      _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to toggle: $e")));
    }
  }
  
  void _manageFullDetails(Map<String, dynamic> event) async {
    await Navigator.push(context, MaterialPageRoute(builder: (c) => EditEventScreen(event: event)));
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Events")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildForm(context))),
                Expanded(flex: 3, child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildList(context))),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: Column(
                children: [
                  Padding(padding: const EdgeInsets.all(16), child: _buildForm(context)),
                  Divider(height: 1, thickness: 8, color: Theme.of(context).dividerColor),
                  Padding(padding: const EdgeInsets.all(16), child: _buildList(context)),
                ],
              ),
            );
          }
        },
      ),
    );
  }
  
  Widget _buildForm(BuildContext context) {
    return Card(
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
                   Text(_editingId != null ? "Edit Event" : "New Event", style: Theme.of(context).textTheme.titleLarge),
                   if (_editingId != null) TextButton(onPressed: _cancelEditing, child: const Text("Cancel"))
                ],
              ),
              const SizedBox(height: 24),
              _buildField(_titleController, "Event Title", Icons.event),
              const SizedBox(height: 16),
              _buildField(_locController, "Location", Icons.location_on),
              const SizedBox(height: 16),
              _buildField(_dateController, "Date (YYYY-MM-DD)", Icons.calendar_today),
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
                         // Find the event object
                         final e = _events.firstWhere((element) => element['id'].toString() == _editingId);
                         _manageFullDetails(e);
                      },
                      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                   ),
                 ),

              SizedBox(
                 width: double.infinity,
                 height: 50,
                 child: ElevatedButton(
                   onPressed: _isLoading ? null : _submitForm,
                   style: ElevatedButton.styleFrom(backgroundColor: FfigTheme.primaryBrown, foregroundColor: Colors.white),
                   child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_editingId != null ? "SAVE CHANGES" : "CREATE EVENT"),
                 ),
              )
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildList(BuildContext context) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
          Text("Upcoming Events", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
             decoration: const InputDecoration(hintText: "Search Events...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
             onChanged: (v) { setState(() { _searchQuery = v; _filterEvents(); }); },
          ),
          const SizedBox(height: 16),
           if (_isLoading && _events.isEmpty)
             const Center(child: CircularProgressIndicator())
           else
             ListView.builder(
               shrinkWrap: true,
               physics: const NeverScrollableScrollPhysics(),
               itemCount: _filteredEvents.length,
               itemBuilder: (context, index) {
                 final e = _filteredEvents[index];
                 return Card(
                   margin: const EdgeInsets.only(bottom: 12),
                   child: ListTile(
                     leading: CircleAvatar(backgroundImage: NetworkImage(e['image_url'] ?? ''), child: e['image_url'] == null ? const Icon(Icons.event) : null),
                     title: Text(e['title']),
                     subtitle: Text("${e['date']} • ${e['location']}"),
                     trailing: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _startEditing(e)),
                          // Power Toggle Logic
                          IconButton(
                             icon: Icon(Icons.power_settings_new, color: (e['is_active'] ?? true) ? Colors.green : Colors.grey),
                             onPressed: () => _toggleEventActive(e),
                           ),
                           IconButton(
                             icon: const Icon(Icons.delete, color: Colors.red),
                             onPressed: () => _deleteEvent(e['id']),
                           ),
                       ],
                     ),
                     onTap: () => _startEditing(e), 
                   ),
                 );
               },
             )
       ],
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
