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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FfigTheme.scaffoldDark : Colors.grey[50], // Premium light bg
      appBar: AppBar(
        title: Text(
          "MANAGE POLLS", 
          style: GoogleFonts.inter(
            letterSpacing: 2, 
            fontWeight: FontWeight.w900,
            fontSize: 14,
          )
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: FfigTheme.primaryBrown),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      itemCount: _polls.length,
                      itemBuilder: (context, index) {
                        return _buildPollBentoTile(_polls[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildPollBentoTile(Map<String, dynamic> poll) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expiry = DateTime.parse(poll['expires_at']);
    final isExpired = expiry.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          if (!isDark) BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  poll['question'],
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.4,
                    color: isDark ? Colors.white : FfigTheme.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isExpired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "EXPIRED",
                    style: GoogleFonts.inter(
                      color: Colors.red,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                "Expires: ${DateFormat('MMM d, h:mm a').format(expiry)}",
                style: GoogleFonts.inter(
                  color: Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  _buildPollAction(
                    icon: Icons.edit_outlined,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => PollFormScreen(poll: poll)));
                      _fetchPolls();
                    },
                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey[400]!,
                  ),
                  const SizedBox(width: 8),
                  _buildPollAction(
                    icon: Icons.delete_outline_rounded,
                    onTap: () => _deletePoll(poll['id']),
                    color: Colors.red[400]!,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPollAction({required IconData icon, required VoidCallback onTap, required Color color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
