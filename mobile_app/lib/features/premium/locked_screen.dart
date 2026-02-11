import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class LockedScreen extends StatelessWidget {
  const LockedScreen({super.key});

  // Your specific payment links
  /// Payment URL for Standard Plan
  final String _standardPlanUrl = "https://www.femalefoundersinitiative.com/plans-pricing/payment/eyJpbnRlZ3JhdGlvbkRhdGEiOnt9LCJwbGFuSWQiOiJhZDQwMzVkZi04MzA0LTRhMjctODZlNi0yY2ExMDNlNTNlNWIiLCJjaGVja291dEZsb3dJZCI6Ijk3ZjRiMjcwLTA5ZTUtNDIxOS1iYzNkLWE3ZjIxNWMwNTJjMCJ9";
  
  /// Payment URL for Premium Plan
  final String _premiumPlanUrl = "https://www.femalefoundersinitiative.com/plans-pricing/payment/eyJpbnRlZ3JhdGlvbkRhdGEiOnt9LCJwbGFuSWQiOiI5YWQ4OTNlNi03ZTIzLTQ2NTAtYWY1OS1lMWNiMTU5NDA5OTQiLCJjaGVja291dEZsb3dJZCI6IjAwMTZmN2QxLTc2MzgtNDgyOS1hODVjLTU5MTYwYTdjMjYxNyJ9";

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open payment page")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium, size: 60, color: Color(0xFFD4AF37)), // Gold
            const SizedBox(height: 16),
            Text(
              "Unlock the Network",
              style: GoogleFonts.playfairDisplay(fontSize: 30, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "Direct messaging is exclusively available to our members. Choose a plan to start connecting.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),

            // Option 1: Standard Plan
            _buildPlanCard(
              context,
              title: "STANDARD MEMBER",
              price: "\$200 / year",
              features: ["Global Networking", "Member Directory Access", "Basic Resources"],
              buttonText: "JOIN STANDARD",
              isRecommended: false,
              onTap: () => _launchURL(context, _standardPlanUrl),
            ),

            const SizedBox(height: 20),

            // Option 2: Premium Plan (Highlighted)
            _buildPlanCard(
              context,
              title: "PREMIUM MEMBER",
              price: "\$400 / year",
              features: ["Direct Messaging (DM)", "VIP Event Access", "Investor Introductions", "Premium Resource Vault"],
              buttonText: "GO PREMIUM",
              isRecommended: true,
              onTap: () => _launchURL(context, _premiumPlanUrl),
            ),

            const SizedBox(height: 40),
            Text(
              "Already upgraded? Pull to refresh your profile.",
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, {
    required String title,
    required String price,
    required List<String> features,
    required String buttonText,
    required bool isRecommended,
    required VoidCallback onTap,
  }) {
    final goldColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isRecommended ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isRecommended ? Colors.black : Colors.grey[300]!, width: 2),
        boxShadow: isRecommended 
            ? [BoxShadow(color: goldColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))] 
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (isRecommended)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: goldColor, borderRadius: BorderRadius.circular(20)),
                child: const Text("RECOMMENDED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            Text(title, style: TextStyle(color: isRecommended ? Colors.white : Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text(price, style: TextStyle(color: isRecommended ? Colors.grey[300] : Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 24),
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Align to top for multi-line
                children: [
                  Icon(Icons.check_circle, color: goldColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded( // Fix 1: Wrap Text in Expanded to prevent overflow
                    child: Text(f, style: TextStyle(color: isRecommended ? Colors.white : Colors.black87, height: 1.3)),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecommended ? goldColor : Colors.grey[100],
                  foregroundColor: isRecommended ? Colors.black : Colors.black,
                  elevation: 0,
                ),
                child: FittedBox( // Fix 2: Ensure button text fits
                  fit: BoxFit.scaleDown,
                  child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
