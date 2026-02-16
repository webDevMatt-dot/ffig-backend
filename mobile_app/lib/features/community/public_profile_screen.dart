import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/constants.dart';
import '../../core/theme/ffig_theme.dart';
import '../../shared_widgets/user_avatar.dart';
import '../chat/chat_screen.dart';
import '../../core/services/membership_service.dart';

class PublicProfileScreen extends StatefulWidget {
  final int? userId;
  final String? username;
  final Map<String, dynamic>? initialData; // Optimization

  const PublicProfileScreen({super.key, this.userId, this.username, this.initialData});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _profileData = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _profileData = widget.initialData!;
      _isLoading = false;
    } else {
      _fetchProfile();
    }
  }

  Future<void> _fetchProfile() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    // We need an endpoint to get a specific member. 
    // Assuming backend supports: /api/members/<id>/ OR filter by username
    // Since I don't know if /members/PK/ exists, I'll try to find them in the list or assume a specific endpoint exists.
    // Usually ViewSets provide a detail view at /members/{id}/.
    
    if (widget.userId == null && widget.username == null) {
        setState(() => _errorMessage = "No user specified");
        return;
    }

    String url;
    if (widget.userId != null) {
        url = '${baseUrl}members/${widget.userId}/';
    } else {
        // Fallback: This might likely fail if backend doesn't support lookup by username directlly
        // But for ChatScreen where we only have username, we might need to search.
        // Let's assume we can get it via search if ID is missing (which is rare if we refactor Chat properly)
        url = '${baseUrl}members/?search=${widget.username}';
    }

    try {
      final response = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            final data = jsonDecode(response.body);
            if (data is List) {
                // It was a search result
                if (data.isNotEmpty) {
                    _profileData = data.first;
                } else {
                    _errorMessage = "User not found";
                }
            } else {
                _profileData = data;
            }
            _isLoading = false;
          });
        }
      } else {
         if (mounted) {
           setState(() {
             _isLoading = false;
             _errorMessage = "Failed to load profile (${response.statusCode})";
         });
         }
      }
    } catch (e) {
      print(e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Connection error";
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (_errorMessage != null) return Scaffold(appBar: AppBar(), body: Center(child: Text(_errorMessage!)));

    final photoUrl = _profileData['photo'] ?? _profileData['photo_url'];
    final firstName = _profileData['first_name'] ?? '';
    final lastName = _profileData['last_name'] ?? '';
    final fullName = (firstName + ' ' + lastName).trim();
    final username = _profileData['username'] ?? widget.username ?? 'Member';
    final industry = _profileData['industry_label'] ?? _profileData['industry'] ?? 'General';
    final location = _profileData['location'] ?? 'Global';
    final bio = _profileData['bio'] ?? '';
    final userId = _profileData['user_id'] ?? _profileData['id'];

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
               // Avatar
               Hero(
                 tag: 'avatar_$username',
                 child: Container(
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

               const SizedBox(height: 16),
               
               // Actions
               ElevatedButton.icon(
                   onPressed: () {
                     if (userId == null) return;
                     if (!MembershipService.canMessageCommunityMember) {
                         MembershipService.showUpgradeDialog(context, "Direct Messaging", requiredTier: UserTier.premium);
                         return;
                     }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            recipientId: userId,
                            recipientName: username,
                          ),
                        ),
                      );
                   },
                   icon: const Icon(Icons.chat_bubble_outline),
                   label: const Text("Message"),
                   style: ElevatedButton.styleFrom(
                       backgroundColor: FfigTheme.primaryBrown,
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
                   ),
               ),
               
               const SizedBox(height: 24),
               
               // Info Cards
               _buildInfoCard(Icons.work_outline, "Industry", industry),
               _buildInfoCard(Icons.location_on_outlined, "Location", location),
               
               if (bio.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Align(alignment: Alignment.centerLeft, child: Text("ABOUT", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey))),
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
                    textAlign: TextAlign.start,
                  ),
               ],
          ],
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
