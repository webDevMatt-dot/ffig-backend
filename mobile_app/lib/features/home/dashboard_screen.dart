import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../community/member_list_screen.dart';
import '../community/profile_screen.dart';
import '../resources/resources_screen.dart';
import '../events/events_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../premium/locked_screen.dart';
import '../premium/premium_screen.dart';
import '../auth/login_screen.dart';
import '../chat/inbox_screen.dart';
import 'package:overlay_support/overlay_support.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../admin/admin_dashboard_screen.dart';
import '../../core/services/admin_api_service.dart';
import '../../core/services/membership_service.dart';
import '../../core/services/version_service.dart'; 
import 'package:url_launcher/url_launcher.dart';
import '../../shared_widgets/user_avatar.dart';

import '../../core/theme/ffig_theme.dart';
import 'models/hero_item.dart';
import 'models/founder_profile.dart';
import 'models/flash_alert.dart';
import 'widgets/hero_carousel.dart';
import 'widgets/founder_card.dart';
import 'widgets/flash_alert_banner.dart';
import 'widgets/news_ticker.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  List<dynamic> _events = [];
  bool _isLoading = true;
  bool _isPremium = false;
  bool _isAdmin = false;
  Timer? _notificationTimer;

  int _lastUnreadCount = 0;

  // New Data Sources (Mocked for now)
  List<HeroItem> _heroItems = [];
  FounderProfile? _founderProfile;
  FlashAlert? _flashAlert;
  List<String> _newsTickerItems = [];
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _fetchFeaturedEvents();

    _checkPremiumStatus();
    _checkPremiumStatus();
    _loadHomepageContent();
    _checkForUpdates();
    // Start the Global Listener (Checks every 10 seconds)
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkUnreadMessages();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkUnreadMessages() async {
    final token = await const FlutterSecureStorage().read(key: 'access_token');
    // Adjust URL based on device
    const String baseUrl = 'https://ffig-api.onrender.com/api/chat/unread-count/';

    // 1. Quit early if not premium
    if (!_isPremium) return; 

    try {
      final response = await http.get(Uri.parse(baseUrl), headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final int currentCount = data['unread_count'];

        // If we have MORE unread messages than before, Ding!
        if (currentCount > _lastUnreadCount) {
           final player = AudioPlayer();
           await player.play(AssetSource('sounds/ding.mp3'));
           
           // Notification removed as per user request
        }
        if (mounted) {
          setState(() {
            _lastUnreadCount = currentCount;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print("Notification Check Error: $e");
    }
  }

  Future<void> _checkPremiumStatus() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    const String baseUrl = 'https://ffig-api.onrender.com/api/members/me/';

    try {
      final response = await http.get(Uri.parse(baseUrl), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _isPremium = data['is_premium'] ?? false;
            // Also update admin status from API to be robust
            if (data.containsKey('is_staff')) {
               _isAdmin = data['is_staff'];
            }
            _userProfile = data; // Store full profile for Avatar
            // Update Global Membership State
            MembershipService.setTier(data['tier']);
            _isPremium = MembershipService.isPremium; // Keep for now, or replace usage
          });
          
          await storage.write(key: 'is_premium', value: _isPremium.toString());
          await storage.write(key: 'is_staff', value: _isAdmin.toString());
        }
      }
    } catch (e) {
      print("Error checking premium/admin status: $e");
    }
  }

  Future<void> _fetchFeaturedEvents() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');

    const String baseUrl = 'https://ffig-api.onrender.com/api/events/featured/';

    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // <--- THE KEY TO THE CASTLE
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _events = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        // Token might be expired
        print("Error fetching events: ${response.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Connection error: $e");
      setState(() => _isLoading = false);
    }

  }

  Future<void> _loadHomepageContent() async {
    final api = AdminApiService();
    try {
      // Run fetches in parallel for speed
      final results = await Future.wait([
        api.fetchItems('hero'),
        api.fetchItems('founder'),
        api.fetchItems('alerts'),
        api.fetchItems('ticker'),
      ]);

      if (mounted) {
        setState(() {
          // 1. Hero Items
          _heroItems = (results[0] as List).map((json) {
            // Ensure ID is string safely
            final Map<String, dynamic> data = Map<String, dynamic>.from(json);
            data['id'] = data['id'].toString();
            // Map 'image' (Django) to 'image_url' (Dart)
            if (data.containsKey('image')) {
                data['image_url'] = data['image']; 
            }
            return HeroItem.fromJson(data);
          }).toList();

          // 2. Founder Profile (Take the first one)
          final founders = results[1] as List;
          if (founders.isNotEmpty) {
            final Map<String, dynamic> data = Map<String, dynamic>.from(founders.first);
            data['id'] = data['id'].toString();
            // Map 'photo' (Django) to 'photo_url' (Dart)
            if (data.containsKey('photo')) {
                data['photo_url'] = data['photo'];
            }
            _founderProfile = FounderProfile.fromJson(data);
          } else {
            _founderProfile = null;
          }

          // 3. Flash Alert (Take the newest valid one)
          final alerts = results[2] as List;
          if (alerts.isNotEmpty) {
             final Map<String, dynamic> data = Map<String, dynamic>.from(alerts.last); // Last = Newest usually
             data['id'] = data['id'].toString();
             _flashAlert = FlashAlert.fromJson(data);
          } else {
            _flashAlert = null;
          }

          // 4. News Ticker
          final tickers = results[3] as List;
           // Map 'text' to string
           _newsTickerItems = tickers.map((t) => t['text'].toString()).toList();
        });
      }
    } catch (e) {
      if (kDebugMode) print("Error loading homepage content: $e");
    }
  }

  Future<void> _checkForUpdates() async {
    final updateData = await VersionService().checkUpdate();
    if (updateData != null && mounted) {
      final bool required = updateData['required'];
      final String url = updateData['url'];
      final String version = updateData['latestVersion'];

      showDialog(
        context: context,
        barrierDismissible: !required,
        builder: (context) => AlertDialog(
          title: const Text("Update Available"),
          content: Text("A new version ($version) of the app is available. Please update to continue enjoying the latest features."),
          actions: [
            if (!required)
              TextButton(child: const Text("Later"), onPressed: () => Navigator.pop(context)),
            ElevatedButton(
              onPressed: () {
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              style: ElevatedButton.styleFrom(backgroundColor: FfigTheme.primaryBrown, foregroundColor: Colors.white),
              child: const Text("Update Now"),
            )
          ],
        ),
      );
    }
  }

  // Logout Function
  Future<void> _logout() async {
    // 1. Delete the token
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    // 2. Return to Login
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final goldColor = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        title: Text("FEMALE FOUNDERS INITIATIVE GLOBAL MEMBER PORTAL", style: GoogleFonts.lato(fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // Profile Avatar (Top Right)
           IconButton(
            icon: Badge(
              isLabelVisible: _lastUnreadCount > 0,
              label: Text('$_lastUnreadCount'),
              child: const Icon(Icons.email_outlined),
            ),
            onPressed: () {
              // Reset count on tap instantly for better UX
              setState(() => _lastUnreadCount = 0); 
              if (MembershipService.canInbox) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const InboxScreen()));
              } else {
                MembershipService.showUpgradeDialog(context, "Inbox");
              }
            },
          ),

          // Profile Avatar (Top Right)
          if (_userProfile != null)
             InkWell(
               onTap: () async {
                 await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                 // Refresh profile on return in case edited
                 _checkPremiumStatus();
               },
               child: Container(
                 padding: const EdgeInsets.all(2),
                 margin: const EdgeInsets.only(right: 8),
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   border: Border.all(color: FfigTheme.primaryBrown, width: 1.5),
                 ),
                 child: UserAvatar(
                   radius: 16, // Small for AppBar
                   imageUrl: _userProfile!['photo'] ?? _userProfile!['photo_url'],
                   firstName: _userProfile!['first_name'] ?? '',
                   lastName: _userProfile!['last_name'] ?? '',
                   username: _userProfile!['username'] ?? 'M',
                 ),
               ),
             ),
        ],
      ),
      body: _selectedIndex == 0 
          ? _buildHomeTab() 
          : _selectedIndex == 1 // 1 is Events
              ? const EventsScreen()
              : _selectedIndex == 2 
                  ? const MemberListScreen() 
                  : _selectedIndex == 3
                      ? (MembershipService.isPremium ? const PremiumScreen() : const LockedScreen())
                      : _selectedIndex == 4
                          ? const ProfileScreen()
                          : _buildPlaceholder("Coming Soon"),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
           // Handle Admin Tab (Index 4 if Admin)
           if (_isAdmin && index == 4) {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
               return; // Do not switch tab
           }
           
           // RBAC: Network/Members Tab (Index 2)
           if (index == 2 && !MembershipService.canViewLimitedDirectory) {
               MembershipService.showUpgradeDialog(context, "Member Directory");
               return;
           }

           setState(() => _selectedIndex = index);
        },
        backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: FfigTheme.primaryBrown.withOpacity(0.15),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined), 
            selectedIcon: Icon(Icons.home, color: FfigTheme.textGrey),
            label: 'Home'
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined), 
            selectedIcon: Icon(Icons.calendar_month, color: FfigTheme.textGrey),
            label: 'Events'
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline), 
            selectedIcon: Icon(Icons.people, color: FfigTheme.textGrey),
            label: 'Network'
          ),
          NavigationDestination(
            icon: Icon(Icons.diamond_outlined, color: FfigTheme.primaryBrown), // Always Gold
            selectedIcon: Icon(Icons.diamond, color: FfigTheme.primaryBrown),
            label: 'VVIP'
          ),

          if (_isAdmin)
          const NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined, color: Colors.amber), 
            label: 'Admin'
          ),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async {
    // Determine if we need to show loading indicators or just refresh silently
    // For pull-to-refresh, we usually just want to await the results
    await Future.wait([
      _fetchFeaturedEvents(),
      _loadHomepageContent(),
      _checkPremiumStatus(),
    ]);
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: FfigTheme.primaryBrown,
      child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0. Flash Alert
          if (_flashAlert != null) FlashAlertBanner(alert: _flashAlert!),

          // 1. Editorial Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase(), 
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)
                ),
                const SizedBox(height: 8),
                Text(
                  "${_getGreeting()},\nFounder.", 
                  style: Theme.of(context).textTheme.displayLarge
                ),
              ],
            ),
          ),

          // 2. Hero Carousel (Replacing single static card)
          if (_heroItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: HeroCarousel(items: _heroItems),
            ),
          
          // 3. News Ticker
          if (_newsTickerItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: NewsTicker(newsItems: _newsTickerItems),
            ),

          // 4. Founder of the Week
          if (_founderProfile != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text("SPOTLIGHT", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
                ),
                FounderCard(profile: _founderProfile!),
                const SizedBox(height: 32),
              ],
            ),

          // 3. Quick Actions Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text("QUICK ACCESS", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildQuickAction(Icons.people_outline, "Members", () {
                   if (MembershipService.canViewLimitedDirectory) {
                      setState(() => _selectedIndex = 2);
                   } else {
                      MembershipService.showUpgradeDialog(context, "Member Directory");
                   }
                }),
                const SizedBox(width: 16),
                _buildQuickAction(Icons.calendar_today_outlined, "Events", () => setState(() => _selectedIndex = 1)),
                const SizedBox(width: 16),
                // _buildQuickAction(Icons.chat_bubble_outline, "Inbox", () => Navigator.push(context, MaterialPageRoute(builder: (c) => const InboxScreen()))),
                // Custom implementation for Badge support in Quick Action
                GestureDetector(
                  onTap: () {
                    setState(() => _lastUnreadCount = 0);
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const InboxScreen()));
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                             BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Badge(
                          isLabelVisible: _lastUnreadCount > 0,
                          label: Text('$_lastUnreadCount'),
                          offset: const Offset(5, -5),
                          child: const Icon(Icons.chat_bubble_outline, color: FfigTheme.pureBlack, size: 28),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("Inbox", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                 _buildQuickAction(Icons.book_outlined, "Resources", () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ResourcesScreen()))),
              ],
            ),
          ),

          const SizedBox(height: 48),

          // 4. "Trending" Horizontal List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("TRENDING NOW", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
                const Text("View All", style: TextStyle(color: FfigTheme.primaryBrown, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
              itemCount: _events.length > 1 ? _events.length - 1 : 0,
              itemBuilder: (context, index) {
                // Skip the first one since it is Featured
                final event = _events[index + 1];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailScreen(event: event))),
                    child: Container(
                      width: 160,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Image.network(event['image_url'], fit: BoxFit.cover, width: double.infinity),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    event['title'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event['date'].toString().split('T')[0],
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    ));
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.grey.withOpacity(0.1)),
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Icon(icon, color: Theme.of(context).iconTheme.color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String text) => Center(child: Text(text));
}
