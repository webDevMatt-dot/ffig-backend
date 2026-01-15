import 'package:flutter/material.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/api/constants.dart';

class AdminApprovalsScreen extends StatelessWidget {
  const AdminApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Approvals Center"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Business Profiles"),
              Tab(text: "Marketing Requests"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BusinessApprovalsList(),
            _MarketingApprovalsList(),
          ],
        ),
      ),
    );
  }
}

class _BusinessApprovalsList extends StatefulWidget {
    const _BusinessApprovalsList();
    @override
    State<_BusinessApprovalsList> createState() => _BusinessApprovalsListState();
}

class _BusinessApprovalsListState extends State<_BusinessApprovalsList> {
    final _api = AdminApiService(); // Ensure this is imported via admin_api_service.dart
    List<dynamic> _items = [];
    bool _isLoading = true;

    @override 
    void initState() { super.initState(); _load(); }

    Future<void> _load() async {
        try {
            final data = await _api.fetchBusinessApprovals();
            // Filter locally for now if API returns all
            final pending = data.where((i) => i['status'] == 'PENDING').toList();
            if (mounted) setState(() { _items = pending; _isLoading = false; });
        } catch (e) {
            if (mounted) setState(() => _isLoading = false);
        }
    }

    Future<void> _decide(int id, String status) async {
        await _api.updateBusinessStatus(id, status); // Need to ensure this exists or add it
        _load();
    }

    @override
    Widget build(BuildContext context) {
        if (_isLoading) return const Center(child: CircularProgressIndicator());
        if (_items.isEmpty) return const Center(child: Text("No pending business profiles."));
        
        return ListView.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                        title: Text(item['company_name'] ?? 'Unknown'),
                        subtitle: Text(item['description'] ?? ''),
                        trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _decide(item['id'], 'APPROVED')),
                                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _decide(item['id'], 'REJECTED')),
                            ],
                        ),
                    ),
                );
            }
        );
    }
}

class _MarketingApprovalsList extends StatefulWidget {
    const _MarketingApprovalsList();
    @override
    State<_MarketingApprovalsList> createState() => _MarketingApprovalsListState();
}

class _MarketingApprovalsListState extends State<_MarketingApprovalsList> {
    final _api = AdminApiService();
    List<dynamic> _items = [];
    bool _isLoading = true;

    @override 
    void initState() { super.initState(); _load(); }

    Future<void> _load() async {
        try {
            final data = await _api.fetchMarketingApprovals();
            // Filter locally
            // final pending = data.where((i) => i['status'] == 'PENDING').toList();
            // Show ALL, but maybe sort PENDING first
            data.sort((a,b) {
                if (a['status'] == 'PENDING' && b['status'] != 'PENDING') return -1;
                if (a['status'] != 'PENDING' && b['status'] == 'PENDING') return 1;
                return 0; // Keep original order otherwise (usually date desc)
            });
            if (mounted) setState(() { _items = data; _isLoading = false; });
        } catch (e) {
            if (mounted) setState(() => _isLoading = false);
        }
    }


    Future<void> _decide(int id, String status) async {
        setState(() => _isLoading = true);
        try {
            await _api.updateMarketingStatus(id, status);
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Request marked as $status"), backgroundColor: Colors.green)
                );
            }
            await _load();
        } catch (e) {
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
                );
                // Reload anyway to reset state
                 _load();
            }
        }
    }

    Future<void> _delete(int id) async {
         // Confirm Dialog
         final confirm = await showDialog<bool>(
             context: context,
             builder: (c) => AlertDialog(
                 title: const Text("Delete Post?"),
                 content: const Text("This cannot be undone."),
                 actions: [
                     TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
                     TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                 ],
             )
         );
         
         if (confirm != true) return;

         setState(() => _isLoading = true);
         try {
             await _api.deleteMarketingRequest(id);
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted!")));
             _load(); 
         } catch (e) {
             if (mounted) {
                 setState(() => _isLoading = false);
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete Failed: $e")));
             }
         }
    }

    @override
    Widget build(BuildContext context) {
        if (_isLoading) return const Center(child: CircularProgressIndicator());
        if (_items.isEmpty) return const Center(child: Text("No pending marketing requests."));
        
        return ListView.builder(
            itemCount: _items.length,
            itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                    margin: const EdgeInsets.all(8),
                    child: Column(
                        children: [
                            ListTile(
                                leading: item['type'] == 'AD' ? const Icon(Icons.star, color: Colors.amber) : const Icon(Icons.campaign, color: Colors.blue),
                                title: Text(item['title'] ?? 'Untitled'),
                                subtitle: Text(item['link'] ?? 'No link'),
                            ),
                            if (item['image'] != null)
                                Builder(builder: (c) {
                                  var url = item['image'].toString();
                                  if (url.startsWith('/')) {
                                      final domain = baseUrl.replaceAll('/api/', '');
                                      url = '$domain$url';
                                  }
                                  return SizedBox(height: 100, child: Image.network(url));
                                }),
                             if (item['video'] != null)
                                const Padding(padding: EdgeInsets.all(8.0), child: Text("VIDEO CONTENT ATTACHED", style: TextStyle(fontWeight: FontWeight.bold))),
                            
                            
                            ButtonBar(
                                children: [
                                    if (item['status'] == 'PENDING') ...[
                                       TextButton(onPressed: () => _decide(item['id'], 'REJECTED'), child: const Text("Reject", style: TextStyle(color: Colors.red))),
                                       ElevatedButton(onPressed: () => _decide(item['id'], 'APPROVED'), child: const Text("Approve")),
                                    ] else ...[
                                        // Already decided, show Delete
                                        IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _delete(item['id']),
                                        ),
                                        Text(item['status'], style: TextStyle(
                                            color: item['status'] == 'APPROVED' ? Colors.green : Colors.grey,
                                            fontWeight: FontWeight.bold
                                        )),
                                    ]
                                ],
                            )
                        ],
                    ),
                );
            }
        );
    }
}
