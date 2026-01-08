import 'package:flutter/material.dart';
import '../../shared_widgets/upgrade_modal.dart';
import '../community/member_list_screen.dart';
import '../events/events_screen.dart';

class StandardScreen extends StatelessWidget {
  const StandardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("COMMUNITY LOUNGE"),
        backgroundColor: Colors.blueGrey, // Standard color, not Gold
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                   const Icon(Icons.check_circle_outline, color: Colors.white, size: 50),
                   const SizedBox(height: 16),
                   const Text("STANDARD MEMBER", style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Text("You have unlocked Community Access.", style: TextStyle(color: Colors.grey.shade400), textAlign: TextAlign.center),
                   const SizedBox(height: 24),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                     children: [
                       _buildAction(context, "Directory", Icons.people, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MemberListScreen()))),
                       _buildAction(context, "Events", Icons.calendar_today, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const EventsScreen()))),
                     ],
                   )
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Upsell Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD4AF37), width: 2), // Gold Border
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
              child: Column(
                children: [
                  const Text("UNLOCK VVIP", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  const Text("Take your membership to the next level.", textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  _buildLockRow("Marketing Center"),
                  _buildLockRow("Direct Messaging (DMs)"),
                  _buildLockRow("Manage Business Profile"),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                       showDialog(context: context, builder: (c) => const UpgradeModal(message: "Upgrade to Premium to unlock VVIP features, including Direct Messaging and Marketing Tools."));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("UPGRADE TO PREMIUM", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildAction(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blueGrey.shade700, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white))
        ],
      ),
    );
  }

  Widget _buildLockRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.lock, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}
