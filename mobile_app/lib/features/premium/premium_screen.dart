import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../marketing/business_profile_editor_screen.dart';
import '../marketing/marketing_requests_screen.dart';
import '../chat/community_chat_screen.dart';
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  List<dynamic> _vipPerks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPremiumData();
  }

  Future<void> _fetchPremiumData() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    const String baseUrl = 'https://ffig-api.onrender.com/api/premium/';

    try {
      final response = await http.get(Uri.parse(baseUrl), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
           setState(() {
             _vipPerks = data['exclusive_data'];
             _isLoading = false;
           });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("VIP LOUNGE"), backgroundColor: Colors.amber, foregroundColor: Colors.black),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.black,
                  child: Column(
                    children: [
                      const Text("EXCLUSIVE ACCESS", style: TextStyle(color: Colors.amber, letterSpacing: 1.5, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildHeaderAction(context, "Community\nChat", Icons.forum, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CommunityChatScreen()))),
                          _buildHeaderAction(context, "Manage\nBusiness", Icons.business, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BusinessProfileEditorScreen()))),
                          _buildHeaderAction(context, "Marketing\nCenter", Icons.campaign, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MarketingRequestsScreen()))),
                        ],
                      ),
                    ],
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: _vipPerks.length,
                  itemBuilder: (context, index) {
                    return Card(
                      color: Colors.black87,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: const Icon(Icons.star, color: Colors.amber),
                        title: Text(_vipPerks[index], style: const TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildHeaderAction(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.black, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12))
        ],
      ),
    );
  }
}
