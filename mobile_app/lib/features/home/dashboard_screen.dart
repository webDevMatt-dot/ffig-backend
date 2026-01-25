import 'package:flutter/material.dart';
import 'dart:ui'; // For ImageFilter
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../community/member_list_screen.dart';
import '../community/profile_screen.dart';
import '../resources/resources_screen.dart';
import '../events/events_screen.dart';
import '../events/event_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../premium/locked_screen.dart';
import '../premium/premium_screen.dart';
import '../premium/standard_screen.dart';
import '../auth/login_screen.dart';
import '../settings/settings_screen.dart';
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
import 'widgets/founder_card.dart';
import '../../core/api/constants.dart';

import '../../core/theme/ffig_theme.dart';
import 'models/hero_item.dart';
import 'models/founder_profile.dart';
import 'models/flash_alert.dart';
import 'widgets/hero_carousel.dart';
import 'widgets/founder_card.dart';
import 'widgets/flash_alert_banner.dart';
import 'widgets/bento_tile.dart';
import '../../shared_widgets/glass_nav_bar.dart';
import 'widgets/news_ticker.dart';

import '../../shared_widgets/moderation_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  // ... (Keep existing state variables)
  int _selectedIndex = 0;
  List<dynamic> _events = [];
  bool _isLoading = true;
  bool _isPremium = false;
  bool _isAdmin = false;
  Timer? _notificationTimer;

  int _lastUnreadCount = 0;
  int _lastNotificationId = 0;

  // New Data Sources (Mocked for now)
  List<HeroItem> _heroItems = [];
  FounderProfile? _founderProfile;
  FlashAlert? _flashAlert;
  List<String> _newsTickerItems = [];
  Map<String, dynamic>? _userProfile;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchEvents(); // Fetches all events, not just featured
    _checkMobileWeb(); // Check for mobile web
    _checkPremiumStatus();
    _checkPremiumStatus();
    _loadHomepageContent();
    // Start the Global Listener (Checks every 10 seconds)
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkUnreadMessages();
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // _checkForUpdates(); // Removed
    }
  }

  Future<void> _checkUnreadMessages() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');

    // 1. Check Chat Messages (Existing)
    if (_isPremium) {
      try {
        final response = await http.get(
          Uri.parse('${baseUrl}chat/unread-count/'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final int currentCount = data['unread_count'];
          if (currentCount > _lastUnreadCount) {
            // Updated count - no sound needed as Push Notification handles alerting
            // and this prevents "startup" dings for existing unread messages.
          }
          if (mounted) setState(() => _lastUnreadCount = currentCount);
        }
      } catch (e) {
        /* ignore */
      }
    }

    // 2. Check Admin Notifications (New)
    if (_isAdmin) {
      _checkAdminNotifications(token);
    }
  }

  Future<void> _checkAdminNotifications(String? token) async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}notifications/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final latest = data.first; // Created at desc
          final int id = latest['id'];

          // If new notification found
          if (id > _lastNotificationId) {
            _lastNotificationId = id;

            // Check persisted ID first
            const storage = FlutterSecureStorage();
            final savedIdStr = await storage.read(key: 'last_notif_id');
            final savedId = int.tryParse(savedIdStr ?? '0') ?? 0;

            if (id > savedId) {
              _lastNotificationId = id;
              await storage.write(key: 'last_notif_id', value: id.toString());

              // Show Popup (Non-disturbing)
              showSimpleNotification(
                Text(
                  latest['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  latest['message'],
                  style: const TextStyle(color: Colors.white),
                ),
                background: FfigTheme.primaryBrown,
                duration: const Duration(seconds: 5),
                slideDismissDirection: DismissDirection.up,
                trailing: Builder(
                  builder: (context) {
                    return TextButton(
                      onPressed: () {
                        OverlaySupportEntry.of(context)?.dismiss();
                        _markNotificationRead(id, token);
                      },
                      child: const Text(
                        "Mark Read",
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
              );

              // Play sound for Admin too
              final player = AudioPlayer();
              await player.play(AssetSource('sounds/ding.mp3'));
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print("Admin Note Error: $e");
    }
  }

  Future<void> _markNotificationRead(int id, String? token) async {
    try {
      await http.post(
        Uri.parse('${baseUrl}notifications/$id/read/'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      /* ignore */
    }
  }

  Future<void> _checkPremiumStatus() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');

    // Guest Mode
    if (token == null) {
      if (mounted) {
        setState(() {
          _isPremium = false;
          _isAdmin = false;
          _userProfile = null;
          MembershipService.setTier("free"); // Default to free/guest
          MembershipService.isAdmin = false;
        });
      }
      return;
    }

    const String endpoint = '${baseUrl}members/me/';

    try {
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {'Authorization': 'Bearer $token'},
      );
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
            MembershipService.isAdmin = _isAdmin;
            _isPremium =
                MembershipService.isPremium; // Keep for now, or replace usage
          });

          await storage.write(key: 'is_premium', value: _isPremium.toString());
          await storage.write(key: 'is_staff', value: _isAdmin.toString());

          // Check Moderation Status
          _checkModerationStatus();
        }
      } else {
        // ERROR HANDLER
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Session Expired or Failed"),
              content: Text(
                "Server returned status ${response.statusCode}.\nPlease log in again.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print("Error checking premium/admin status: $e");
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Profile Load Error"),
            content: Text("Failed to load user data: $e"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  void _checkModerationStatus() {
    if (_userProfile == null) return;

    // 1. Blocked
    if (_userProfile!['is_blocked'] == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const ModerationDialog(type: ModerationType.block),
      );
      return;
    }

    // 2. Suspended
    if (_userProfile!['is_suspended'] == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ModerationDialog(
          type: ModerationType.suspend,
          message:
              "Your account is suspended until ${_userProfile!['suspension_expiry'] ?? 'review completed'}.",
        ),
      );
      return;
    }

    // 3. Warning (Show only once per session or always? Assuming always until admin clears it)
    if (_userProfile!['admin_notice'] != null &&
        _userProfile!['admin_notice'].toString().isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => ModerationDialog(
          type: ModerationType.warning,
          message: _userProfile!['admin_notice'],
        ),
      );
    }
  }

  Future<void> _fetchEvents() async {
    // Renamed from _fetchFeaturedEvents
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');

    const String endpoint = '${baseUrl}events/';

    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    try {
      final response = await http.get(Uri.parse(endpoint), headers: headers);

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

  List<dynamic> _getUpcomingEventsForTrending() {
    final now = DateTime.now();
    return _events.where((event) {
      try {
        final eventDate = DateTime.parse(event['date']);
        return eventDate.isAfter(now);
      } catch (_) {
        return false;
      }
    }).toList();
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
          _heroItems = (results[0]).map((json) {
            // Ensure ID is string safely
            final Map<String, dynamic> data = Map<String, dynamic>.from(json);
            data['id'] = data['id'].toString();
            if (data['image'] != null) {
               var url = data['image'].toString();
               if (url.isNotEmpty && url != "null") {
                 final domain = baseUrl.replaceAll('/api/', '');
                 if (url.startsWith('/')) {
                   data['image_url'] = '$domain$url';
                 } else {
                   data['image_url'] = url;
                 }
               }
            }
            return HeroItem.fromJson(data);
          }).toList();

          // 2. Founder Profile (Take the first one)
          final founders = results[1];
          if (founders.isNotEmpty) {
            final Map<String, dynamic> data = Map<String, dynamic>.from(
              founders.first,
            );
            data['id'] = data['id'].toString();
            final domain = baseUrl.replaceAll('/api/', '');
            // The serializer returns photo_url directly, but ensure it's properly formatted
            if (data['photo_url'] != null && data['photo_url'] != 'null') {
              var url = data['photo_url'].toString();
              if (url.isNotEmpty && !url.startsWith('http')) {
                // If it's a relative path, make it absolute
                if (url.startsWith('/')) {
                  data['photo_url'] = '$domain$url';
                }
              }
            } else if (data['photo'] != null) {
              // Fallback: if photo field exists (raw upload), use that
              var url = data['photo'].toString();
              if (url.isNotEmpty && url != "null") {
                if (url.startsWith('/')) {
                  data['photo_url'] = '$domain$url';
                } else {
                  data['photo_url'] = url;
                }
              }
            }
            _founderProfile = FounderProfile.fromJson(data);
          } else {
            _founderProfile = null;
          }

          // 3. Flash Alert (Take the newest valid one)
          final alerts = results[2];
          if (alerts.isNotEmpty) {
            final Map<String, dynamic> data = Map<String, dynamic>.from(
              alerts.last,
            ); // Last = Newest usually
            data['id'] = data['id'].toString();
            _flashAlert = FlashAlert.fromJson(data);
          } else {
            _flashAlert = null;
          }

          // 4. News Ticker
          final tickers = results[3];
          // Map 'text' to string
          _newsTickerItems = tickers.map((t) => t['text'].toString()).toList();
        });
      }
    } catch (e) {
      if (kDebugMode) print("Error loading homepage content: $e");
    }
  }

  // Update check removed as per user request
  // Future<void> _checkForUpdates() async { ... }

  void _showLoginDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Login Required"),
        content: const Text("Please login or sign up to access this feature."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
                Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FfigTheme.primaryBrown,
              foregroundColor: Colors.white,
            ),
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }

  // Logout Function
  Future<void> _logout() async {
    // 1. Delete the token
    const storage = FlutterSecureStorage();
    await storage.deleteAll();

    // 2. Return to Homepage (Guest Mode)
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false, // Remove all previous routes
      );
    }
  }

  void _checkMobileWeb() {
    // If on Web AND (Android OR iOS)
    if (kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      // Wait a beat so it doesn't clash with other dialogs
      Future.delayed(const Duration(seconds: 2), () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Get the Full Experience"),
            content: const Text(
              "For the best experience, including Push Notifications and Offline Access, download our mobile app.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Stay on Web"),
              ),
              ElevatedButton(
                onPressed: () {
                  // Navigate to Play Store
                  launchUrl(
                    Uri.parse(
                      'https://play.google.com/store/apps/details?id=com.ffiglobal.mobile_app',
                    ),
                    mode: LaunchMode.externalApplication,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: FfigTheme.primaryBrown,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Download App"),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() => _selectedIndex = 0);
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Scaffold(
      extendBody: true, // Allow body to flow behind the floating nav bar
      appBar: AppBar(
        title: Text(
          "MEMBER PORTAL",
          style: GoogleFonts.inter(
            fontSize: 14,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            ),
          ),
        ),
        actions: [
          // Settings (Logged Out) or Inbox (Logged In)
          if (_userProfile == null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            )
          else
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InboxScreen(),
                    ),
                  );
                } else {
                  MembershipService.showUpgradeDialog(context, "Inbox");
                }
              },
            ),

          // Profile Avatar or Login Button (Top Right)
          if (_userProfile != null)
            InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
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
                  imageUrl:
                      _userProfile!['photo'] ?? _userProfile!['photo_url'],
                  firstName: _userProfile!['first_name'] ?? '',
                  lastName: _userProfile!['last_name'] ?? '',
                  username: _userProfile!['username'] ?? 'M',
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const LoginScreen()),
                ),
                child: const Text(
                  "Login",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: FfigTheme.primaryBrown,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        children: [
          _buildHomeTab(),
          const EventsScreen(),
          const MemberListScreen(),
          MembershipService.isPremium
              ? const PremiumScreen()
              : (MembershipService.isStandard
                    ? const StandardScreen()
                    : const LockedScreen()),
          if (_isAdmin)
            const AdminDashboardScreen(), // Allow swiping to Admin if Admin
        ],
      ),
      bottomNavigationBar: GlassNavBar(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          // Handle Admin Tab Logic or Restrictions first
          if (!_isAdmin && index == 4) return;

          // RBAC: Network/Members Tab (Index 2)
          if (index == 2) {
            if (_userProfile == null) {
              _showLoginDialog();
              return;
            }
            if (!MembershipService.canViewLimitedDirectory) {
              MembershipService.showUpgradeDialog(context, "Member Directory");
              return;
            }
          }

          // RBAC: VVIP (Index 3)
          if (index == 3 && _userProfile == null) {
            _showLoginDialog();
            return;
          }

          // Animate to page
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        items: [
          GlassNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: "Home",
          ),
          GlassNavItem(
            icon: Icons.calendar_month_outlined,
            activeIcon: Icons.calendar_month,
            label: "Events",
          ),
          GlassNavItem(
            icon: Icons.people_outline,
            activeIcon: Icons.people,
            label: "Network",
          ),
          GlassNavItem(
            icon: Icons.diamond_outlined,
            activeIcon: Icons.diamond,
            label: "VVIP",
          ),
          if (_isAdmin)
            GlassNavItem(
              icon: Icons.admin_panel_settings_outlined,
              activeIcon: Icons.admin_panel_settings,
              label: "Admin",
            ),
        ],
      ),
    ),
    );
  }

  Future<void> _onRefresh() async {
    // Determine if we need to show loading indicators or just refresh silently
    // For pull-to-refresh, we usually just want to await the results
    await Future.wait([
      _fetchEvents(), // Changed from _fetchFeaturedEvents
      _loadHomepageContent(),
      _checkPremiumStatus(),
    ]);
  }

  int _getUpcomingCount() {
    final now = DateTime.now();
    // Normalize to start of day to include events happening "today"
    final today = DateTime(now.year, now.month, now.day);
    return _events.where((event) {
      try {
        final eventDate = DateTime.parse(event['date']);
        // We want events that are on or after today (ignoring time)
        final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
        return !eventDay.isBefore(today);
      } catch (_) {
        return false;
      }
    }).length;
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
                    DateFormat(
                      'EEEE, MMM d',
                    ).format(DateTime.now()).toUpperCase(),
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${_getGreeting()},\nFounder.",
                    style: Theme.of(context).textTheme.displayLarge,
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

            // 2. BENTO GRID LAYOUT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // ROW 1: STATUS & EVENTS
                  Row(
                    children: [
                      // Membership Status Tile
                      Expanded(
                        child: BentoTile(
                          title: _isPremium
                              ? "Premium"
                              : (MembershipService.isStandard
                                  ? "Standard"
                                  : "Free"),
                          subtitle: "Membership",
                          height: 160,
                          color: _isPremium
                              ? FfigTheme.primaryBrown
                              : const Color(0xFF161B22),
                          isGlass: true, // Glass effect for consistency
                          icon: Icon(
                            Icons.verified_user,
                            color: _isPremium ? Colors.white : Colors.grey,
                            size: 24,
                          ),
                          onTap: () {
                            // TODO: Navigate to Membership details
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Events Quick Access
                      Expanded(
                        child: BentoTile(
                          title: "Events",
                          subtitle: "${_getUpcomingCount()} Upcoming",
                          height: 160,
                          isGlass: true, // Glass effect
                          icon: const Icon(
                            Icons.calendar_month,
                            color: FfigTheme.accentBrown,
                            size: 24,
                          ),
                          onTap: () {
                            setState(() => _selectedIndex = 1);
                            _pageController.jumpToPage(1); // Jump to Events Tab
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ROW 2: MAIN FEATURE (FIND FOUNDER)
                  BentoTile(
                    title: "Network",
                    subtitle: "Connect with Global Founders",
                    height: 180,
                    isGlass: true,
                    icon: const Icon(
                      Icons.search,
                      color: FfigTheme.accentBrown,
                      size: 28,
                    ),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: FfigTheme.primaryBrown,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Find a Founder",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    onTap: () {
                      if (_userProfile == null) {
                        _showLoginDialog();
                        return;
                      }
                      if (MembershipService.canViewLimitedDirectory) {
                        setState(() => _selectedIndex = 2);
                        _pageController.jumpToPage(2); // Jump to Network Tab
                      } else {
                        MembershipService.showUpgradeDialog(
                          context,
                          "Member Directory",
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // ROW 3: FOUNDER SPOTLIGHT (If available)
                  if (_founderProfile != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: InkWell(
                        onTap: () {
                           showDialog(
                             context: context,
                             builder: (context) => Dialog(
                               backgroundColor: Colors.transparent,
                               insetPadding: const EdgeInsets.all(16),
                               child: FounderCard(profile: _founderProfile!),
                             ),
                           );
                        },
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          height: 300, 
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withOpacity(0.3),
                                 blurRadius: 20,
                                 offset: const Offset(0, 10),
                               ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Full Bleed Image
                                Image.network(
                                  _founderProfile!.photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c,e,s) => Container(color: Colors.grey[900], child: const Icon(Icons.person, color: Colors.white, size: 50)),
                                ),
                                
                                // Gradient Overlay (Subtle)
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black87],
                                      stops: [0.5, 1.0],
                                    ),
                                  ),
                                ),

                                // Top Badge: Spotlight
                                Positioned(
                                  top: 20,
                                  left: 20,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        color: Colors.white.withOpacity(0.1),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.star, color: Color(0xFFD4AF37), size: 16), // Gold star
                                            const SizedBox(width: 8),
                                            Text(
                                              "FOUNDER OF THE WEEK",
                                              style: GoogleFonts.inter(
                                                color: Colors.white, 
                                                fontSize: 12, 
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.0
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Bottom Details
                                Positioned(
                                  bottom: 24,
                                  left: 24,
                                  right: 24,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _founderProfile!.name,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _founderProfile!.businessName.toUpperCase(),
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFD4AF37), // Gold
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _founderProfile!.country,
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (_founderProfile != null) const SizedBox(height: 16),

                  // ROW 4: RESOURCES & INBOX
                  Row(
                    children: [
                      Expanded(
                        child: BentoTile(
                          title: "Inbox",
                          subtitle: _lastUnreadCount > 0
                              ? "$_lastUnreadCount Unread"
                              : "No messages",
                          height: 140,
                          isGlass: true, // Glass effect for hover/light mode
                          icon: Icon(
                            Icons.chat_bubble_outline,
                            color: _lastUnreadCount > 0
                                ? FfigTheme.primaryBrown
                                : Colors.grey,
                          ),
                          onTap: () {
                            if (_userProfile == null) {
                              _showLoginDialog();
                              return;
                            }
                            setState(() => _lastUnreadCount = 0);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => const InboxScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: BentoTile(
                          title: "Resources",
                          subtitle: "Library",
                          height: 140,
                          isGlass: true, // Glass effect for hover/light mode
                          icon: const Icon(Icons.book, color: Colors.grey),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => const ResourcesScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  Text(
                    "TRENDING NOW",
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: Colors.grey),
                  ),
                  const Text(
                    "View All",
                    style: TextStyle(
                      color: FfigTheme.primaryBrown,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 320, // Increased
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: 20, // Reduced bottom padding as it's a fixed height container
                ), 
                itemCount: _getUpcomingEventsForTrending().length > 2 ? 2 : _getUpcomingEventsForTrending().length,
                itemBuilder: (context, index) {
                  final upcomingEvents = _getUpcomingEventsForTrending();
                  if (index >= upcomingEvents.length) return const SizedBox.shrink();
                  final event = upcomingEvents[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailScreen(event: event),
                        ),
                      ),
                      child: Container(
                        width: 200, // Reduced width
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                                child: Image.network(
                                  event['image_url'],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      () {
                                          try {
                                              final dt = DateTime.parse(event['date']);
                                              return DateFormat('dd-MM-yyyy').format(dt);
                                          } catch (_) {
                                              return event['date'].toString();
                                          }
                                      }(),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
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
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
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
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    Theme.of(context).dividerTheme.color ??
                    Colors.grey.withOpacity(0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Theme.of(context).iconTheme.color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String text) => Center(child: Text(text));
}
