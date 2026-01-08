import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';
import 'edit_event_screen.dart';

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({super.key});

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  final _apiService = AdminApiService();
  bool _isLoading = true;
  List<dynamic> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    // We assume AdminApiService has a generic fetch or we add fetchEvents
    // For now we might need to add fetchEvents to AdminApiService or use generic
    try {
      // Temporary: Use a new method I'll add to AdminApiService or mock
      final data = await _apiService.fetchEvents(); 
      setState(() => _events = data);
    } catch (e) {
      // handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _editEvent(Map<String, dynamic>? event) async {
    await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => EditEventScreen(event: event))
    );
    _loadEvents();
  }

  Future<void> _deleteEvent(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Event?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.deleteEvent(id);
      _loadEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Events")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editEvent(null),
        child: const Icon(Icons.add),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final e = _events[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(e['image_url']),
                      onBackgroundImageError: (_, __) {},
                      child: e['image_url'].isEmpty ? const Icon(Icons.event) : null,
                    ),
                    title: Text(e['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${e['date']} • ${e['ticket_tiers']?.length ?? 0} Tiers\n${e['location']}"),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editEvent(e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteEvent(e['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
