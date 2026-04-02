import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/services/admin_api_service.dart';
import 'poll_form_screen.dart';

class ManagePollsScreen extends StatefulWidget {
  const ManagePollsScreen({super.key});

  @override
  State<ManagePollsScreen> createState() => _ManagePollsScreenState();
}

class _ManagePollsScreenState extends State<ManagePollsScreen> {
  final _api = AdminApiService();
  List<dynamic> _polls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPolls();
  }

  Future<void> _fetchPolls() async {
    try {
      final polls = await _api.fetchPollsAdmin();
      if (mounted) {
        setState(() {
          _polls = polls;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePoll(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Poll?"),
        content: const Text("This action cannot be undone and will remove all associated votes."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.deletePoll(id);
        _fetchPolls();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Poll deleted")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("MANAGE POLLS", style: GoogleFonts.lato(letterSpacing: 2, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const PollFormScreen()));
              _fetchPolls();
            },
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _polls.isEmpty
              ? const Center(child: Text("No polls created yet."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _polls.length,
                  itemBuilder: (context, index) {
                    final poll = _polls[index];
                    final expiry = DateTime.parse(poll['expires_at']);
                    final isExpired = expiry.isBefore(DateTime.now());

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(poll['question'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text("Expires: ${DateFormat('MMM d, h:mm a').format(expiry)}"),
                            if (isExpired) 
                              const Text("EXPIRED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (context) => PollFormScreen(poll: poll)));
                                _fetchPolls();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deletePoll(poll['id']),
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
