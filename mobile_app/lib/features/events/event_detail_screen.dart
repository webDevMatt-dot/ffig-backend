import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ticket_flow/ticket_selection_screen.dart';
import 'ticket_flow/checkout_screen.dart';
import '../../core/services/membership_service.dart';
import '../../core/services/stripe_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../tickets/my_tickets_screen.dart';

/// Displays detailed information about a specific Event.
///
/// **Features:**
/// - Parallax Header with Event Image.
/// - Tabbed Interface: Overview, Agenda, Speakers, FAQ.
/// - Ticket Purchase Logic (In-App Selection or External URL).
/// - Gatekeeping: Uses `MembershipService` to restrict ticket buying to non-Free users.
class EventDetailScreen extends StatelessWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({super.key, required this.event});

  Future<void> _launchExternalUrl(BuildContext context, String? urlString) async {
    if (urlString != null && urlString.isNotEmpty) {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open link")));
        }
      }
    }
  }

  /// Handles the "Get Tickets" button action.
  /// - Checks permissions via `MembershipService.canBuyTickets`.
  /// - Shows Upgrade Dialog if user is Free tier.
  /// - Navigates to `TicketSelectionScreen` if in-app tiers exist.
  /// - Launches external URL fallback otherwise.
  void _onGetTickets(BuildContext context) {
    if (!MembershipService.canBuyTickets) {
      MembershipService.showUpgradeDialog(context, "Ticket Purchase");
      return;
    }

    if (event['is_rsvp_only'] == true) {
      _onRSVP(context);
      return;
    }
    
    // If ticket_tiers exist, go to In-App Selection
    // Else fall back to external URL
    final tiers = event['ticket_tiers'] as List?;
    if (tiers != null && tiers.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => TicketSelectionScreen(event: event)));
    } else {
      _launchExternalUrl(context, event['ticket_url']);
    }
  }

  void _onRSVP(BuildContext context) async {
    final tiers = event['ticket_tiers'] as List?;
    if (tiers == null || tiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No RSVP options available for this event.")));
      return;
    }
    
    // Find the first free tier
    final freeTier = tiers.firstWhere(
      (t) => (double.tryParse(t['price'].toString()) ?? 0.0) <= 0.0, 
      orElse: () => null
    );
    
    if (freeTier != null) {
      _showRSVPDialog(context, freeTier);
    } else {
      // If no free tier, just go to selection anyway or show error
      Navigator.push(context, MaterialPageRoute(builder: (context) => TicketSelectionScreen(event: event)));
    }
  }

  void _showRSVPDialog(BuildContext context, Map<String, dynamic> tier) {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.event_available, color: Color(0xFF8B4513), size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Confirm RSVP",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text(
                    "Please provide your details below to secure your spot for this event.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  _buildPremiumField(
                    controller: firstNameController,
                    label: "First Name",
                    icon: Icons.person_outline,
                    validator: (v) => v!.isEmpty ? "Please enter your first name" : null,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumField(
                    controller: lastNameController,
                    label: "Last Name",
                    icon: Icons.person_outline,
                    validator: (v) => v!.isEmpty ? "Please enter your last name" : null,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumField(
                    controller: emailController,
                    label: "Email Address",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v!.isEmpty) return "Please enter your email";
                      if (!v.contains('@')) return "Please enter a valid email";
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.white60,
                      ),
                      child: const Text("CANCEL"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(context);
                          _processRSVP(context, tier, firstNameController.text, lastNameController.text, emailController.text);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B4513),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text("CONFIRM", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: const Color(0xFF8B4513), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF8B4513), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }

  void _processRSVP(BuildContext context, Map<String, dynamic> tier, String first, String last, String email) async {
      try {
        final success = await StripeService().registerFreeTicket(
          tierId: tier['id'],
          firstName: first,
          lastName: last,
          email: email,
        );
        if (success && context.mounted) {
           showDialog(
             context: context,
             barrierDismissible: false,
             builder: (ctx) => AlertDialog(
               backgroundColor: const Color(0xFF1A1A1A),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Icon(Icons.check_circle_outline, color: Color(0xFF8B4513), size: 80),
                   const SizedBox(height: 24),
                   const Text(
                     "RSVP Sent!",
                     style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 12),
                   const Text(
                     "Your registration has been successfully sent. You can find your ticket in the 'My Tickets' section.",
                     textAlign: TextAlign.center,
                     style: TextStyle(color: Colors.white70, fontSize: 16),
                   ),
                   const SizedBox(height: 32),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                       onPressed: () {
                         Navigator.pop(ctx);
                         Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MyTicketsScreen()));
                       },
                       style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFF8B4513),
                         foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(vertical: 16),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                       ),
                       child: const Text("VIEW MY TICKETS", style: TextStyle(fontWeight: FontWeight.bold)),
                     ),
                   ),
                 ],
               ),
             ),
           );
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("RSVP Failed: $e")));
      }
  }

  bool _isConcluded() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    try {
      final dateStr = (event['end_date'] != null && event['end_date'].toString().isNotEmpty) 
          ? event['end_date'] 
          : event['date'];
      final eventDate = DateTime.parse(dateStr);
      final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
      return eventDay.isBefore(today);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final speakers = event['speakers'] as List? ?? [];
    final agenda = event['agenda'] as List? ?? [];
    final faqs = event['faqs'] as List? ?? [];

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                expandedHeight: 450.0,
                pinned: true,
                floating: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Link copied to clipboard!")),
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: innerBoxIsScrolled 
                    ? Text(
                        event['title'], 
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                      )
                    : null,
                  background: Container(
                    color: const Color(0xFF0F0F0F), // Deep black-charcoal
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        // Flyer with Shadow & Rounded corners
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: event['image_url'],
                                  fit: BoxFit.contain,
                                  placeholder: (_, __) => Container(color: Colors.grey[900]),
                                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 50),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Premium Typographic Title Area
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                          child: Column(
                            children: [
                               Text(
                                event['title'].toString().toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 40,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                bottom: const TabBar(
                  isScrollable: true,
                  indicatorColor: Colors.white,
                  tabs: [
                    Tab(text: "OVERVIEW"),
                    Tab(text: "AGENDA"),
                    Tab(text: "SPEAKERS"),
                    Tab(text: "FAQ"),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildOverview(context),
              _buildAgenda(agenda),
              _buildSpeakers(speakers),
              _buildFAQ(faqs),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: (event['is_sold_out'] == true || _isConcluded()) ? null : () => _onGetTickets(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: (event['is_sold_out'] == true || _isConcluded()) ? Colors.grey : Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isConcluded() 
                  ? "EVENT CONCLUDED" 
                  : (event['is_sold_out'] == true 
                      ? "SOLD OUT" 
                      : (event['is_rsvp_only'] == true ? "RSVP NOW" : "GET TICKETS")),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the Overview tab content.
  /// - Displays Date, Location, and Virtual Link.
  /// - Shows Description and Price.
  Widget _buildOverview(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // DateTime & Location
           Row(
             children: [
               const Icon(Icons.calendar_month, color: Colors.grey),
               const SizedBox(width: 8),
               Expanded(
                   child: Text(
                       () {
                           try {
                               final dt = DateTime.parse(event['date']);
                               final startStr = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
                               
                               final endStr = event['end_date'];
                               if (endStr != null && endStr.isNotEmpty) {
                                   try {
                                       final endDt = DateTime.parse(endStr);
                                       return "$startStr to ${endDt.day.toString().padLeft(2, '0')}-${endDt.month.toString().padLeft(2, '0')}-${endDt.year}";
                                   } catch (_) {}
                               }
                               return startStr;
                           } catch (_) {
                               return "${event['date']}";
                           }
                       }(), 
                       style: const TextStyle(fontWeight: FontWeight.bold)
                   )
               ),
             ],
           ),
           const SizedBox(height: 12),
           Row(
             children: [
               const Icon(Icons.location_on, color: Colors.grey),
               const SizedBox(width: 8),
               Expanded(child: Text("${event['location']}", style: const TextStyle(fontWeight: FontWeight.bold))),
             ],
           ),

           const Divider(height: 48),
           
           Text("About this Event", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
           const SizedBox(height: 16),
           Text(event['description'] ?? "No description provided.", style: const TextStyle(fontSize: 16, height: 1.6)),
           
           const SizedBox(height: 32),
           // Price Tag
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: Theme.of(context).cardColor,
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: Theme.of(context).dividerColor),
             ),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 const Text("Starting Price:", style: TextStyle(fontSize: 16)),
                 Text(
                   () {
                     if (event['ticket_tiers'] != null && (event['ticket_tiers'] as List).isNotEmpty) {
                       try {
                         final tiers = event['ticket_tiers'] as List;
                         var cheapest = tiers[0];
                         double minP = double.tryParse(cheapest['price'].toString()) ?? 999999.0;
                         for (var t in tiers) {
                            double p = double.tryParse(t['price'].toString()) ?? 0.0;
                            if (p < minP) { minP = p; cheapest = t; }
                         }
                         final cur = (cheapest['currency'] ?? 'usd').toString().toUpperCase();
                         return minP == 0 ? "Free" : "$cur ${minP.toStringAsFixed(2)}";
                       } catch (e) { return event['price_label'] ?? 'Free'; }
                     }
                     return event['price_label'] ?? 'Free';
                   }(), 
                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)
                 ),
               ],
             ),
           ),
           const SizedBox(height: 80), // Specs for scrolling
        ],
      ),
    );
  }

  /// Builds the Agenda tab content list.
  Widget _buildAgenda(List agenda) {
    if (agenda.isEmpty) return const Center(child: Text("Agenda coming soon."));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: agenda.length,
      itemBuilder: (context, index) {
        final item = agenda[index];
        return Card(
           margin: const EdgeInsets.only(bottom: 16),
           child: ListTile(
             leading: Text(
               "${item['start_time'].toString().substring(0,5)}\n${item['end_time'].toString().substring(0,5)}", 
               textAlign: TextAlign.center, 
               style: const TextStyle(fontWeight: FontWeight.bold)
             ),
             title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
             subtitle: Text(item['description'] ?? ''),
           ),
        );
      },
    );
  }

  /// Builds the Speakers tab content list.
  Widget _buildSpeakers(List speakers) {
     if (speakers.isEmpty) return const Center(child: Text("Speakers to be announced."));
     return ListView.builder(
       padding: const EdgeInsets.all(16),
       itemCount: speakers.length,
       itemBuilder: (context, index) {
         final s = speakers[index];
         return Card(
           margin: const EdgeInsets.only(bottom: 16),
           child: Padding(
             padding: const EdgeInsets.all(16),
             child: Row(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 CircleAvatar(
                   radius: 30,
                   backgroundImage: (s['photo_url'] != null) ? CachedNetworkImageProvider(s['photo_url']) : null,
                   child: (s['photo_url'] == null) ? Text(s['name'][0]) : null,
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(s['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                       if (s['role'] != null) Text(s['role'], style: TextStyle(color: Theme.of(context).primaryColor)),
                       const SizedBox(height: 8),
                       Text(s['bio'] ?? '', style: const TextStyle(fontSize: 14)),
                     ],
                   ),
                 )
               ],
             ),
           ),
         );
       },
     );
  }

  /// Builds the FAQ tab content as expansion tiles.
  Widget _buildFAQ(List faqs) {
    if (faqs.isEmpty) return const Center(child: Text("No FAQs yet."));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: faqs.length,
      itemBuilder: (context, index) {
        final f = faqs[index];
        return ExpansionTile(
          title: Text(f['question'], style: const TextStyle(fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(f['answer']),
            )
          ],
        );
      },
    );
  }
}
