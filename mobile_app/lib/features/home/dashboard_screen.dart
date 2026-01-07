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
import '../../core/theme/ffig_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchFeaturedEvents();
    _checkPremiumStatus();
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

           showSimpleNotification(
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const InboxScreen()));
                },
                child: const Text("New Message Received! Tap to check."),
              ),
              subtitle: const Text("Someone wants to connect."),
              background: Colors.amber, 
              foreground: Colors.black,
              duration: const Duration(seconds: 4),
              slideDismissDirection: DismissDirection.up,
           );
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
          if (_isAdmin)
             IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.amber),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
              },
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: _lastUnreadCount > 0,
              label: Text('$_lastUnreadCount'),
              child: const Icon(Icons.email_outlined),
            ),
            onPressed: () {
              // Reset count on tap instantly for better UX
              setState(() => _lastUnreadCount = 0); 
              if (_isPremium) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const InboxScreen()));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LockedScreen()));
              }
            },
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout))
        ],
      ),
      body: _selectedIndex == 0 
          ? _buildHomeTab() 
          : _selectedIndex == 1 // 1 is Events
              ? const EventsScreen()
              : _selectedIndex == 2 
                  ? const MemberListScreen() 
                  : _selectedIndex == 3
                      ? (_isPremium ? const PremiumScreen() : const LockedScreen())
                      : _selectedIndex == 4
                          ? const ProfileScreen()
                          : _buildPlaceholder("Coming Soon"),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: FfigTheme.primaryBrown.withOpacity(0.15),
        destinations: const [
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
          NavigationDestination(
            icon: Icon(Icons.person_outline), 
            selectedIcon: Icon(Icons.person, color: FfigTheme.textGrey),
            label: 'Profile'
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _fetchFeaturedEvents,
      color: FfigTheme.primaryBrown,
      child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // 2. Featured "Hero" Card (Netflix Style)
          if (!_isLoading && _events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailScreen(event: _events[0]))),
                child: Hero(
                  tag: 'event-${_events[0]['id']}',
                  child: Container(
                    height: 420,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      image: DecorationImage(
                        image: NetworkImage(_events[0]['image_url']),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.9),
                          ],
                          stops: const [0.4, 0.7, 1.0],
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: FfigTheme.primaryBrown,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "FEATURED EVENT",
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 10),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _events[0]['title'],
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.white70, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _events[0]['location'],
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
          const SizedBox(height: 48),

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
                _buildQuickAction(Icons.people_outline, "Members", () => setState(() => _selectedIndex = 2)),
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
