import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/api/constants.dart';
import '../../../core/services/admin_api_service.dart';

class AdminApprovalsScreen extends StatelessWidget {
  const AdminApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _ApprovalsAppBar(),
        body: TabBarView(
          children: [
            _BusinessApprovalsList(),
            _MarketingApprovalsList(),
          ],
        ),
      ),
    );
  }
}

class _ApprovalsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ApprovalsAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text("Approvals Center"),
      bottom: const TabBar(
        tabs: [
          Tab(text: "Business"),
          Tab(text: "Marketing"),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);
}

class _BusinessApprovalsList extends StatefulWidget {
  const _BusinessApprovalsList();

  @override
  State<_BusinessApprovalsList> createState() => _BusinessApprovalsListState();
}

class _BusinessApprovalsListState extends State<_BusinessApprovalsList> {
  final AdminApiService _api = AdminApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _items = [];
  final Set<int> _selectedIds = <int>{};

  bool _isLoading = true;
  String _statusFilter = 'ALL';
  String _ageFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.fetchBusinessApprovals();
      data.sort((a, b) {
        final aPending = a['status'] == 'PENDING' ? 0 : 1;
        final bPending = b['status'] == 'PENDING' ? 0 : 1;
        if (aPending != bPending) return aPending.compareTo(bPending);
        final aDate = DateTime.tryParse((a['created_at'] ?? '').toString());
        final bDate = DateTime.tryParse((b['created_at'] ?? '').toString());
        if (aDate == null || bDate == null) return 0;
        return aDate.compareTo(bDate);
      });
      if (!mounted) return;
      setState(() {
        _items = data;
        _isLoading = false;
        _selectedIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load approvals: $e")));
    }
  }

  int _hoursOpen(dynamic item) {
    final created = DateTime.tryParse((item['created_at'] ?? '').toString());
    if (created == null) return 0;
    return DateTime.now().difference(created.toLocal()).inHours;
  }

  bool _isSlaBreached(dynamic item) {
    return (item['status'] == 'PENDING') && _hoursOpen(item) > 48;
  }

  List<dynamic> _filteredItems() {
    final query = _searchController.text.trim().toLowerCase();
    return _items.where((item) {
      final status = (item['status'] ?? '').toString().toUpperCase();
      final company = (item['company_name'] ?? '').toString().toLowerCase();
      final description = (item['description'] ?? '').toString().toLowerCase();

      if (_statusFilter != 'ALL' && status != _statusFilter) return false;
      if (_ageFilter == '<=24H' && _hoursOpen(item) > 24) return false;
      if (_ageFilter == '>24H' && _hoursOpen(item) <= 24) return false;

      if (query.isEmpty) return true;
      return company.contains(query) || description.contains(query);
    }).toList();
  }

  Future<String?> _askRejectReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject reason"),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Reason..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return null;
    return reason;
  }

  Future<void> _bulkUpdate(String status) async {
    final targets = _items.where((e) => _selectedIds.contains(e['id']) && e['status'] == 'PENDING').toList();
    if (targets.isEmpty) return;

    String? feedback;
    if (status == 'REJECTED') {
      feedback = await _askRejectReason();
      if (feedback == null) return;
    }

    setState(() => _isLoading = true);
    try {
      for (final item in targets) {
        await _api.updateBusinessStatus(item['id'] as int, status, feedback: feedback);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Updated ${targets.length} business profile(s) to $status")),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bulk update failed: $e")));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems();
    final pendingCount = _items.where((e) => e['status'] == 'PENDING').length;
    final breachedCount = _items.where(_isSlaBreached).length;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).cardColor,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Expanded(child: Text("Pending: $pendingCount", style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(child: Text("SLA breaches: $breachedCount", style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        ),
        if (_selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _bulkUpdate('APPROVED'),
                    child: Text("Approve (${_selectedIds.length})"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _bulkUpdate('REJECTED'),
                    child: const Text("Reject"),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _selectedIds.clear()),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Search company or description...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              _chip(label: "All", selected: _statusFilter == 'ALL', onTap: () => setState(() => _statusFilter = 'ALL')),
              _chip(label: "Pending", selected: _statusFilter == 'PENDING', onTap: () => setState(() => _statusFilter = 'PENDING')),
              _chip(label: "Approved", selected: _statusFilter == 'APPROVED', onTap: () => setState(() => _statusFilter = 'APPROVED')),
              _chip(label: "Rejected", selected: _statusFilter == 'REJECTED', onTap: () => setState(() => _statusFilter = 'REJECTED')),
              const SizedBox(width: 8),
              _chip(label: "All ages", selected: _ageFilter == 'ALL', onTap: () => setState(() => _ageFilter = 'ALL')),
              _chip(label: "<=24h", selected: _ageFilter == '<=24H', onTap: () => setState(() => _ageFilter = '<=24H')),
              _chip(label: ">24h", selected: _ageFilter == '>24H', onTap: () => setState(() => _ageFilter = '>24H')),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text("No approvals match your filter."))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final id = item['id'] as int;
                    final status = (item['status'] ?? 'UNKNOWN').toString().toUpperCase();
                    final selected = _selectedIds.contains(id);
                    final hours = _hoursOpen(item);
                    final breached = _isSlaBreached(item);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: selected,
                                  onChanged: (_) {
                                    setState(() {
                                      if (selected) {
                                        _selectedIds.remove(id);
                                      } else {
                                        _selectedIds.add(id);
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    (item['company_name'] ?? 'Unknown company').toString(),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: _statusColor(status),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              (item['description'] ?? '').toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  breached ? Icons.warning_amber_rounded : Icons.schedule,
                                  size: 16,
                                  color: breached ? Colors.red : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  breached ? "SLA breached (${hours}h open)" : "Open ${hours}h · SLA 48h",
                                  style: TextStyle(
                                    color: breached ? Colors.red : Colors.grey[700],
                                    fontSize: 12,
                                    fontWeight: breached ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (status == 'PENDING')
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () async {
                                        final reason = await _askRejectReason();
                                        if (reason == null) return;
                                        await _api.updateBusinessStatus(id, 'REJECTED', feedback: reason);
                                        await _load();
                                      },
                                      child: const Text("Reject"),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await _api.updateBusinessStatus(id, 'APPROVED');
                                        await _load();
                                      },
                                      child: const Text("Approve"),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MarketingApprovalsList extends StatefulWidget {
  const _MarketingApprovalsList();

  @override
  State<_MarketingApprovalsList> createState() => _MarketingApprovalsListState();
}

class _MarketingApprovalsListState extends State<_MarketingApprovalsList> {
  final AdminApiService _api = AdminApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _items = [];
  final Set<int> _selectedIds = <int>{};

  bool _isLoading = true;
  String _statusFilter = 'ALL';
  String _typeFilter = 'ALL';
  String _ageFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.fetchMarketingApprovals();
      if (!mounted) return;
      setState(() {
        _items = data;
        _isLoading = false;
        _selectedIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load approvals: $e")));
    }
  }

  int _hoursOpen(dynamic item) {
    final created = DateTime.tryParse((item['created_at'] ?? '').toString());
    if (created == null) return 0;
    return DateTime.now().difference(created.toLocal()).inHours;
  }

  bool _isSlaBreached(dynamic item) => (item['status'] == 'PENDING') && _hoursOpen(item) > 48;

  List<dynamic> _filteredItems() {
    final query = _searchController.text.trim().toLowerCase();
    return _items.where((item) {
      final status = (item['status'] ?? '').toString().toUpperCase();
      final type = (item['type'] ?? '').toString().toUpperCase();
      final title = (item['title'] ?? '').toString().toLowerCase();
      final link = (item['link'] ?? '').toString().toLowerCase();

      if (_statusFilter != 'ALL' && status != _statusFilter) return false;
      if (_typeFilter != 'ALL' && type != _typeFilter) return false;
      if (_ageFilter == '<=24H' && _hoursOpen(item) > 24) return false;
      if (_ageFilter == '>24H' && _hoursOpen(item) <= 24) return false;

      if (query.isEmpty) return true;
      return title.contains(query) || link.contains(query);
    }).toList();
  }

  Future<String?> _askRejectReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject reason"),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Reason..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return null;
    return reason;
  }

  Future<void> _bulkUpdate(String status) async {
    final targets = _items.where((e) => _selectedIds.contains(e['id']) && e['status'] == 'PENDING').toList();
    if (targets.isEmpty) return;

    String? feedback;
    if (status == 'REJECTED') {
      feedback = await _askRejectReason();
      if (feedback == null) return;
    }

    setState(() => _isLoading = true);
    try {
      for (final item in targets) {
        await _api.updateMarketingStatus(item['id'] as int, status, feedback: feedback);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Updated ${targets.length} marketing request(s) to $status")),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bulk update failed: $e")));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String? _absoluteMediaUrl(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty || raw == 'null') return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('//')) {
      return 'https:$raw';
    }

    final apiUri = Uri.parse(baseUrl);
    final origin = '${apiUri.scheme}://${apiUri.host}${apiUri.hasPort ? ':${apiUri.port}' : ''}';

    if (raw.startsWith('/')) {
      return '$origin$raw';
    }
    return '$origin/$raw';
  }

  String? _imageUrl(dynamic item) {
    return _absoluteMediaUrl(item['image_url'] ?? item['image']);
  }

  String? _videoUrl(dynamic item) {
    return _absoluteMediaUrl(item['video_url'] ?? item['video']);
  }

  bool _hasMedia(dynamic item) => _imageUrl(item) != null || _videoUrl(item) != null;

  Future<void> _showPreview(dynamic item) async {
    final imageUrl = _imageUrl(item);
    final videoUrl = _videoUrl(item);
    if (imageUrl == null && videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No uploaded media found for this request.")),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _MarketingMediaPreviewSheet(
          title: (item['title'] ?? 'Marketing Preview').toString(),
          imageUrl: imageUrl,
          videoUrl: videoUrl,
          link: (item['link'] ?? '').toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems();
    final pendingCount = _items.where((e) => e['status'] == 'PENDING').length;
    final breachedCount = _items.where(_isSlaBreached).length;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).cardColor,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Expanded(child: Text("Pending: $pendingCount", style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(child: Text("SLA breaches: $breachedCount", style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        ),
        if (_selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _bulkUpdate('APPROVED'),
                    child: Text("Approve (${_selectedIds.length})"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _bulkUpdate('REJECTED'),
                    child: const Text("Reject"),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _selectedIds.clear()),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Search title or link...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              _chip(label: "All", selected: _statusFilter == 'ALL', onTap: () => setState(() => _statusFilter = 'ALL')),
              _chip(label: "Pending", selected: _statusFilter == 'PENDING', onTap: () => setState(() => _statusFilter = 'PENDING')),
              _chip(label: "Approved", selected: _statusFilter == 'APPROVED', onTap: () => setState(() => _statusFilter = 'APPROVED')),
              _chip(label: "Rejected", selected: _statusFilter == 'REJECTED', onTap: () => setState(() => _statusFilter = 'REJECTED')),
              const SizedBox(width: 8),
              _chip(label: "All types", selected: _typeFilter == 'ALL', onTap: () => setState(() => _typeFilter = 'ALL')),
              _chip(label: "Ads", selected: _typeFilter == 'AD', onTap: () => setState(() => _typeFilter = 'AD')),
              _chip(label: "Promotion", selected: _typeFilter == 'PROMOTION', onTap: () => setState(() => _typeFilter = 'PROMOTION')),
              _chip(label: "Content", selected: _typeFilter == 'CONTENT', onTap: () => setState(() => _typeFilter = 'CONTENT')),
              const SizedBox(width: 8),
              _chip(label: "All ages", selected: _ageFilter == 'ALL', onTap: () => setState(() => _ageFilter = 'ALL')),
              _chip(label: "<=24h", selected: _ageFilter == '<=24H', onTap: () => setState(() => _ageFilter = '<=24H')),
              _chip(label: ">24h", selected: _ageFilter == '>24H', onTap: () => setState(() => _ageFilter = '>24H')),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text("No approvals match your filter."))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final id = item['id'] as int;
                    final status = (item['status'] ?? 'UNKNOWN').toString().toUpperCase();
                    final selected = _selectedIds.contains(id);
                    final hours = _hoursOpen(item);
                    final breached = _isSlaBreached(item);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: selected,
                                  onChanged: (_) {
                                    setState(() {
                                      if (selected) {
                                        _selectedIds.remove(id);
                                      } else {
                                        _selectedIds.add(id);
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    (item['title'] ?? 'Untitled request').toString(),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: _statusColor(status),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Type: ${(item['type'] ?? '').toString().toUpperCase()} · ${(item['link'] ?? '').toString()}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (_imageUrl(item) != null)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      "Photo",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.blue),
                                    ),
                                  ),
                                if (_videoUrl(item) != null)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      "Video",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.deepPurple),
                                    ),
                                  ),
                                if (!_hasMedia(item))
                                  Text(
                                    "No media uploaded",
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _hasMedia(item) ? () => _showPreview(item) : null,
                                  icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                                  label: const Text("Preview"),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  breached ? Icons.warning_amber_rounded : Icons.schedule,
                                  size: 16,
                                  color: breached ? Colors.red : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  breached ? "SLA breached (${hours}h open)" : "Open ${hours}h · SLA 48h",
                                  style: TextStyle(
                                    color: breached ? Colors.red : Colors.grey[700],
                                    fontSize: 12,
                                    fontWeight: breached ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: 8,
                                children: [
                                  if (status == 'PENDING')
                                    OutlinedButton(
                                      onPressed: () async {
                                        final reason = await _askRejectReason();
                                        if (reason == null) return;
                                        await _api.updateMarketingStatus(id, 'REJECTED', feedback: reason);
                                        await _load();
                                      },
                                      child: const Text("Reject"),
                                    ),
                                  if (status == 'PENDING')
                                    ElevatedButton(
                                      onPressed: () async {
                                        await _api.updateMarketingStatus(id, 'APPROVED');
                                        await _load();
                                      },
                                      child: const Text("Approve"),
                                    ),
                                  if (status != 'PENDING')
                                    TextButton(
                                      onPressed: () async {
                                        await _api.deleteAdminMarketingRequest(id);
                                        await _load();
                                      },
                                      child: const Text("Delete"),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MarketingMediaPreviewSheet extends StatefulWidget {
  final String title;
  final String? imageUrl;
  final String? videoUrl;
  final String link;

  const _MarketingMediaPreviewSheet({
    required this.title,
    required this.imageUrl,
    required this.videoUrl,
    required this.link,
  });

  @override
  State<_MarketingMediaPreviewSheet> createState() => _MarketingMediaPreviewSheetState();
}

class _MarketingMediaPreviewSheetState extends State<_MarketingMediaPreviewSheet> {
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final videoUrl = widget.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _videoReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _videoError = e.toString();
        _videoReady = false;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.imageUrl != null) ...[
                  const Text("Photo", style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 220,
                        alignment: Alignment.center,
                        color: Colors.black12,
                        child: const Text("Could not load image preview"),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (widget.videoUrl != null) ...[
                  const Text("Video", style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black,
                      child: _videoError != null
                          ? SizedBox(
                              height: 220,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    "Could not load video preview.\n$_videoError",
                                    style: const TextStyle(color: Colors.white70),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            )
                          : !_videoReady || _videoController == null
                              ? const SizedBox(
                                  height: 220,
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : AspectRatio(
                                  aspectRatio: _videoController!.value.aspectRatio,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      VideoPlayer(_videoController!),
                                      Align(
                                        alignment: Alignment.center,
                                        child: IconButton(
                                          iconSize: 56,
                                          color: Colors.white,
                                          onPressed: () {
                                            final controller = _videoController;
                                            if (controller == null) return;
                                            if (controller.value.isPlaying) {
                                              controller.pause();
                                            } else {
                                              controller.play();
                                            }
                                            setState(() {});
                                          },
                                          icon: Icon(
                                            _videoController!.value.isPlaying
                                                ? Icons.pause_circle_filled
                                                : Icons.play_circle_fill,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                if (widget.link.trim().isNotEmpty) ...[
                  const Text("Destination Link", style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SelectableText(widget.link, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _chip({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}
