import 'package:flutter/material.dart';

import '../../../core/services/admin_api_service.dart';
import 'report_detail_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final AdminApiService _api = AdminApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _reports = <dynamic>[];
  final Set<int> _selectedOpenReportIds = <int>{};

  bool _isLoading = true;
  String? _error;
  String _statusFilter = 'OPEN';
  String _typeFilter = 'ALL';
  String _ageFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reports = await _api.fetchReports();
      reports.sort((a, b) {
        final aStatus = (a['status'] ?? 'OPEN').toString().toUpperCase();
        final bStatus = (b['status'] ?? 'OPEN').toString().toUpperCase();
        if (aStatus != bStatus) {
          if (aStatus == 'OPEN') return -1;
          if (bStatus == 'OPEN') return 1;
        }

        final aDate = DateTime.tryParse((a['created_at'] ?? '').toString());
        final bDate = DateTime.tryParse((b['created_at'] ?? '').toString());
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoading = false;
        _selectedOpenReportIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int _reportId(dynamic report) {
    final id = report['id'];
    if (id is int) return id;
    return int.tryParse(id.toString()) ?? -1;
  }

  int _hoursOpen(dynamic report) {
    final created = DateTime.tryParse((report['created_at'] ?? '').toString());
    if (created == null) return 0;
    return DateTime.now().difference(created.toLocal()).inHours;
  }

  bool _isSlaBreached(dynamic report) {
    final status = (report['status'] ?? 'OPEN').toString().toUpperCase();
    return status != 'RESOLVED' && _hoursOpen(report) > 24;
  }

  List<dynamic> _filteredReports() {
    final query = _searchController.text.trim().toLowerCase();
    return _reports.where((report) {
      final status = (report['status'] ?? 'OPEN').toString().toUpperCase();
      final type = (report['reported_item_type'] ?? '').toString().toUpperCase();
      final reporter = (report['reporter_username'] ?? '').toString().toLowerCase();
      final reportedUser = (report['reported_user'] ?? '').toString().toLowerCase();
      final reason = (report['reason'] ?? '').toString().toLowerCase();

      if (_statusFilter != 'ALL' && status != _statusFilter) return false;
      if (_typeFilter != 'ALL' && type != _typeFilter) return false;

      final ageHours = _hoursOpen(report);
      if (_ageFilter == '<=24H' && ageHours > 24) return false;
      if (_ageFilter == '>24H' && ageHours <= 24) return false;
      if (_ageFilter == '>72H' && ageHours <= 72) return false;

      if (query.isEmpty) return true;
      return reporter.contains(query) || reportedUser.contains(query) || reason.contains(query);
    }).toList();
  }

  Future<void> _bulkResolveSelected() async {
    final targets = _reports.where((report) {
      final id = _reportId(report);
      final status = (report['status'] ?? 'OPEN').toString().toUpperCase();
      return _selectedOpenReportIds.contains(id) && status != 'RESOLVED';
    }).toList();

    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one open report to resolve.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      for (final report in targets) {
        final id = _reportId(report);
        if (id > 0) {
          await _api.updateReportStatus(id, 'RESOLVED');
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Resolved ${targets.length} report(s).")),
      );
      await _fetchReports();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bulk resolve failed: $e")),
      );
    }
  }

  Widget _buildStatsCard() {
    final openCount = _reports.where((report) {
      final status = (report['status'] ?? 'OPEN').toString().toUpperCase();
      return status != 'RESOLVED';
    }).length;

    final breachedCount = _reports.where(_isSlaBreached).length;

    final today = DateTime.now();
    final resolvedToday = _reports.where((report) {
      final status = (report['status'] ?? '').toString().toUpperCase();
      if (status != 'RESOLVED') return false;
      final created = DateTime.tryParse((report['created_at'] ?? '').toString())?.toLocal();
      if (created == null) return false;
      return created.year == today.year && created.month == today.month && created.day == today.day;
    }).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _metric("Open queue", "$openCount"),
          ),
          Expanded(
            child: _metric("SLA breaches", "$breachedCount"),
          ),
          Expanded(
            child: _metric("Resolved today", "$resolvedToday"),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredReports();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Moderation Queue"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchReports,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildStatsCard(),
                    if (_selectedOpenReportIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _bulkResolveSelected,
                                icon: const Icon(Icons.check_circle_outline),
                                label: Text("Resolve (${_selectedOpenReportIds.length})"),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _selectedOpenReportIds.clear()),
                              icon: const Icon(Icons.clear),
                              tooltip: "Clear selection",
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
                          hintText: "Search reason, reporter, or reported user...",
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
                          _chip(
                            label: "All statuses",
                            selected: _statusFilter == 'ALL',
                            onTap: () => setState(() => _statusFilter = 'ALL'),
                          ),
                          _chip(
                            label: "Open",
                            selected: _statusFilter == 'OPEN',
                            onTap: () => setState(() => _statusFilter = 'OPEN'),
                          ),
                          _chip(
                            label: "Resolved",
                            selected: _statusFilter == 'RESOLVED',
                            onTap: () => setState(() => _statusFilter = 'RESOLVED'),
                          ),
                          const SizedBox(width: 8),
                          _chip(
                            label: "All types",
                            selected: _typeFilter == 'ALL',
                            onTap: () => setState(() => _typeFilter = 'ALL'),
                          ),
                          _chip(
                            label: "User",
                            selected: _typeFilter == 'USER',
                            onTap: () => setState(() => _typeFilter = 'USER'),
                          ),
                          _chip(
                            label: "Chat",
                            selected: _typeFilter == 'CHAT',
                            onTap: () => setState(() => _typeFilter = 'CHAT'),
                          ),
                          _chip(
                            label: "Post",
                            selected: _typeFilter == 'POST',
                            onTap: () => setState(() => _typeFilter = 'POST'),
                          ),
                          const SizedBox(width: 8),
                          _chip(
                            label: "All ages",
                            selected: _ageFilter == 'ALL',
                            onTap: () => setState(() => _ageFilter = 'ALL'),
                          ),
                          _chip(
                            label: "<=24h",
                            selected: _ageFilter == '<=24H',
                            onTap: () => setState(() => _ageFilter = '<=24H'),
                          ),
                          _chip(
                            label: ">24h",
                            selected: _ageFilter == '>24H',
                            onTap: () => setState(() => _ageFilter = '>24H'),
                          ),
                          _chip(
                            label: ">72h",
                            selected: _ageFilter == '>72H',
                            onTap: () => setState(() => _ageFilter = '>72H'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text("No reports match this queue filter."))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final report = filtered[index];
                                final status = (report['status'] ?? 'OPEN').toString().toUpperCase();
                                final type = (report['reported_item_type'] ?? 'UNKNOWN').toString().toUpperCase();
                                final isResolved = status == 'RESOLVED';
                                final reportId = _reportId(report);
                                final selected = _selectedOpenReportIds.contains(reportId);
                                final hours = _hoursOpen(report);
                                final breached = _isSlaBreached(report);

                                return Card(
                                  margin: EdgeInsets.zero,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ReportDetailScreen(
                                            report: Map<String, dynamic>.from(report),
                                            onUpdated: _fetchReports,
                                          ),
                                        ),
                                      );
                                      if (!mounted) return;
                                      await _fetchReports();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Checkbox(
                                                value: selected,
                                                onChanged: isResolved
                                                    ? null
                                                    : (_) {
                                                        setState(() {
                                                          if (selected) {
                                                            _selectedOpenReportIds.remove(reportId);
                                                          } else {
                                                            _selectedOpenReportIds.add(reportId);
                                                          }
                                                        });
                                                      },
                                              ),
                                              Expanded(
                                                child: Text(
                                                  "Reason: ${(report['reason'] ?? 'No reason provided').toString()}",
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward_ios,
                                                size: 14,
                                                color: Colors.grey[500],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Reporter: ${report['reporter_username'] ?? 'Unknown'}",
                                            style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "Target: ${report['reported_user'] ?? report['reported_item_id'] ?? 'Unknown'}",
                                            style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _badge(
                                                label: status,
                                                color: isResolved ? Colors.green : Colors.orange,
                                              ),
                                              const SizedBox(width: 8),
                                              _badge(
                                                label: type,
                                                color: Colors.blueGrey,
                                              ),
                                              const SizedBox(width: 8),
                                              _badge(
                                                label: breached ? "SLA BREACHED" : "OPEN ${hours}H",
                                                color: breached ? Colors.red : Colors.grey,
                                              ),
                                            ],
                                          ),
                                          if (!isResolved)
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                onPressed: () async {
                                                  final messenger = ScaffoldMessenger.of(this.context);
                                                  try {
                                                    await _api.updateReportStatus(reportId, 'RESOLVED');
                                                    if (!mounted) return;
                                                    messenger.showSnackBar(
                                                      const SnackBar(content: Text("Report marked as resolved.")),
                                                    );
                                                    await _fetchReports();
                                                  } catch (e) {
                                                    if (!mounted) return;
                                                    messenger.showSnackBar(
                                                      SnackBar(content: Text("Could not resolve report: $e")),
                                                    );
                                                  }
                                                },
                                                icon: const Icon(Icons.check, size: 16),
                                                label: const Text("Resolve"),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
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

  Widget _badge({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
