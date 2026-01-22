import 'package:flutter/material.dart';
import '../../shared_widgets/upgrade_modal.dart';
import '../events/events_screen.dart';
import '../chat/community_chat_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../../core/api/constants.dart';
import 'package:flutter/foundation.dart';

class StandardScreen extends StatefulWidget {
  const StandardScreen({super.key});

  @override
  State<StandardScreen> createState() => _StandardScreenState();
}

class _StandardScreenState extends State<StandardScreen> {
  int _communityUnreadCount = 0;
  Timer? _chatTimer;

  @override
  void initState() {
    super.initState();
    _fetchCommunityUnread();
    _chatTimer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchCommunityUnread());
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCommunityUnread() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}chat/community/'), 
        headers: {'Authorization': 'Bearer $token'}
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
           setState(() {
             _communityUnreadCount = data['unread_count'] ?? 0;
           });
        }
      }
    } catch (e) {
      if (kDebugMode) print("Error fetching community badge: $e");
    }
  }

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
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       _buildAction(context, "Community\nChat", Icons.chat_bubble_outline, 
                           () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CommunityChatScreen())),
                           badgeCount: _communityUnreadCount
                       ),
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
  
  Widget _buildAction(BuildContext context, String label, IconData icon, VoidCallback onTap, {int badgeCount = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blueGrey.shade700, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white),
              ),
              if (badgeCount > 0)
                  Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                              badgeCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                      ),
                  ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))
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
