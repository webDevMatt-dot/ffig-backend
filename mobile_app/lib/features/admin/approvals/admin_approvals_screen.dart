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
    final _api = AdminApiService(); 
    List<dynamic> _items = [];
    bool _isLoading = true;
    String _searchQuery = "";

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
        if (status == 'REJECTED') {
            final reason = await _showDeclineReasonDialog(context);
            if (reason == null) return; // Cancelled
            await _api.updateBusinessStatus(id, status, feedback: reason);
        } else {
            await _api.updateBusinessStatus(id, status); 
        }
        _load();
    }

    @override
    Widget build(BuildContext context) {
        if (_isLoading) return const Center(child: CircularProgressIndicator());
        
        // Filter based on search query
        final filteredItems = _items.where((item) {
            if (_searchQuery.isEmpty) return true;
            final name = (item['company_name'] ?? '').toString().toLowerCase();
            final desc = (item['description'] ?? '').toString().toLowerCase();
            final q = _searchQuery.toLowerCase();
            return name.contains(q) || desc.contains(q);
        }).toList();

        if (_items.isEmpty) return const Center(child: Text("No pending business profiles."));
        
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search businesses...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16)
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: filteredItems.isEmpty 
                  ? const Center(child: Text("No matches found."))
                  : ListView.builder(
                    itemCount: filteredItems.length,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: InkWell(
                                onTap: () => _showBusinessDetails(context, item),
                                child: ListTile(
                                    title: Text(item['company_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(item['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                                    trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _decide(item['id'], 'APPROVED')),
                                            IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _decide(item['id'], 'REJECTED')),
                                        ],
                                    ),
                                ),
                            ),
                        );
                    }
                ),
            ),
          ],
        );
    }

    void _showBusinessDetails(BuildContext context, dynamic item) {
        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (c) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
                child: Container(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text("Business Details", style: TextStyle(color: FfigTheme.primaryBrown, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                Text(item['company_name'] ?? 'Unknown Business', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 8),
                                Text(item['description'] ?? 'No description provided.', style: const TextStyle(fontSize: 16, height: 1.5)),
                                const SizedBox(height: 16),
                                if (item['website'] != null && item['website'].toString().isNotEmpty) ...[
                                    const Text("Website", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    Text(item['website']),
                                    const SizedBox(height: 16),
                                ],
                                if (item['industry'] != null && item['industry'].toString().isNotEmpty) ...[
                                    const Text("Industry", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    Text(item['industry']),
                                    const SizedBox(height: 16),
                                ],
                                if (item['contact_email'] != null && item['contact_email'].toString().isNotEmpty) ...[
                                    const Text("Contact Email", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    Text(item['contact_email']),
                                    const SizedBox(height: 16),
                                ],
                                const SizedBox(height: 24),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close")),
                                    ]
                                )
                            ]
                        )
                    )
                )
            )
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
    String _searchQuery = "";

    @override 
    void initState() { super.initState(); _load(); }

    Future<void> _load() async {
        try {
            final data = await _api.fetchMarketingApprovals();
            // Show ALL, but maybe sort PENDING first
            data.sort((a,b) {
                if (a['status'] == 'PENDING' && b['status'] != 'PENDING') return -1;
                if (a['status'] != 'PENDING' && b['status'] == 'PENDING') return 1;
                return 0; 
            });
            if (mounted) setState(() { _items = data; _isLoading = false; });
        } catch (e) {
            if (mounted) setState(() => _isLoading = false);
        }
    }


    Future<void> _decide(int id, String status) async {
        String? reason;
        if (status == 'REJECTED') {
            reason = await _showDeclineReasonDialog(context);
            if (reason == null) return; // Cancelled
        }
        
        setState(() => _isLoading = true);
        try {
            await _api.updateMarketingStatus(id, status, feedback: reason);
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
             await _api.deleteAdminMarketingRequest(id);
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
        
        // Filter
        final filteredItems = _items.where((item) {
            if (_searchQuery.isEmpty) return true;
            final title = (item['title'] ?? '').toString().toLowerCase();
            final link = (item['link'] ?? '').toString().toLowerCase();
            final q = _searchQuery.toLowerCase();
            return title.contains(q) || link.contains(q);
        }).toList();

        if (_items.isEmpty) return const Center(child: Text("No pending marketing requests."));
        
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Search marketing...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16)
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: filteredItems.isEmpty 
                  ? const Center(child: Text("No matches found."))
                  : ListView.builder(
                    itemCount: filteredItems.length,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: InkWell(
                                onTap: () => _showMarketingDetails(context, item),
                                child: Column(
                                    children: [
                                        ListTile(
                                            leading: item['type'] == 'AD' ? const Icon(Icons.star, color: Colors.amber) : const Icon(Icons.campaign, color: Colors.blue),
                                            title: Text(item['title'] ?? 'Untitled'),
                                            subtitle: Text(item['link'] ?? 'No link', maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ),
                                        if (item['image'] != null)
                                            Builder(builder: (c) {
                                              var url = item['image'].toString();
                                              if (url.startsWith('/')) {
                                                  final domain = baseUrl.replaceAll('/api/', '');
                                                  url = '$domain$url';
                                              }
                                              return SizedBox(height: 100, child: Image.network(url, fit: BoxFit.cover));
                                            }),
                                         if (item['video'] != null)
                                            const Padding(padding: EdgeInsets.all(8.0), child: Text("VIDEO CONTENT ATTACHED", style: TextStyle(fontWeight: FontWeight.bold))),
                                        
                                        
                                        OverflowBar(
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
                            ),
                        );
                    }
                ),
            ),
          ],
        );
    }

    void _showMarketingDetails(BuildContext context, dynamic item) {
        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (c) => Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
                child: Container(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text("Marketing Request Details", style: TextStyle(color: FfigTheme.primaryBrown, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                Text(item['title'] ?? 'Untitled Request', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                const Text("Type", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 8),
                                Text(item['type'] ?? 'Unknown', style: const TextStyle(fontSize: 16)),
                                const SizedBox(height: 16),
                                if (item['link'] != null && item['link'].toString().isNotEmpty) ...[
                                    const Text("Link", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    Text(item['link']),
                                    const SizedBox(height: 16),
                                ],
                                if (item['image'] != null) ...[
                                    const Text("Attached Image", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    Builder(builder: (c) {
                                        var url = item['image'].toString();
                                        if (url.startsWith('/')) {
                                            final domain = baseUrl.replaceAll('/api/', '');
                                            url = '$domain$url';
                                        }
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(8), 
                                          child: Image.network(url, fit: BoxFit.cover)
                                        );
                                    }),
                                    const SizedBox(height: 16),
                                ],
                                if (item['video'] != null) ...[
                                    const Text("Attached Video", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    const Text("User uploaded a video for this request.", style: TextStyle(fontStyle: FontStyle.italic)),
                                    const SizedBox(height: 16),
                                ],
                                const SizedBox(height: 24),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close")),
                                    ]
                                )
                            ]
                        )
                    )
                )
            )
        );
    }
}

/// Helper method to prompt the admin for a reason when declining.
Future<String?> _showDeclineReasonDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
            title: const Text("Decline Reason"),
            content: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Why is this being declined?",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                maxLines: 3,
                autofocus: true,
            ),
            actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
                ElevatedButton(
                    onPressed: () {
                        if (controller.text.trim().isEmpty) return;
                        Navigator.pop(c, controller.text.trim());
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("Confirm Decline"),
                )
            ]
        )
    );
}
