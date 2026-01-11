import 'package:flutter/material.dart';
import '../../core/services/admin_api_service.dart';

class MarketingRequestsScreen extends StatefulWidget {
  const MarketingRequestsScreen({super.key});

  @override
  State<MarketingRequestsScreen> createState() => _MarketingRequestsScreenState();
}

class _MarketingRequestsScreenState extends State<MarketingRequestsScreen> {
  bool _isLoading = false;

  Future<void> _submitRequest(String type) async {
    final titleController = TextEditingController();
    final linkController = TextEditingController();
    
    await showDialog(context: context, builder: (context) => AlertDialog(
      title: Text("Submit $type"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title/Headline")),
          TextField(controller: linkController, decoration: const InputDecoration(labelText: "Link URL")),
          const SizedBox(height: 8),
          const Text("Images can be uploaded after initial submission approval.", style: TextStyle(fontSize: 12, color: Colors.grey))
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            setState(() => _isLoading = true);
            try {
              await AdminApiService().createMarketingRequest({
                'type': type == 'Ad' ? 'AD' : 'PROMOTION',
                'title': titleController.text,
                'link': linkController.text,
              });
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Submitted!")));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
            } finally {
              if (mounted) setState(() => _isLoading = false);
            }
          },
          child: const Text("Submit"),
        )
      ],
    ));
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
             _buildBenefitCard("Business Ad", "Launch high-visibility ads in the community feed.", Icons.campaign, () => _submitRequest("Ad")),
             const SizedBox(height: 16),
             _buildBenefitCard("Promotion", "Submit a special offer or discount for members.", Icons.discount, () => _submitRequest("Promotion")),
             const SizedBox(height: 32),
             const Text("My Requests", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
             const SizedBox(height: 16),
             const Center(child: Text("No active requests.", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitCard(String title, String desc, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.amber, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
        trailing: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
          child: const Text("Create"),
        ),
      ),
    );
  }
}
