import 'package:flutter/material.dart';
import '../../core/services/admin_api_service.dart';
import '../../core/theme/ffig_theme.dart';
// For BackdropFilter
import 'create_marketing_request_screen.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/constants.dart';
import '../../core/utils/dialog_utils.dart';
import 'edit_marketing_request_screen.dart';

class MarketingRequestsScreen extends StatefulWidget {
  const MarketingRequestsScreen({super.key});

  @override
  State<MarketingRequestsScreen> createState() =>
      _MarketingRequestsScreenState();
}

class _MarketingRequestsScreenState extends State<MarketingRequestsScreen> {
  bool _isLoading = false;
  List<dynamic> _myRequests = [];
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchMyRequests();
  }

  Future<void> _fetchMyRequests() async {
    setState(() => _isLoading = true);
    final token = await _storage.read(key: 'access_token');
    
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}members/me/marketing/list/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _myRequests = jsonDecode(response.body);
          });
        }
      } else {
        if (mounted) DialogUtils.showError(context, "Error", "Failed to load requests");
      }
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Error", e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRequest(String type) async {
    await Navigator.push(context, MaterialPageRoute(builder: (c) => CreateMarketingRequestScreen(type: type)));
    _fetchMyRequests(); // Refresh listing after return
  }

  Future<void> _editRequest(dynamic request) async {
     await Navigator.push(context, MaterialPageRoute(builder: (c) => EditMarketingRequestScreen(requestData: request)));
     _fetchMyRequests();
  }

  Future<void> _deleteRequest(int id) async {
    final confirmed = await DialogUtils.showConfirmation(context, "Delete Request", "Are you sure you want to delete this request?");
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await AdminApiService().deleteMarketingRequest(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request deleted")));
      _fetchMyRequests();
    } catch (e) {
      if (mounted) DialogUtils.showError(context, "Error", e.toString());
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Marketing Center")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBenefitCard(
              "Business Ad",
              "Launch high-visibility ads in the community feed.",
              Icons.campaign,
              () => _submitRequest("Ad"),
            ),
            const SizedBox(height: 16),
            _buildBenefitCard(
              "Promotion",
              "Submit a special offer or discount for members.",
              Icons.discount,
              () => _submitRequest("Promotion"),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "My Requests",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchMyRequests)
              ],
            ),
            const SizedBox(height: 16),
            _isLoading 
               ? const Center(child: CircularProgressIndicator())
               : _myRequests.isEmpty 
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          "No active requests.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _myRequests.length,
                      itemBuilder: (context, index) {
                        return _buildRequestItem(_myRequests[index]);
                      },
                    ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestItem(dynamic req) {
    final status = req['status'] ?? 'PENDING';
    Color statusColor = Colors.orange;
    if (status == 'APPROVED') statusColor = Colors.green;
    if (status == 'REJECTED') statusColor = Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
           width: 50, height: 50,
           color: Colors.grey[200],
           child: req['image'] != null 
              ? Image.network(req['image'], fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.broken_image))
              : const Icon(Icons.image, color: Colors.grey),
        ),
        title: Text(req['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(req['type'] ?? 'AD'),
            Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: FfigTheme.primaryBrown),
              onPressed: () => _editRequest(req),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteRequest(req['id']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitCard(
    String title,
    String desc,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.amber, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
        trailing: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: const Text("Create"),
        ),
      ),
    );
  }
}
