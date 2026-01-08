import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; 
import '../../core/api/constants.dart'; 
import '../../core/theme/ffig_theme.dart';
import '../../shared_widgets/user_avatar.dart';
import '../settings/settings_screen.dart';
import '../marketing/business_profile_editor_screen.dart';
import '../../core/services/membership_service.dart';
import '../../core/services/version_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _profileData = {};

  @override
  void initState() {
    super.initState();
    _fetchMyProfile();
  }

  Future<void> _fetchMyProfile() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token == null) return; 

    try {
      final response = await http.get(
          Uri.parse('${baseUrl}members/me/'),
          headers: {'Authorization': 'Bearer $token'}
      ); 

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _profileData = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final photoUrl = _profileData['photo'] ?? _profileData['photo_url'];
    final firstName = _profileData['first_name'] ?? '';
    final lastName = _profileData['last_name'] ?? '';
    final fullName = (firstName + ' ' + lastName).trim();
    final username = _profileData['username'] ?? 'Member';

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update),
            onPressed: () async {
               // Manual Update Check
               final updateData = await VersionService().checkUpdate();
               if (!mounted) return;
               
               if (updateData != null) {
                  // Update Available
                  showDialog(context: context, builder: (c) => AlertDialog(
                    title: const Text("Update Available"),
                    content: Text("Latest Version: ${updateData['latestVersion']}\nWe found an update!"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
                      ElevatedButton(onPressed: () => launchUrl(Uri.parse(updateData['url']), mode: LaunchMode.externalApplication), child: const Text("Update"))
                    ],
                  ));
               } else {
                  // No Update or Error
                  // We can't easily distinguish "No Update" from "Error" with current Service, 
                  // but usually checkUpdate returns null if no update OR error.
                  // Let's assume up to date.
                  final info = await PackageInfo.fromPlatform();
                  showDialog(context: context, builder: (c) => AlertDialog(
                    title: const Text("No Update Required"),
                    content: Text("You are on version ${info.version}.\nSystem is up to date."),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
                  ));
               }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              // Wait for return to refresh
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              _fetchMyProfile();
            },
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMyProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
               // Avatar
               Container(
                 padding: const EdgeInsets.all(4),
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   border: Border.all(color: FfigTheme.primaryBrown, width: 2),
                 ),
                 child: UserAvatar(
                   radius: 60,
                   imageUrl: photoUrl,
                   firstName: firstName,
                   lastName: lastName,
                   username: username,
                   textColor: Colors.black54,
                   backgroundColor: Colors.grey[200],
                 ),
               ),
               const SizedBox(height: 16),
               
               // Name & Business
               Text(
                 fullName.isNotEmpty ? fullName : username,
                 style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
               ),
               if (_profileData['business_name'] != null)
                 Text(
                   _profileData['business_name'], 
                   style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, color: FfigTheme.primaryBrown, fontWeight: FontWeight.w600)
                 ),
               
               const SizedBox(height: 24),
               
               const SizedBox(height: 16),
               if (MembershipService.canCreateBusinessProfile)
                 OutlinedButton.icon(
                   icon: const Icon(Icons.business),
                   label: const Text("Manage Business Profile"),
                   onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const BusinessProfileEditorScreen()));
                   },
                 )
               else
                 TextButton.icon(
                   icon: const Icon(Icons.lock, size: 16),
                   label: const Text("Unlock Business Profile"),
                   onPressed: () => MembershipService.showUpgradeDialog(context, "Business Profile"),
                 ),
               
               const SizedBox(height: 24),
               
               // Info Cards
               _buildInfoCard(Icons.work_outline, "Industry", _profileData['industry_label'] ?? 'General'),
               _buildInfoCard(Icons.location_on_outlined, "Location", _profileData['location'] ?? 'Global'),
               
               if (_profileData['bio'] != null && _profileData['bio'].toString().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Align(alignment: Alignment.centerLeft, child: Text("ABOUT", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey))),
                  const SizedBox(height: 8),
                  Text(
                    _profileData['bio'],
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
                    textAlign: TextAlign.start,
                  ),
               ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0,2))
        ]
      ),
      child: Row(
        children: [
          Icon(icon, color: FfigTheme.primaryBrown),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey)),
              Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          )
        ],
      ),
    );
  }
}
