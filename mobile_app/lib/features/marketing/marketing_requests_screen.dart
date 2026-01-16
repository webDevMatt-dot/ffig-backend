import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../../core/services/admin_api_service.dart';
import '../../core/theme/ffig_theme.dart';
import 'dart:ui'; // For BackdropFilter
import 'create_marketing_request_screen.dart';

class MarketingRequestsScreen extends StatefulWidget {
  const MarketingRequestsScreen({super.key});

  @override
  State<MarketingRequestsScreen> createState() =>
      _MarketingRequestsScreenState();
}

class _MarketingRequestsScreenState extends State<MarketingRequestsScreen> {
  bool _isLoading = false;

  Future<void> _submitRequest(String type) async {
    await Navigator.push(context, MaterialPageRoute(builder: (c) => CreateMarketingRequestScreen(type: type)));
    // Refresh if needed? The main screen doesn't show list, it just shows "My Requests" placeholder.
    // If I implemented list fetching, I'd call it here.
    setState(() {}); // Trigger refresh if we had list
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
            const Text(
              "My Requests",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                "No active requests.",
                style: TextStyle(color: Colors.grey),
              ),
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
