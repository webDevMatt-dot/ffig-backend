import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../core/api/constants.dart';
import '../../../../core/utils/dialog_utils.dart';

class AdminApprovalsScreen extends StatelessWidget {
  const AdminApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Approvals Center", 
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)
          ),
          bottom: TabBar(
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
            indicatorColor: FfigTheme.accentBrown,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: "Business Profiles"),
              Tab(text: "Marketing Requests"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BusinessApprovalsList(),
            _MarketingApprovalsList(),
          ],
        ),
      ),
    );
  }
}

class _BusinessApprovalsList extends StatefulWidget {
    const _BusinessApprovalsList();
    @override
    State<_BusinessApprovalsList> createState() => _BusinessApprovalsListState();
}

class _BusinessApprovalsListState extends State<_BusinessApprovalsList> {
    final _api = AdminApiService(); 
    List<dynamic> _items = [];
    bool _isLoading = true;
    String _searchQuery = "";

    @override 
    void initState() { super.initState(); _load(); }

    Future<void> _load() async {
        try {
            final data = await _api.fetchBusinessApprovals();
            // Filter locally for now if API returns all
            final pending = data.where((i) => i['status'] == 'PENDING').toList();
            if (mounted) setState(() { _items = pending; _isLoading = false; });
        } catch (e) {
            if (mounted) setState(() => _isLoading = false);
        }
    }

    Future<void> _decide(int id, String status) async {
        if (status == 'REJECTED') {
            final reason = await _showDeclineReasonDialog(context);
            if (reason == null) return; // Cancelled
            await _api.updateBusinessStatus(id, status, feedback: reason);
        } else {
            await _api.updateBusinessStatus(id, status); 
        }
        _load();
    }

    @override
    Widget build(BuildContext context) {
        if (_isLoading) return const Center(child: CircularProgressIndicator());
        
        final filteredItems = _items.where((item) {
            if (_searchQuery.isEmpty) return true;
            final name = (item['company_name'] ?? '').toString().toLowerCase();
            final desc = (item['description'] ?? '').toString().toLowerCase();
            final q = _searchQuery.toLowerCase();
            return name.contains(q) || desc.contains(q);
        }).toList();

        if (_items.isEmpty) return Center(child: Text("No pending business profiles.", style: GoogleFonts.inter(color: Colors.grey)));
        
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search pending businesses...",
                  hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16)
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: filteredItems.isEmpty 
                  ? Center(child: Text("No matches found.", style: GoogleFonts.inter(color: Colors.grey)))
                  : ListView.builder(
                    itemCount: filteredItems.length,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showBusinessDetails(context, item),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item['company_name'] ?? 'Unknown', 
                                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
                                              maxLines: 1, overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                            child: Text("PENDING", style: GoogleFonts.inter(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w800)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item['description'] ?? '', 
                                        maxLines: 2, overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey, height: 1.4),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.close, size: 16),
                                            label: Text("REJECT", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(color: Colors.red),
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => _decide(item['id'], 'REJECTED'),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.check, size: 16),
                                            label: Text("APPROVE", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => _decide(item['id'], 'APPROVED'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ),
                        );
                    }
                ),
            ),
          ],
        );
    }

    void _showBusinessDetails(BuildContext context, dynamic item) {
        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (c) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // HEADER
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item['company_name'] ?? 'Business Details', 
                                  style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                        
                        Flexible(
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Text("ABOUT BUSINESS", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2)),
                                      const SizedBox(height: 12),
                                      Text(
                                        item['description'] ?? 'No description provided.', 
                                        style: GoogleFonts.inter(fontSize: 15, height: 1.6),
                                      ),
                                      const SizedBox(height: 24),
                                      
                                      Text("CONTACT & INFO", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2)),
                                      const SizedBox(height: 16),
                                      if (item['website'] != null && item['website'].toString().isNotEmpty) ...[
                                          _detailRow(Icons.language, "Website", item['website']),
                                      ],
                                      if (item['industry'] != null && item['industry'].toString().isNotEmpty) ...[
                                          _detailRow(Icons.category_outlined, "Industry", item['industry']),
                                      ],
                                      if (item['contact_email'] != null && item['contact_email'].toString().isNotEmpty) ...[
                                          _detailRow(Icons.email_outlined, "Email", item['contact_email']),
                                      ],
                                      const SizedBox(height: 32),
                                  ]
                              )
                          ),
                        ),
                    ]
                )
            )
        );
    }
}

Widget _detailRow(IconData icon, String label, String val) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: Row(
      children: [
        Icon(icon, size: 20, color: FfigTheme.accentBrown),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700)),
            Text(val, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    ),
  );
}

class _MarketingApprovalsList extends StatefulWidget {
    const _MarketingApprovalsList();
    @override
    State<_MarketingApprovalsList> createState() => _MarketingApprovalsListState();
}

class _MarketingApprovalsListState extends State<_MarketingApprovalsList> {
    final _api = AdminApiService();
    List<dynamic> _items = [];
    bool _isLoading = true;
    String _searchQuery = "";

    @override 
    void initState() { super.initState(); _load(); }

    Future<void> _load() async {
        try {
            final data = await _api.fetchMarketingApprovals();
            // Show ALL, but maybe sort PENDING first
            data.sort((a,b) {
                if (a['status'] == 'PENDING' && b['status'] != 'PENDING') return -1;
                if (a['status'] != 'PENDING' && b['status'] == 'PENDING') return 1;
                return 0; 
            });
            if (mounted) setState(() { _items = data; _isLoading = false; });
        } catch (e) {
            if (mounted) setState(() => _isLoading = false);
        }
    }


    Future<void> _decide(int id, String status) async {
        String? reason;
        if (status == 'REJECTED') {
            reason = await _showDeclineReasonDialog(context);
            if (reason == null) return; // Cancelled
        }
        
        setState(() => _isLoading = true);
        try {
            await _api.updateMarketingStatus(id, status, feedback: reason);
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Request marked as $status"), backgroundColor: Colors.green)
                );
            }
            await _load();
        } catch (e) {
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
                );
                // Reload anyway to reset state
                 _load();
            }
        }
    }

    Future<void> _delete(int id) async {
         // Confirm Dialog
         final confirm = await showGeneralDialog<bool>(
             context: context,
             barrierDismissible: true,
             barrierLabel: '',
             barrierColor: Colors.black.withOpacity(0.7),
             transitionDuration: const Duration(milliseconds: 300),
             pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
             transitionBuilder: (ctx, anim1, anim2, child) {
               return BackdropFilter(
                 filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                 child: ScaleTransition(
                   scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
                   child: FadeTransition(
                     opacity: anim1,
                     child: AlertDialog(
                         backgroundColor: Theme.of(ctx).cardColor.withOpacity(0.9),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                         title: Text("Delete Post?".toUpperCase(), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.red, letterSpacing: 1.0)),
                         content: Text("This cannot be undone. Are you sure?", style: GoogleFonts.inter(fontSize: 14)),
                         actions: [
                             TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("CANCEL", style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w700))),
                             const SizedBox(width: 8),
                             ElevatedButton(
                               onPressed: () => Navigator.pop(ctx, true), 
                               style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                               child: Text("DELETE", style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white))
                             ),
                         ],
                     ),
                   ),
                 ),
               );
             }
         );
         
         if (confirm != true) return;

         setState(() => _isLoading = true);
         try {
             await _api.deleteAdminMarketingRequest(id);
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted!")));
             _load(); 
         } catch (e) {
             if (mounted) {
                 setState(() => _isLoading = false);
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete Failed: $e")));
             }
         }
    }

    @override
    Widget build(BuildContext context) {
        if (_isLoading) return const Center(child: CircularProgressIndicator());
        
        final filteredItems = _items.where((item) {
            if (_searchQuery.isEmpty) return true;
            final title = (item['title'] ?? '').toString().toLowerCase();
            final link = (item['link'] ?? '').toString().toLowerCase();
            final q = _searchQuery.toLowerCase();
            return title.contains(q) || link.contains(q);
        }).toList();

        if (_items.isEmpty) return Center(child: Text("No pending marketing requests.", style: GoogleFonts.inter(color: Colors.grey)));
        
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search marketing requests...",
                  hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16)
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: filteredItems.isEmpty 
                  ? Center(child: Text("No matches found.", style: GoogleFonts.inter(color: Colors.grey)))
                  : ListView.builder(
                    itemCount: filteredItems.length,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                            ),
                            child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showMarketingDetails(context, item),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(item['title'] ?? 'Untitled', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                    Text(item['link'] ?? 'No link attached', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  ],
                                                ),
                                              ),
                                              _statusChip(item['status']),
                                            ],
                                          ),
                                        ),
                                        if (item['image'] != null)
                                            Builder(builder: (c) {
                                              var url = item['image'].toString();
                                              if (url.startsWith('/')) {
                                                  final domain = baseUrl.replaceAll('/api/', '');
                                                  url = '$domain$url';
                                              }
                                              return Container(
                                                height: 180, width: double.infinity,
                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.network(url, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white24))),
                                                ),
                                              );
                                            }),
                                         if (item['video'] != null && item['image'] == null)
                                            Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 16),
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.videocam_outlined, color: Colors.blue),
                                                  const SizedBox(width: 12),
                                                  Text("VIDEO CONTENT ATTACHED", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.blue)),
                                                ],
                                              ),
                                            ),
                                        
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (item['status'] == 'PENDING') ...[
                                                 TextButton(onPressed: () => _decide(item['id'], 'REJECTED'), child: Text("REJECT", style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w800, fontSize: 12))),
                                                 const SizedBox(width: 12),
                                                 ElevatedButton(
                                                   onPressed: () => _decide(item['id'], 'APPROVED'), 
                                                   style: ElevatedButton.styleFrom(backgroundColor: FfigTheme.accentBrown, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                                   child: Text("APPROVE", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12))
                                                 ),
                                              ] else ...[
                                                  IconButton(
                                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                      onPressed: () => _delete(item['id']),
                                                  ),
                                                  const Spacer(),
                                                  Text(item['status'].toUpperCase(), style: GoogleFonts.inter(
                                                      color: item['status'] == 'APPROVED' ? Colors.green : Colors.grey,
                                                      fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.2
                                                  )),
                                              ]
                                            ],
                                          ),
                                        )
                                    ],
                                ),
                            ),
                        );
                    }
                ),
            ),
          ],
        );
    }

    Widget _statusChip(String status) {
      Color color = Colors.grey;
      if (status == 'PENDING') color = Colors.orange;
      if (status == 'APPROVED') color = Colors.green;
      if (status == 'REJECTED') color = Colors.red;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(status.toUpperCase(), style: GoogleFonts.inter(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
      );
    }

    void _showMarketingDetails(BuildContext context, dynamic item) {
        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (c) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
                constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        // HEADER
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item['title'] ?? 'Marketing Request', 
                                  style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                        
                        Flexible(
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Text("REQUEST DETAILS", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2)),
                                      const SizedBox(height: 16),
                                      _detailRow(Icons.category_outlined, "Type", (item['type'] ?? 'Unknown').toString().toUpperCase()),
                                      if (item['link'] != null && item['link'].toString().isNotEmpty) ...[
                                          _detailRow(Icons.link_rounded, "External Link", item['link']),
                                      ],
                                      const SizedBox(height: 24),
                                      
                                      if (item['image'] != null) ...[
                                          Text("ATTACHED MEDIA", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2)),
                                          const SizedBox(height: 16),
                                          Builder(builder: (c) {
                                              var url = item['image'].toString();
                                              if (url.startsWith('/')) {
                                                  final domain = baseUrl.replaceAll('/api/', '');
                                                  url = '$domain$url';
                                              }
                                              return ClipRRect(
                                                borderRadius: BorderRadius.circular(16), 
                                                child: Image.network(url, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(height: 200, color: Colors.grey[900], child: const Icon(Icons.broken_image, color: Colors.white24)))
                                              );
                                          }),
                                          const SizedBox(height: 16),
                                      ],
                                      if (item['video'] != null) ...[
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.videocam_outlined, color: Colors.blue),
                                                const SizedBox(width: 12),
                                                Text("USER PROVIDED VIDEO CONTENT", style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.blue)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                      ],
                                      const SizedBox(height: 32),
                                  ]
                              )
                          ),
                        ),
                    ]
                )
            )
        );
    }
}

/// Helper method to prompt the admin for a reason when declining.
Future<String?> _showDeclineReasonDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showGeneralDialog<String>(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.black.withOpacity(0.7),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
        transitionBuilder: (ctx, anim1, anim2, child) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: ScaleTransition(
              scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
              child: FadeTransition(
                opacity: anim1,
                child: AlertDialog(
                    backgroundColor: Theme.of(ctx).cardColor.withOpacity(0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    title: Text("Decline Reason".toUpperCase(), style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: FfigTheme.accentBrown, letterSpacing: 1.0)),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Please provide a reason for declining this request.", style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 20),
                        TextField(
                            controller: controller,
                            style: GoogleFonts.inter(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: "Reason...",
                              hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                              filled: true,
                              fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                            ),
                            maxLines: 4,
                            autofocus: true,
                        ),
                      ],
                    ),
                    actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCEL", style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        ElevatedButton(
                            onPressed: () {
                                if (controller.text.trim().isEmpty) return;
                                Navigator.pop(ctx, controller.text.trim());
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: Text("REJECT", style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white)),
                        )
                    ]
                ),
              ),
            ),
          );
        }
    );
}
