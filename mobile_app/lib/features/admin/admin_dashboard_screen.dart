import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/admin_api_service.dart';
import 'user_management_screen.dart';
import 'resource_management_screen.dart';
// Import Management Screens
import 'home_management/manage_hero_screen.dart';
import 'home_management/manage_founder_screen.dart';
import 'home_management/manage_alerts_screen.dart';
import 'home_management/manage_ticker_screen.dart';
import 'events_management/manage_events_screen.dart';
import 'approvals/admin_approvals_screen.dart';
import 'analytics/admin_analytics_screen.dart';
import 'moderation/admin_reports_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _reportsCount = 0;
  int _approvalsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotificationCounts();
  }

  Future<void> _fetchNotificationCounts() async {
    try {
      final api = AdminApiService();
      // Fetch Reports -> Count PENDING
      try {
        final reports = await api.fetchItems('moderation/reports');
        // If the endpoint returns raw list, filter. If it's already filtered, just length.
        // Assuming endpoint returns all, filter for pending/open statuses if applicable.
        // AdminReportsScreen logic suggests 'status' field.
        final pendingReports = reports.where((r) => r['status'] != 'RESOLVED').length;
        if (mounted) setState(() => _reportsCount = pendingReports);
      } catch (e) {
        debugPrint("Error fetching reports count: $e");
      }

      // Fetch Approvals -> Count Pending Business + Marketing
      try {
        final biz = await api.fetchBusinessApprovals();
        final mkt = await api.fetchMarketingApprovals();
        
        final pendingBiz = biz.where((item) => item['status'] == 'PENDING').length;
        final pendingMkt = mkt.where((item) => item['status'] == 'PENDING').length;
        
        if (mounted) setState(() => _approvalsCount = pendingBiz + pendingMkt);
      } catch (e) {
        debugPrint("Error fetching approvals count: $e");
      }

    } catch (e) {
       // Silent fail
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if wide screen (Desktop/Web)
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text("ADMIN DASHBOARD", style: GoogleFonts.lato(letterSpacing: 2, fontWeight: FontWeight.bold)),
      ),
      body: isWide 
        ? _buildWideLayout(context) 
        : _buildMobileLayout(context),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
      children: [
        _buildSectionHeader(context, "Homepage Content"),
         _buildAdminTile(
          context,
          icon: Icons.campaign_outlined,
          title: "Flash Alerts",
          subtitle: "Create time-sensitive banners",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageAlertsScreen())),
        ),
        _buildAdminTile(
          context,
          icon: Icons.view_carousel_outlined,
          title: "Hero Carousel",
          subtitle: "Manage rotating hero banners",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageHeroScreen())),
        ),
         _buildAdminTile(
          context,
          icon: Icons.newspaper_outlined,
          title: "News Ticker",
          subtitle: "Update scrolling news items",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageTickerScreen())),
        ),
        _buildAdminTile(
          context,
          icon: Icons.star_border,
          title: "Founder Spotlight",
          subtitle: "Update the Founder of the Week",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageFounderScreen())),
        ),
        _buildAdminTile(
          context,
          icon: Icons.event,
          title: "Manage Events",
          subtitle: "Create, edit, and ticket events",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageEventsScreen())),
        ),
        _buildAdminTile(
          context,
          icon: Icons.library_books_outlined,
          title: "Manage Resources",
          subtitle: "Magazines, Masterclasses, Newsletters",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ResourceManagementScreen())),
        ),
        
        const SizedBox(height: 24),
        _buildSectionHeader(context, "Community & Moderation"),
        
        _buildAdminTile(
          context,
          icon: Icons.flag_outlined, 
          title: "Reports (Moderation)",
          subtitle: "Review reported users & content",
          notificationCount: _reportsCount,
          onTap: () async {
             await Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminReportsScreen()));
             _fetchNotificationCounts(); // Refresh on return
          },
        ),

        const SizedBox(height: 24),
        _buildSectionHeader(context, "General Management"),
        _buildAdminTile(
          context,
          icon: Icons.people_outline,
          title: "Manage Users",
          subtitle: "View, edit, and delete users",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen())),
        ),

        const SizedBox(height: 24),
        _buildSectionHeader(context, "Approvals & Analytics"),

        _buildAdminTile(
          context,
          icon: Icons.rule, 
          title: "Approvals Center",
          subtitle: "Review Business Profiles & Ads",
          notificationCount: _approvalsCount,
          onTap: () async {
             await Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminApprovalsScreen()));
             _fetchNotificationCounts();
          },
        ),
        _buildAdminTile(
          context,
          icon: Icons.analytics_outlined, 
          title: "Analytics",
          subtitle: "View platform growth & stats",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAnalyticsScreen())),
        ),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Welcome, Admin.", style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 32),
          
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 1.5,
              children: [
                 _buildWideTile(
                  context, 
                  "Manage Users", 
                  Icons.people_outline, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen()))
                ),
                 _buildWideTile(
                  context, 
                  "Resources", 
                  Icons.library_books_outlined, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ResourceManagementScreen()))
                ),
                 _buildWideTile(
                  context, 
                  "Events", 
                  Icons.event, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageEventsScreen()))
                ),
                 _buildWideTile(
                   context, 
                   "Reports", 
                   Icons.flag_outlined, 
                   () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminReportsScreen())),
                   notificationCount: _reportsCount
                 ),
                 _buildWideTile(
                   context, 
                   "Approvals", 
                   Icons.rule, 
                   () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminApprovalsScreen())),
                   notificationCount: _approvalsCount
                 ),
                 _buildWideTile(
                   context, 
                   "Analytics", 
                   Icons.analytics_outlined, 
                   () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAnalyticsScreen()))
                 ),
                 _buildWideTile(
                  context, 
                  "Hero Carousel", 
                  Icons.view_carousel_outlined, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageHeroScreen()))
                ),
                 _buildWideTile(
                  context, 
                  "Founder Spotlight", 
                  Icons.star_border, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageFounderScreen()))
                ),
                 _buildWideTile(
                  context, 
                  "Flash Alerts", 
                  Icons.campaign_outlined, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageAlertsScreen()))
                ),
                 _buildWideTile(
                  context, 
                  "News Ticker", 
                  Icons.newspaper_outlined, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageTickerScreen()))
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
    );
  }

  Widget _buildAdminTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap, int notificationCount = 0}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(icon, color: Theme.of(context).brightness == Brightness.dark 
              ? Theme.of(context).colorScheme.secondary 
              : Theme.of(context).primaryColor),
        ),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (notificationCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                child: Text("$notificationCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
          ],
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildWideTile(BuildContext context, String title, IconData icon, VoidCallback onTap, {int notificationCount = 0}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: Theme.of(context).brightness == Brightness.dark 
                    ? Theme.of(context).colorScheme.secondary 
                    : Theme.of(context).primaryColor),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            if (notificationCount > 0)
              Positioned(
                 top: 16,
                 right: 16,
                 child: Container(
                   padding: const EdgeInsets.all(6),
                   decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                   child: Text("$notificationCount", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                 ),
              )
          ],
        ),
      ),
    );
  }
}
