import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/api/constants.dart';
import '../../../core/services/admin_api_service.dart';

class ReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback? onUpdated;

  const ReportDetailScreen({
    super.key,
    required this.report,
    this.onUpdated,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final AdminApiService _api = AdminApiService();
  bool _isLoadingContext = false;
  bool _isUpdating = false;
  List<dynamic> _chatContext = [];
  bool _contextError = false;
  final _storage = const FlutterSecureStorage();
  late String _currentStatus;
  late Map<String, dynamic> _report;

  @override
  void initState() {
    super.initState();
    _report = Map<String, dynamic>.from(widget.report);
    _currentStatus = (_report['status'] ?? 'OPEN').toString().toUpperCase();
    _extractAndFetchContext();
  }

  Future<void> _extractAndFetchContext() async {
    final reason = (_report['reason'] ?? '').toString();
    // Regex to find [CID:123]
    final regex = RegExp(r'\[CID:(\d+)\]');
    final match = regex.firstMatch(reason);
    
    if (match != null) {
        final cid = match.group(1);
        if (cid != null) {
            _fetchMessages(cid);
        }
    }
  }

  Future<void> _fetchMessages(String conversationId) async {
      setState(() => _isLoadingContext = true);
      try {
          final token = await _storage.read(key: 'access_token');
          // Fetch last 20 messages? Need API.
          // Re-using Message List API: api/chat/conversations/{pk}/messages/
          // Note: This API requires User to be Participant. Admin might fail if not checked.
          // But Admin permission usually overrides?
          // Wait, MessageListView checks: "if not conversation.is_public and self.request.user not in conversation.participants"
          // Admin User (is_staff) needs override in Backend View?
          // If Backend blocks Admin, I can't fetch.
          // Logic gap: Admins need access to ANY conversation messages?
          // I will attempt fetch. If 403/404, I show error.
          
          final response = await http.get(
              Uri.parse('${baseUrl}chat/conversations/$conversationId/messages/'),
              headers: {'Authorization': 'Bearer $token'}
          );

          if (response.statusCode == 200) {
              final msgs = jsonDecode(response.body) as List;
              // Take last 10
              final last10 = msgs.length > 10 ? msgs.sublist(msgs.length - 10) : msgs;
              if (mounted) {
                setState(() {
                  _chatContext = last10;
                  _isLoadingContext = false;
              });
              }
          } else {
              if (mounted) {
                setState(() {
                  _isLoadingContext = false;
                  _contextError = true; // "Admin access denied" likely
              });
              }
          }
      } catch (e) {
          if (mounted) {
            setState(() {
              _isLoadingContext = false;
              _contextError = true;
          });
          }
      }
  }

  Future<void> _resolveReport() async {
      if (_isUpdating) return;
      setState(() => _isUpdating = true);
      try {
          final int id = (_report['id'] is int)
              ? _report['id'] as int
              : int.parse(_report['id'].toString());
          await _api.updateReportStatus(id, 'RESOLVED');

          if (!mounted) return;
          setState(() {
            _currentStatus = 'RESOLVED';
            _report['status'] = 'RESOLVED';
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marked as resolved")));
          widget.onUpdated?.call();
      } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating status: $e")));
      } finally {
          if (mounted) {
            setState(() => _isUpdating = false);
          }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Report Detail")),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text("Report #${_report['id']}", style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    _buildInfoRow("Reporter", _report['reporter_username'] ?? 'Unknown'),
                    _buildInfoRow("Type", _report['reported_item_type']),
                    _buildInfoRow("Reported User", _report['reported_user'] ?? 'Unknown'),
                    _buildInfoRow("Target ID", _report['reported_item_id']),
                    _buildInfoRow("Date", _report['created_at']),
                    
                    const SizedBox(height: 24),
                    const Text("Reason & Context:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                        child: Text((_report['reason'] ?? '').toString()),
                    ),

                    const SizedBox(height: 32),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text("Chat Context (Last 10)", style: Theme.of(context).textTheme.titleMedium),
                            if (_isLoadingContext) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        ],
                    ),
                    const SizedBox(height: 8),
                    if (_contextError)
                         Container(
                             padding: const EdgeInsets.all(12),
                             color: Colors.red[50], 
                             child: const Text("Could not load chat context. Note: Standard Admins may not have permission to view private chats via API unless logic is updated.", style: TextStyle(color: Colors.red))
                         )
                    else if (_chatContext.isEmpty && !_isLoadingContext)
                         const Text("No automated context found in reason.")
                    else
                         ..._chatContext.map((msg) => ListTile(
                             contentPadding: EdgeInsets.zero,
                             leading: CircleAvatar(child: Text((msg['sender']['username'] as String)[0].toUpperCase())),
                             title: Text(msg['sender']['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                             subtitle: Text(msg['text']),
                             trailing: Text(DateFormat('HH:mm').format(DateTime.parse(msg['created_at']).toLocal()), style: const TextStyle(fontSize: 10)),
                         )),
                         
                    const SizedBox(height: 40),
                    if (_currentStatus != 'RESOLVED')
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check),
                                  label: _isUpdating
                                      ? const Text("Updating...")
                                      : const Text("Mark as Resolved"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                                  onPressed: _isUpdating ? null : _resolveReport,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            const Text("Administrative Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 16),
                            if (_report['target_user_id'] != null) ...[
                                _buildActionBtn("Warn User", Colors.orange, Icons.warning, () => _confirmAction('WARN')),
                                _buildActionBtn("Suspend (7 Days)", Colors.deepOrange, Icons.timer_off, () => _confirmAction('SUSPEND')),
                                _buildActionBtn("Block User", Colors.red, Icons.block, () => _confirmAction('BLOCK')),
                                _buildActionBtn("Delete User", Colors.black, Icons.delete_forever, () => _confirmAction('DELETE')),
                            ] else
                                const Text("Action unavailable: No direct user target.", style: TextStyle(color: Colors.grey)),
                          ],
                        )
                    else
                        const Center(child: Text("✅ Report Resolved", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)))
                ],
            ),
        ),
    );
  }

  Widget _buildActionBtn(String label, Color color, IconData icon, VoidCallback onTap) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                  icon: Icon(icon, color: color),
                  label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      side: BorderSide(color: color),
                  ),
                  onPressed: _isUpdating ? null : onTap
              ),
          ),
      );
  }

  Future<void> _confirmAction(String action) async {
      final reasonController = TextEditingController(text: (_report['reason'] ?? '').toString());
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
              title: Text("Confirm $action?"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("This action cannot be easily undone."),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Reason",
                      hintText: "Add admin note",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context, true), 
                      child: const Text("Confirm")
                  ),
              ],
          )
      );

      if (confirmed == true) {
          await _performAction(action, reasonController.text.trim());
      }
      reasonController.dispose();
  }

  Future<void> _performAction(String action, String reason) async {
      final dynamic target = _report['target_user_id'];
      final int? targetUserId = target is int ? target : int.tryParse(target?.toString() ?? '');
      if (targetUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This report has no direct user target.")),
        );
        return;
      }

      setState(() => _isUpdating = true);
       try {
          await _api.performModerationAction(
            action: action,
            targetUserId: targetUserId,
            reason: reason,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action $action successful.")));
          if (_currentStatus != 'RESOLVED') {
            final int reportId = (_report['id'] is int)
                ? _report['id'] as int
                : int.parse(_report['id'].toString());
            await _api.updateReportStatus(reportId, 'RESOLVED');
            if (!mounted) return;
            setState(() {
              _currentStatus = 'RESOLVED';
              _report['status'] = 'RESOLVED';
            });
            widget.onUpdated?.call();
          }
      } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action failed: $e")));
      } finally {
          if (mounted) {
            setState(() => _isUpdating = false);
          }
      }
  }

  Widget _buildInfoRow(String label, dynamic value) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
              children: [
                  SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                  Expanded(child: Text(value?.toString() ?? '-')),
              ],
          ),
      );
  }
}
