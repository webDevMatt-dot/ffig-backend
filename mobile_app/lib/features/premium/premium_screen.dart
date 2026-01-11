import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:async'; // For Timer exception
import '../marketing/business_profile_editor_screen.dart';
import '../../core/theme/ffig_theme.dart';
import '../marketing/marketing_requests_screen.dart';
import '../chat/community_chat_screen.dart';
import '../../core/api/constants.dart';
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  List<dynamic> _vipPerks = [];
  bool _isLoading = true;
  int _communityUnreadCount = 0;
  Timer? _chatTimer;

  @override
  void initState() {
    super.initState();
    _fetchPremiumData();
    _fetchCommunityUnread();
    _chatTimer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchCommunityUnread());
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPremiumData() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    const String endpoint = '${baseUrl}premium/';

    try {
      final response = await http.get(Uri.parse(endpoint), headers: {'Authorization': 'Bearer $token'});
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("VIP LOUNGE"), 
        // Use theme defaults automatically
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: FfigTheme.accentBrown)) 
        : SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  color: isDark ? const Color(0xFF121212) : FfigTheme.primaryBrown.withOpacity(0.05),
                  width: double.infinity,
                  child: Column(
                    children: [
                      const Icon(Icons.diamond_outlined, size: 60, color: FfigTheme.accentBrown),
                      const SizedBox(height: 12),
                      const Text("EXCLUSIVE ACCESS", style: TextStyle(color: FfigTheme.accentBrown, letterSpacing: 2.0, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderAction(context, "Community\nChat", Icons.forum, 
                             () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CommunityChatScreen())),
                             badgeCount: _communityUnreadCount
                          ),
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
                      // Card theme handles color automatically
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: const Icon(Icons.star, color: FfigTheme.accentBrown),
                        title: Text(_vipPerks[index]),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildHeaderAction(BuildContext context, String label, IconData icon, VoidCallback onTap, {int badgeCount = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, 
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FfigTheme.accentBrown.withOpacity(0.3))
                    ),
                    child: Icon(icon, color: FfigTheme.accentBrown, size: 30),
                ),
                if (badgeCount > 0)
                    Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                                badgeCount.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                        ),
                    ),
            ],
          ),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.w600, fontSize: 12))
        ],
      ),
    );
  }
}
