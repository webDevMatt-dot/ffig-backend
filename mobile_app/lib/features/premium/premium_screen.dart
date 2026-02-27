import 'package:flutter/material.dart';
import '../../core/theme/ffig_theme.dart';
import 'widgets/vvip_feed.dart';

/// The main screen for VVIP/Premium members.
///
/// **Purpose:**
/// - Displays the exclusive `VVIPFeed`.
/// - Acts as the container for the VVIP tab in the `DashboardScreen`.
/// - The header and creation menu logic are handled by the parent `DashboardScreen`.
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

  @override
  Widget build(BuildContext context) {
     return VVIPFeed(controller: _pageController);
  }
}

