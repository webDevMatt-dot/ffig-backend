import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/api/constants.dart';
import '../../../core/theme/ffig_theme.dart';
import 'report_detail_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  List<dynamic> _reports = [];
  bool _isLoading = true;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse('${baseUrl}admin/moderation/reports/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _reports = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Content Reports")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _reports.isEmpty 
            ? const Center(child: Text("No reports found."))
            : ListView.separated(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120), // Added padding for nav bar
                itemCount: _reports.length,
                separatorBuilder: (c, i) => const Divider(),
                itemBuilder: (context, index) {
                   final report = _reports[index];
                   final status = report['status'];
                   final isResolved = status == 'RESOLVED';
                   
                   return ListTile(
                     title: Text("Reason: ${report['reason']}", maxLines: 1, overflow: TextOverflow.ellipsis),
                     subtitle: RichText(
                         text: TextSpan(
                             style: DefaultTextStyle.of(context).style,
                             children: [
                                 TextSpan(text: "Reported by: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
                                 TextSpan(text: "${report['reporter_username'] ?? 'Unknown'}\n"),
                                 TextSpan(text: "Reported User: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
                                 TextSpan(text: "${report['reported_user'] ?? 'Unknown'}"),
                                 TextSpan(text: "\nStatus: $status", style: TextStyle(color: isResolved ? Colors.green : Colors.orange)),
                             ],
                         ),
                     ),
                     trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                     tileColor: isResolved ? null : Colors.red.withOpacity(0.05),
                     onTap: () async {
                         await Navigator.push(context, MaterialPageRoute(builder: (context) => ReportDetailScreen(report: report)));
                         _fetchReports(); // Refresh on return
                     },
                   );
                },
              ),
    );
  }
}
