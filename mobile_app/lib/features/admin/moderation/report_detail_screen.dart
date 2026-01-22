import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/api/constants.dart';
import '../../../core/theme/ffig_theme.dart';

class ReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  bool _isLoadingContext = false;
  List<dynamic> _chatContext = [];
  bool _contextError = false;
  final _storage = const FlutterSecureStorage();
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.report['status'];
    _extractAndFetchContext();
  }

  Future<void> _extractAndFetchContext() async {
    final reason = widget.report['reason'] as String;
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
      try {
          final token = await _storage.read(key: 'access_token');
          final response = await http.patch(
              Uri.parse('${baseUrl}admin/moderation/reports/${widget.report['id']}/'),
              headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
              body: jsonEncode({'status': 'RESOLVED'})
          );

          if (response.statusCode == 200) {
              setState(() => _currentStatus = 'RESOLVED');
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marked as Resolved")));
          }
      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error updating status")));
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
                    Text("Report #${widget.report['id']}", style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    _buildInfoRow("Reporter", widget.report['reporter_username'] ?? 'Unknown'),
                    _buildInfoRow("Type", widget.report['reported_item_type']),
                    _buildInfoRow("Reported User", widget.report['reported_user'] ?? 'Unknown'),
                    _buildInfoRow("Target ID", widget.report['reported_item_id']),
                    _buildInfoRow("Date", widget.report['created_at']),
                    
                    const SizedBox(height: 24),
                    const Text("Reason & Context:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                        child: Text(widget.report['reason']),
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
                                  label: const Text("Mark as Resolved"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                                  onPressed: _resolveReport,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            const Text("Administrative Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 16),
                            if (widget.report['target_user_id'] != null) ...[
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
                  onPressed: onTap
              ),
          ),
      );
  }

  Future<void> _confirmAction(String action) async {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
              title: Text("Confirm $action?"),
              content: const Text("This action cannot be easily undone."),
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
          _performAction(action);
      }
  }

  Future<void> _performAction(String action) async {
       try {
          final token = await _storage.read(key: 'access_token');
          final response = await http.post(
              Uri.parse('${baseUrl}admin/moderation/actions/'),
              headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
              body: jsonEncode({
                  'action': action,
                  'target_user_id': widget.report['target_user_id'],
                  'reason': widget.report['reason'] // Pass report reason as context
              })
          );

          if (response.statusCode == 200) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action $action Successful")));
              // Optionally resolve the report too
              if (_currentStatus != 'RESOLVED') _resolveReport(); 
          } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action Failed: ${response.body}")));
          }
      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Error")));
      }
  }

  Widget _buildInfoRow(String label, String value) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
              children: [
                  SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                  Expanded(child: Text(value)),
              ],
          ),
      );
  }
}
