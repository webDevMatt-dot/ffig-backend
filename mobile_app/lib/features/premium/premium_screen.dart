import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../core/theme/ffig_theme.dart';
import '../../core/api/constants.dart';
import 'widgets/stories_bar.dart';
import 'widgets/stories_bar.dart';
import 'widgets/vvip_feed.dart';
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
  // We can keep these for future "Menu" integration if needed
  // int _communityUnreadCount = 0;
  // Timer? _chatTimer;

  @override
  void initState() {
    super.initState();
    // _fetchCommunityUnread();
    // _chatTimer = Timer.periodic(const Duration(seconds: 10), (timer) => _fetchCommunityUnread());
  }

  @override
  void dispose() {
    _pageController.dispose();
    // _chatTimer?.cancel();
    super.dispose();
  }

  // ... fetchCommunityUnread logic ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      // We remove the AppBar to allow content to be immersive
      // DashboardScreen's AppBar is transparent, so it will overlay this.
      // StoriesBar will be at the top.
      body: Stack(
        children: [
          VVIPFeed(controller: _pageController),

          // VVIP Creation Button (Top Left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12, // Align with Dashboard AppBar
            left: 16,
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                  double opacity = 1.0;
                  try {
                      if (_pageController.hasClients && _pageController.position.haveDimensions) {
                           final offset = _pageController.page ?? 0;
                           opacity = (1 - offset).clamp(0.0, 1.0);
                      }
                  } catch (_) {}
                  
                  if (opacity == 0) return const SizedBox.shrink();

                  return Opacity(
                      opacity: opacity,
                      child: IgnorePointer(
                          ignoring: opacity == 0,
                          child: child
                      )
                  );
              },
              child: FloatingActionButton.small(
                backgroundColor: FfigTheme.primaryBrown,
                heroTag: 'vvip_create_btn',
                onPressed: _showCreationMenu,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreationMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Create Content",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.white),
                title: const Text("Reel (Ad / Promotion)", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateMarketingRequestScreen(type: 'Ad'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_toggle_off, color: FfigTheme.primaryBrown),
                title: const Text("Story", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateStoryScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
