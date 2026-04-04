import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../core/services/admin_api_service.dart';
import '../../../core/theme/ffig_theme.dart';
import 'poll_form_screen.dart';

class ManagePollsScreen extends StatefulWidget {
  const ManagePollsScreen({super.key});

  @override
  State<ManagePollsScreen> createState() => _ManagePollsScreenState();
}

class _ManagePollsScreenState extends State<ManagePollsScreen> {
  final _api = AdminApiService();
  List<dynamic> _polls = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPolls();
  }

  Future<void> _fetchPolls() async {
    try {
      final polls = await _api.fetchPollsAdmin();
      if (mounted) {
        setState(() {
          _polls = polls;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePoll(int id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool confirmed = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? FfigTheme.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon & Title
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 36),
                ),
                const SizedBox(height: 24),
                Text(
                  "DELETE POLL?",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 20,
                    color: isDark ? Colors.white : FfigTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "This action is permanent. All collected votes and analytics for this poll will be erased.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Actions
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      confirmed = true;
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text("PERMANENTLY DELETE", style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                  },
                  child: Text("CANCEL", style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1.5)),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed) {
      try {
        await _api.deletePoll(id);
        _fetchPolls();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text("Poll Successfully Removed"),
               backgroundColor: Colors.red[700],
             )
           );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("MANAGE POLLS", style: GoogleFonts.lato(letterSpacing: 2, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const PollFormScreen()));
              _fetchPolls();
            },
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchPolls,
              child: _polls.isEmpty
                  ? const Center(child: Text("No polls created yet."))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _polls.length,
                      itemBuilder: (context, index) {
                        final poll = _polls[index];
                        final expiry = DateTime.parse(poll['expires_at']);
                        final isExpired = expiry.isBefore(DateTime.now());

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(poll['question'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text("Expires: ${DateFormat('MMM d, h:mm a').format(expiry)}"),
                                if (isExpired) 
                                  const Text("EXPIRED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () async {
                                    await Navigator.push(context, MaterialPageRoute(builder: (context) => PollFormScreen(poll: poll)));
                                    _fetchPolls();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deletePoll(poll['id']),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
