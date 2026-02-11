import 'package:flutter/material.dart';
import '../../core/theme/ffig_theme.dart';
import 'widgets/vvip_feed.dart';
import '../marketing/create_marketing_request_screen.dart';
import 'create_story_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showCreationMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22), // Obsidian lighter
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, 
                  height: 4, 
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))
                ),
                const Text(
                  "Create Content",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: FfigTheme.primaryBrown.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.history_edu, color: FfigTheme.primaryBrown),
                  ),
                  title: const Text("Add to Story", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Share a quick update (24h)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const CreateStoryScreen()));
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.video_library, color: Colors.cyan),
                  ),
                  title: const Text("Post VVIP Reel / Ad", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Promote your business or share value", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const CreateMarketingRequestScreen(type: 'Ad')));
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          // 1. The Feed (Background)
          VVIPFeed(controller: _pageController),

          // 2. The "Instagram-Style" Header
          // We wrap it in an AnimatedBuilder to fade it out when scrolling down (optional)
          // or keep it fixed. Let's keep it fixed for easy access.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 10,
                left: 16,
                right: 16
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0D1117).withOpacity(0.9), 
                    const Color(0xFF0D1117).withOpacity(0.0)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // THE MANAGER BUTTON (+)
                  GestureDetector(
                    onTap: _showCreationMenu,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.2))
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 24),
                    ),
                  ),

                  // Title (Optional)
                  const Text(
                    "MEMBER PORTAL",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0
                    ),
                  ),

                  // Placeholder for balance (or Chat icon)
                  const SizedBox(width: 40), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
