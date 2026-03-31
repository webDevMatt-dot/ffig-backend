import 'dart:async'; // Add this for Timer (Debounce)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Needed for Velvet Rope
import '../../core/api/constants.dart';
import '../chat/chat_screen.dart'; // Needed for navigation
import '../premium/locked_screen.dart'; // Needed for navigation
import '../../core/api/admin_service.dart'; // Admin Service
import '../../core/theme/ffig_theme.dart';
import '../../shared_widgets/user_avatar.dart';
import '../../core/services/membership_service.dart';
import 'public_profile_screen.dart';
import 'widgets/filter_bottom_sheet.dart'; // Add this for Filtering

/// Displays the Community Member Directory.
///
/// **Features:**
/// - Searchable list of members.
/// - Filter by Industry and Sort by Name/Industry.
/// - "Premium Only" toggle.
/// - Admin features: Long-press to reset password.
/// - Navigates to `PublicProfileScreen` (or `ChatScreen` implicitly via profile).
class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  List<dynamic> _members = [];
  bool _isLoading = true;
  
  // --- FILTER VARIABLES ---
  String _searchQuery = "";
  List<String> _selectedIndustries = [];
  List<String> _selectedCountries = [];
  List<String> _selectedTiers = [];
  List<String> _availableCountries = [];
  String _sortBy = "name"; // Options: name, industry
  bool _premiumOnly = false;
  bool _amIAdmin = false; // Admin Checking
  String? _myUsername;
  Timer? _debounce; // To stop API calls on every keystroke

  final Map<String, String> _industryMapping = {
    'TECH': 'Technology',
    'FIN': 'Finance',
    'HLTH': 'Healthcare',
    'RET': 'Retail',
    'EDU': 'Education',
    'MED': 'Media & Arts',
    'LEG': 'Legal',
    'FASH': 'Fashion',
    'MAN': 'Manufacturing',
    'OTH': 'Other',
  };

  final Map<String, String> _tierMapping = {
    'FREE': 'Free',
    'STANDARD': 'Standard',
    'PREMIUM': 'Premium',
  };

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _fetchAvailableCountries();
    _fetchMembers();
  }

  // --- CHECK ADMIN STATUS ---
  Future<void> _checkAdminStatus() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    try {
       final response = await http.get(
        Uri.parse('${baseUrl}members/me/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
           setState(() {
             _amIAdmin = data['is_staff'] ?? false;
             _myUsername = data['username'];
           });
        }
      }
    } catch(e) {
      print("Error checking admin: $e");
    }
  }

  // --- API CALL ---
  Future<void> _fetchAvailableCountries() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}members/unique-locations/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
           setState(() => _availableCountries = data.map((e) => e.toString()).toList()..sort());
        }
      }
    } catch(e) {
      print("Error fetching locations: $e");
    }
  }

  // --- API CALL ---
  /// Fetches members from the backend based on filters.
  /// - Supports Search (`?search=query`).
  /// - Supports Industry filtering (`&industry=TECH`).
  /// - Performs client-side sorting to prioritize Premium members (`is_premium`).
  Future<void> _fetchMembers() async {
    // Avoid setting loading to true on every keystroke to prevent flickering, 
    // but useful for initial load or major filter changes.
    // For now we keep it simple.
    // setState(() => _isLoading = true); 
    
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    try {
      // Build the URL with query parameters
      String url = '${baseUrl}members/?search=$_searchQuery';
      
      // Multi-select Industries
      for (var ind in _selectedIndustries) {
        url += '&industry=$ind';
      }
      
      // Multi-select Tiers
      for (var t in _selectedTiers) {
        url += '&tier=$t';
      }
      
      // Multi-select Locations
      for (var loc in _selectedCountries) {
        url += '&location=$loc';
      }
      
      // Note: Backend typically sorts by Premium first automatically.
      // We can add extra sorting here if the backend supports it.
      
      final response = await http.get(
        Uri.parse(url),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body) as List;

        // Filter out myself
        if (_myUsername != null) {
          data = data.where((m) => m['username'] != _myUsername).toList();
        }

        // CLIENT-SIDE FILTERING (For instant "Premium Only" toggle)
        if (_premiumOnly) {
          data = data.where((m) => m['is_premium'] == true).toList();
        }

        // CLIENT-SIDE SORTING
        data.sort((a, b) {
           // Always keep Premium users at the very top
           bool aPrem = a['is_premium'] ?? false;
           bool bPrem = b['is_premium'] ?? false;
           if (aPrem && !bPrem) return -1;
           if (!aPrem && bPrem) return 1;

           // Then sort by chosen field
           if (_sortBy == 'industry') {
             return (a['industry_label'] ?? '').compareTo(b['industry_label'] ?? '');
           }
           return (a['username'] ?? '').compareTo(b['username'] ?? '');
        });

        if (mounted) {
          setState(() {
            _members = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => FilterBottomSheet(
        initialSelectedIndustries: _selectedIndustries,
        initialSelectedCountries: _selectedCountries,
        initialSelectedTiers: _selectedTiers,
        availableCountries: _availableCountries,
        onApply: (inds, countries, tiers) {
          setState(() {
            _selectedIndustries = inds;
            _selectedCountries = countries;
            _selectedTiers = tiers;
            _isLoading = true;
          });
          _fetchMembers();
        },
      ),
    );
  }

  // --- SEARCH DEBOUNCE ---
  // Waits 500ms after user stops typing before calling API
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
      });
      _fetchMembers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("COMMUNITY", style: Theme.of(context).textTheme.displaySmall?.copyWith(letterSpacing: 3.0)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false, // Clean look
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- SEARCH & FILTER BAR ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              children: [
                // 1. Search Box with Filter Icon Side-by-Side
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: const InputDecoration(
                          hintText: "SEARCH MEMBERS...",
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showFilterSheet,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (_selectedIndustries.isNotEmpty || _selectedCountries.isNotEmpty || _selectedTiers.isNotEmpty)
                                ? FfigTheme.primaryBrown
                                : Colors.transparent,
                          )
                        ),
                        child: Icon(
                          Icons.tune, 
                          color: (_selectedIndustries.isNotEmpty || _selectedCountries.isNotEmpty || _selectedTiers.isNotEmpty)
                              ? FfigTheme.primaryBrown
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // 2. Filter Chips (Horizontal List)
                if (_selectedIndustries.isNotEmpty || _selectedCountries.isNotEmpty || _selectedTiers.isNotEmpty)
                  Container(
                    height: 50,
                    margin: const EdgeInsets.only(top: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._selectedTiers.map((t) => _buildChip(t, _tierMapping[t] ?? t, () {
                          setState(() => _selectedTiers.remove(t));
                          _fetchMembers();
                        })),
                        ..._selectedIndustries.map((i) => _buildChip(i, _industryMapping[i] ?? i, () {
                          setState(() => _selectedIndustries.remove(i));
                          _fetchMembers();
                        })),
                        ..._selectedCountries.map((c) => _buildChip(c, c, () {
                          setState(() => _selectedCountries.remove(c));
                          _fetchMembers();
                        })),
                      ],
                    ),
                  ),

                // 3. Sort Dropdown (Simplified)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "FOUND ${_members.length} MEMBERS",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        dropdownColor: Theme.of(context).cardTheme.color,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                        items: const [
                          DropdownMenuItem(value: 'name', child: Text('Sort: Name')),
                          DropdownMenuItem(value: 'industry', child: Text('Sort: Industry')),
                        ],
                        onChanged: (val) {
                            setState(() => _sortBy = val!);
                            _fetchMembers(); // Re-sort list
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- THE LIST ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : RefreshIndicator(
                  onRefresh: _fetchMembers,
                  color: FfigTheme.primaryBrown,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final isPremium = member['is_premium'] ?? false;
                    final firstName = (member['first_name'] ?? member['name'] ?? '').toString().trim();
                    final lastName = (member['last_name'] ?? member['surname'] ?? '').toString().trim();
                    final fullName = [firstName, lastName].where((p) => p.isNotEmpty).join(' ');
                    final displayName = fullName.isNotEmpty ? fullName : (member['username'] ?? 'Member').toString();
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Theme.of(context).dividerTheme.color ?? Colors.grey.withOpacity(0.2))),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero, // Clean edge-to-edge
                        leading: Container(
                          decoration: BoxDecoration(
                             // Removed circle border as requested
                            shape: BoxShape.circle,
                            // border: isPremium ? Border.all(color: FfigTheme.accentBrown, width: 2) : null, 
                          ),
                          padding: const EdgeInsets.all(2), // Space for border
                          child: UserAvatar(
                            radius: 28,
                            imageUrl: () {
                              var url = member['photo'] ?? member['photo_url'];
                              if (url != null && url.toString().startsWith('/')) {
                                return '${baseUrl.replaceAll('/api/', '')}$url';
                              }
                              return url;
                            }(),
                            username: displayName,
                            firstName: member['first_name'], 
                            lastName: member['last_name'],
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName.toUpperCase(), 
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Verified Badge Logic
                            if (isPremium || member['tier'] == 'PREMIUM')
                               const Icon(Icons.verified, color: Colors.amber, size: 16)
                            else if (member['tier'] == 'STANDARD') // Assuming backend sends 'tier' now, or fallback to !isPremium but not "Free"
                               const Icon(Icons.verified, color: Colors.blue, size: 16)
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "${member['industry_label'] ?? member['industry'] ?? 'Unknown'} • ${member['location'] ?? member['country'] ?? ''}",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ),
                        trailing: const Icon(Icons.arrow_forward, size: 16),
                        onTap: () {
                            if (!MembershipService.canViewCommunityProfile) {
                                MembershipService.showUpgradeDialog(context, "Community Profiles", requiredTier: UserTier.standard);
                                return;
                            }
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => PublicProfileScreen(
                                        userId: member['user_id'],
                                        username: displayName,
                                        initialData: member,
                                    ),
                                ),
                            );
                        },
                        // ADMIN: Long Press to Reset Password
                        onLongPress: () {
                          if (_amIAdmin) {
                             _showAdminOptions(context, member);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ),
        ],
      ),
    );
  }

  void _showAdminOptions(BuildContext context, dynamic member) {
    showDialog(
      context: context, 
      builder: (context) {
        final passController = TextEditingController();
        return AlertDialog(
          title: Text("Admin: Manage ${member['username']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text("User ID: ${member['user_id']}"),
               const SizedBox(height: 16),
               TextField(
                 controller: passController,
                 decoration: const InputDecoration(labelText: "New Password", border: OutlineInputBorder()),
               )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancel")
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                 Navigator.pop(context); // Close dialog
                 final password = passController.text.trim();
                 if (password.isEmpty) return; // Silent fail if empty
                 
                 final success = await AdminService().resetUserPassword(member['user_id'], password);
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(
                       content: Text(success ? "Password Reset Successfully" : "Failed to reset"),
                       backgroundColor: success ? Colors.green : Colors.red,
                     )
                   );
                 }
              }, 
              child: const Text("RESET PASSWORD")
            )
          ],
        );
      }
    );
  }

  Widget _buildChip(String key, String label, VoidCallback onDeleted) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onDeleted,
        backgroundColor: FfigTheme.primaryBrown.withOpacity(0.1),
        side: BorderSide(color: FfigTheme.primaryBrown.withOpacity(0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
