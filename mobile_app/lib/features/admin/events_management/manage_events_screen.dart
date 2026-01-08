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
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final e = _events[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(e['image_url']),
                  ),
                  title: Text(e['title']),
                  subtitle: Text("${e['date']} • ${e['ticket_tiers']?.length ?? 0} Tiers"),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editEvent(e),
                  ),
                );
              },
            ),
    );
  }
}
