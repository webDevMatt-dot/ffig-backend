import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/admin_api_service.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  final AdminApiService _apiService = AdminApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _loginLogs = [];
  List<dynamic> _auditLogs = [];
  bool _isLoading = true;
  String? _error;
  String _auditActionFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _apiService.fetchLoginLogs(),
        _apiService.fetchAuditLogs(),
      ]);
      if (!mounted) return;
      setState(() {
        _loginLogs = results[0];
        _auditLogs = results[1];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown time';
    try {
      return DateFormat('MMM dd, yyyy - HH:mm:ss').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  List<dynamic> _filteredAuditLogs() {
    final query = _searchController.text.trim().toLowerCase();

    return _auditLogs.where((log) {
      if (_auditActionFilter != 'ALL' && log['action_type'] != _auditActionFilter) {
        return false;
      }

      if (query.isEmpty) return true;

      final actor = (log['actor_username'] ?? '').toString().toLowerCase();
      final label = (log['target_label'] ?? '').toString().toLowerCase();
      final targetType = (log['target_type'] ?? '').toString().toLowerCase();
      final reason = (log['reason'] ?? '').toString().toLowerCase();
      final action = (log['action_type'] ?? '').toString().toLowerCase();

      return actor.contains(query) ||
          label.contains(query) ||
          targetType.contains(query) ||
          reason.contains(query) ||
          action.contains(query);
    }).toList();
  }

  Color _actionColor(String actionType) {
    switch (actionType) {
      case 'MODERATION_ACTION':
        return Colors.deepOrange;
      case 'REPORT_STATUS':
        return Colors.blue;
      case 'BUSINESS_STATUS':
        return Colors.green;
      case 'MARKETING_STATUS':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _actionLabel(String actionType) {
    switch (actionType) {
      case 'MODERATION_ACTION':
        return 'Moderation';
      case 'REPORT_STATUS':
        return 'Report Update';
      case 'BUSINESS_STATUS':
        return 'Business Approval';
      case 'MARKETING_STATUS':
        return 'Marketing Approval';
      default:
        return actionType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Activity Logs"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Login Logs"),
              Tab(text: "Audit Trail"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchLogs,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchLogs,
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _buildLoginLogs(),
                      _buildAuditLogs(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildLoginLogs() {
    if (_loginLogs.isEmpty) {
      return const Center(child: Text("No login logs found."));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _loginLogs.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final log = _loginLogs[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            log['username'] ?? 'Unknown User',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text("IP: ${log['ip_address'] ?? 'N/A'}"),
              const SizedBox(height: 2),
              Text(
                "Agent: ${log['user_agent'] ?? 'N/A'}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: Text(
            _formatDate(log['timestamp']?.toString()),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        );
      },
    );
  }

  Widget _buildAuditLogs() {
    final filtered = _filteredAuditLogs();
    final actionTypes = <String>{
      'ALL',
      ..._auditLogs.map((e) => (e['action_type'] ?? '').toString()).where((e) => e.isNotEmpty),
    }.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Search actor, target, reason...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: actionTypes.map((type) {
              final selected = _auditActionFilter == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type == 'ALL' ? 'All actions' : _actionLabel(type)),
                  selected: selected,
                  onSelected: (_) => setState(() => _auditActionFilter = type),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text("No audit records found for this filter."))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    final actionType = (log['action_type'] ?? '').toString();
                    final actionColor = _actionColor(actionType);
                    final metadata = log['metadata'];
                    final metadataText = metadata is Map
                        ? const JsonEncoder.withIndent('  ').convert(metadata)
                        : metadata?.toString();

                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: actionColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _actionLabel(actionType),
                                    style: TextStyle(
                                      color: actionColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatDate(log['created_at']?.toString()),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${log['actor_username'] ?? 'System'} -> ${log['target_type'] ?? 'target'}:${log['target_id'] ?? ''}",
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if ((log['target_label'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                log['target_label'].toString(),
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                            if ((log['reason'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                "Reason: ${log['reason']}",
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                            if (metadataText != null && metadataText.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  metadataText,
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                ),
                              ),
                            ],
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
