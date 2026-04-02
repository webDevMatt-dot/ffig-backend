import 'dart:async'; // Add this for Timer (Debounce)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Needed for Velvet Rope
import '../../core/api/constants.dart';
import '../../core/api/admin_service.dart'; // Admin Service
import '../../core/theme/ffig_theme.dart';
import '../../shared_widgets/user_avatar.dart';
import '../../core/services/membership_service.dart';
import 'public_profile_screen.dart';
import 'widgets/filter_bottom_sheet.dart'; // Add this for Filtering

class CommunityPollOption {
  CommunityPollOption({required this.id, required this.label, this.votes = 0});

  final int id;
  final String label;
  int votes;

  factory CommunityPollOption.fromJson(Map<String, dynamic> json) {
    return CommunityPollOption(
      id: json['id'],
      label: json['label'],
      votes: json['votes'] ?? 0,
    );
  }
}

class CommunityPoll {
  CommunityPoll({
    required this.id,
    required this.question,
    required this.options,
    this.selectedIndex,
  });

  final int id;
  final String question;
  final List<CommunityPollOption> options;
  int? selectedIndex;

  factory CommunityPoll.fromJson(Map<String, dynamic> json) {
    return CommunityPoll(
      id: json['id'],
      question: json['question'],
      options: (json['options'] as List).map((o) => CommunityPollOption.fromJson(o)).toList(),
      selectedIndex: json['selected_index'],
    );
  }
}

class CommunityQuizQuestion {
  CommunityQuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
    this.selectedIndex,
  });

  final int id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  int? selectedIndex;

  factory CommunityQuizQuestion.fromJson(Map<String, dynamic> json) {
    return CommunityQuizQuestion(
      id: json['id'],
      prompt: json['prompt'],
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correct_index'],
      explanation: json['explanation'] ?? '',
      selectedIndex: json['selected_index'],
    );
  }
}

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
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedIndustries = [];
  List<String> _selectedCountries = [];
  List<String> _selectedTiers = [];
  List<String> _availableCountries = [];
  String _sortBy = "name"; // Options: name, industry
  bool _premiumOnly = false;
  bool _amIAdmin = false; // Admin Checking
  String? _myUsername;
  Timer? _debounce; // To stop API calls on every keystroke
  int _communityMode = 0; // 0=members, 1=polls, 2=quizzes
  List<CommunityPoll> _polls = [];
  List<CommunityQuizQuestion> _quizQuestions = [];
  bool _isPollsLoading = false;
  bool _isQuizzesLoading = false;

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
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _fetchAvailableCountries();
    _fetchMembers();
    _fetchPolls();
    _fetchQuizzes();
  }

  int get _unansweredPollsCount => _polls.where((p) => p.selectedIndex == null).length;
  int get _unansweredQuizzesCount => _quizQuestions.where((q) => q.selectedIndex == null).length;

  Future<void> _fetchPolls() async {
    setState(() => _isPollsLoading = true);
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}community/polls/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _polls = data.map((json) => CommunityPoll.fromJson(json)).toList();
            _isPollsLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isPollsLoading = false);
    }
  }

  Future<void> _fetchQuizzes() async {
    setState(() => _isQuizzesLoading = true);
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}community/quizzes/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _quizQuestions = data.map((json) => CommunityQuizQuestion.fromJson(json)).toList();
            _isQuizzesLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isQuizzesLoading = false);
    }
  }

  Future<void> _votePoll(int pollId, int optionId) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}community/polls/$pollId/vote/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'option_id': optionId}),
      );
      if (response.statusCode == 200) {
        _fetchPolls(); // Refresh state
      }
    } catch (e) {
      print("Vote error: $e");
    }
  }

  Future<void> _submitQuiz(int quizId, int selectedIndex) async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}community/quizzes/$quizId/submit/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'selected_index': selectedIndex}),
      );
      if (response.statusCode == 200) {
        _fetchQuizzes(); // Refresh state
      }
    } catch (e) {
      print("Quiz error: $e");
    }
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
    setState(() => _searchQuery = query);
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
          const SizedBox(height: 8),
          _buildModeSelector(),
          Expanded(child: _buildActiveCommunityView()),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    final pollsLabel = _unansweredPollsCount > 0 ? 'Polls ($_unansweredPollsCount)' : 'Polls';
    final quizzesLabel = _unansweredQuizzesCount > 0 ? 'Quizzes ($_unansweredQuizzesCount)' : 'Quizzes';
    final labels = ['Members', pollsLabel, quizzesLabel];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color?.withOpacity(0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = _communityMode == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _communityMode = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? FfigTheme.primaryBrown : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveCommunityView() {
    if (_communityMode == 1) return _buildPollsView();
    if (_communityMode == 2) return _buildQuizzesView();
    return _buildMembersView();
  }

  Widget _buildMembersView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: "SEARCH MEMBERS...",
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged("");
                                },
                              )
                            : null,
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
                        ),
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
                        _fetchMembers();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            decoration: const BoxDecoration(shape: BoxShape.circle),
                            padding: const EdgeInsets.all(2),
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
                              if (isPremium || member['tier'] == 'PREMIUM')
                                const Icon(Icons.verified, color: Colors.amber, size: 16)
                              else if (member['tier'] == 'STANDARD')
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
                          onLongPress: () {
                            if (_amIAdmin) _showAdminOptions(context, member);
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPollsView() {
    if (_isPollsLoading && _polls.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_polls.isEmpty) return const Center(child: Text("No polls available at the moment."));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      itemCount: _polls.length,
      itemBuilder: (context, index) {
        final poll = _polls[index];
        final totalVotes = poll.options.fold<int>(0, (sum, option) => sum + option.votes);
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(poll.question, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...List.generate(poll.options.length, (optionIndex) {
                  final option = poll.options[optionIndex];
                  final percentage = totalVotes == 0 ? 0 : ((option.votes / totalVotes) * 100).round();
                  final selected = poll.selectedIndex == optionIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _votePoll(poll.id, option.id),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? FfigTheme.primaryBrown : Colors.grey.shade300),
                          color: selected ? FfigTheme.primaryBrown.withOpacity(0.08) : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(option.label)),
                            Text("$percentage%"),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Text("Votes: $totalVotes", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuizzesView() {
    if (_isQuizzesLoading && _quizQuestions.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_quizQuestions.isEmpty) return const Center(child: Text("No quizzes available at the moment."));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      itemCount: _quizQuestions.length,
      itemBuilder: (context, index) {
        final quiz = _quizQuestions[index];
        final hasAnswered = quiz.selectedIndex != null;
        final answeredCorrectly = quiz.selectedIndex == quiz.correctIndex;
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Q${index + 1}: ${quiz.prompt}", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...List.generate(quiz.options.length, (optionIndex) {
                  final selected = quiz.selectedIndex == optionIndex;
                  final isCorrect = optionIndex == quiz.correctIndex;
                  Color borderColor = Colors.grey.shade300;
                  if (hasAnswered && isCorrect) borderColor = Colors.green;
                  if (selected && hasAnswered && !isCorrect) borderColor = Colors.red;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: hasAnswered
                          ? null
                          : () => _submitQuiz(quiz.id, optionIndex),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(quiz.options[optionIndex]),
                      ),
                    ),
                  );
                }),
                if (hasAnswered) ...[
                  const SizedBox(height: 6),
                  Text(
                    answeredCorrectly ? "Correct ✅" : "Not quite ❌",
                    style: TextStyle(
                      color: answeredCorrectly ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (quiz.explanation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(quiz.explanation, style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ],
            ),
          ),
        );
      },
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
