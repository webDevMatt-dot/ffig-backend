import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../core/theme/ffig_theme.dart';
import '../../core/api/constants.dart';
import 'widgets/stories_bar.dart';
import 'widgets/vvip_feed.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
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
    // _chatTimer?.cancel();
    super.dispose();
  }

  // ... fetchCommunityUnread logic ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // We remove the AppBar to allow content to be immersive
      // DashboardScreen's AppBar is transparent, so it will overlay this.
      // StoriesBar will be at the top.
      body: Column(
        children: [
          // Spacer for Status Bar + Dashboard AppBar
          // Dashboard default AppBar height is kToolbarHeight (56).
          // Status bar height is MediaQuery.of(context).padding.top.
          // But StoriesBar needs to be interactable.
          // If we are under the AppBar, touches might be intercepted if AppBar has background.
          // But Dashboard AppBar is transparent and allows clicks through? 
          // Usually Actions consume clicks. Title area might not.
          // Ideally we add padding to push stories down below the AppBar.
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
          
          // 1. Stories
          const StoriesBar(),
          
          // 2. Feed
          const Expanded(child: VVIPFeed()),
        ],
      ),
    );
  }
}
