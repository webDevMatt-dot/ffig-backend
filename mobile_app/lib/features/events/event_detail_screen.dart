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
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.event_available, color: Theme.of(context).primaryColor, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  "Confirm RSVP",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    "Please provide your details below to secure your spot for this event.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  _buildPremiumField(
                    context: context,
                    controller: firstNameController,
                    label: "First Name",
                    icon: Icons.person_outline,
                    validator: (v) => v!.isEmpty ? "Please enter your first name" : null,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumField(
                    context: context,
                    controller: lastNameController,
                    label: "Last Name",
                    icon: Icons.person_outline,
                    validator: (v) => v!.isEmpty ? "Please enter your last name" : null,
                  ),
                  const SizedBox(height: 16),
                  _buildPremiumField(
                    context: context,
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
                          backgroundColor: Theme.of(context).primaryColor,
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
    required BuildContext context,
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
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark 
            ? Colors.white.withOpacity(0.05) 
            : Colors.black.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
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
               backgroundColor: Theme.of(context).cardColor,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(Icons.check_circle_outline, color: Theme.of(context).primaryColor, size: 80),
                   const SizedBox(height: 24),
                   Text(
                     "RSVP Sent!",
                     style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 12),
                   Text(
                     "Your registration has been successfully sent. You can find your ticket in the 'My Tickets' section.",
                     textAlign: TextAlign.center,
                     style: Theme.of(context).textTheme.bodyMedium,
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
                          backgroundColor: Theme.of(context).primaryColor,
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
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverAppBar(
                  expandedHeight: 500.0,
                  pinned: true,
                  elevation: innerBoxIsScrolled ? 4 : 0,
                  forceElevated: innerBoxIsScrolled,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
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
                  collapseMode: CollapseMode.parallax,
                  titlePadding: const EdgeInsets.only(bottom: kTextTabBarHeight + 12, left: 40, right: 40),
                  title: LayoutBuilder(
                    builder: (context, constraints) {
                      final top = constraints.biggest.height;
                      // Calculate opacity: 0 at expandedHeight, 1 at collapse boundary
                      final double expandedH = 500.0;
                      final double collapsedH = kToolbarHeight + kTextTabBarHeight;
                      
                      // Speed up the fade-in so it only shows up at the very end
                      final double opacity = (1.0 - (top - collapsedH) / 100.0).clamp(0.0, 1.0);
                      
                      return Opacity(
                        opacity: opacity,
                        child: Text(
                          event['title'].toString().replaceAll(RegExp(r'poala', caseSensitive: false), 'Paola'), 
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface, 
                            fontSize: 16, 
                            fontWeight: FontWeight.bold
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                  background: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 80),
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
                                    placeholder: (_, __) => Container(color: Theme.of(context).colorScheme.surface),
                                    errorWidget: (_, __, ___) => Icon(Icons.broken_image, color: Theme.of(context).disabledColor, size: 50),
                                  ),
                              ),
                            ),
                          ),
                        ),
                        // Premium Typographic Title Area
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                Text(
                                event['title'].toString().replaceAll('POALA', 'PAOLA').toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 20, // Slightly smaller for better fit
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: kTextTabBarHeight + 20),
                      ],
                    ),
                  ),
                ),
                bottom: TabBar(
                  isScrollable: true,
                  indicatorColor: Theme.of(context).primaryColor,
                  labelColor: Theme.of(context).colorScheme.onSurface,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  tabs: [
                    Tab(text: "OVERVIEW"),
                    Tab(text: "AGENDA"),
                    Tab(text: "SPEAKERS"),
                    Tab(text: "FAQ"),
                  ],
                ),
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
    return Builder(builder: (context) {
      return CustomScrollView(
        key: const PageStorageKey<String>('overview'),
        slivers: [
          SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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
                      Icon(Icons.location_on, color: Theme.of(context).disabledColor),
                      const SizedBox(width: 8),
                      Expanded(child: Text("${event['location']}", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold))),
                    ],
                  ),

                 const Divider(height: 48),
                                  Text("About this Event", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(event['description'] ?? "No description provided.", style: Theme.of(context).textTheme.bodyLarge),
                 
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
              ]),
            ),
          ),
        ],
      );
    });
  }

  /// Builds the Agenda tab content list.
  Widget _buildAgenda(List agenda) {
    return Builder(builder: (context) {
      if (agenda.isEmpty) return const Center(child: Text("Agenda coming soon."));
      return CustomScrollView(
        key: const PageStorageKey<String>('agenda'),
        slivers: [
          SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
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
                childCount: agenda.length,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildSpeakers(List speakers) {
     return Builder(builder: (context) {
       if (speakers.isEmpty) {
         return Center(child: Text("Speakers to be announced.", style: Theme.of(context).textTheme.bodyMedium));
       }
       return CustomScrollView(
         key: const PageStorageKey<String>('speakers'),
         slivers: [
           SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
           SliverPadding(
             padding: const EdgeInsets.all(24),
             sliver: SliverList(
               delegate: SliverChildBuilderDelegate(
                 (context, index) {
                   final s = speakers[index];
                   final String? photoUrl = s['photo_url'];
                   final String name = s['name'] ?? 'Speaker';
                   final String? role = s['role'];
                   final String? bio = s['bio'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor, // Use cardColor for responsive background
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Theme.of(context).dividerColor),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.2),
                           blurRadius: 10,
                           offset: const Offset(0, 4),
                         ),
                       ],
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Padding(
                           padding: const EdgeInsets.all(20),
                           child: Row(
                             children: [
                               // Profile Image / Fallback
                               Container(
                                 width: 70,
                                 height: 70,
                                 decoration: BoxDecoration(
                                   shape: BoxShape.circle,
                                   border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3), width: 2),
                                   gradient: LinearGradient(
                                     colors: [
                                       Theme.of(context).primaryColor.withOpacity(0.8),
                                       Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                                     ],
                                     begin: Alignment.topLeft,
                                     end: Alignment.bottomRight,
                                   ),
                                 ),
                                 child: ClipOval(
                                   child: (photoUrl != null && photoUrl.isNotEmpty)
                                       ? CachedNetworkImage(
                                           imageUrl: photoUrl,
                                           fit: BoxFit.cover,
                                           placeholder: (context, url) => const Center(
                                             child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
                                           ),
                                           errorWidget: (context, url, error) => Center(
                                             child: Text(name[0], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                           ),
                                         )
                                       : Center(
                                           child: Text(name[0], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                         ),
                                 ),
                               ),
                               const SizedBox(width: 20),
                               // Name and Role
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                      Text(
                                        name, 
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                                      ),
                                     if (role != null && role.isNotEmpty)
                                       Padding(
                                         padding: const EdgeInsets.only(top: 4),
                                         child: Text(
                                           role.toUpperCase(), 
                                           style: TextStyle(
                                             color: Theme.of(context).primaryColor,
                                             fontWeight: FontWeight.w700, 
                                             fontSize: 12, 
                                             letterSpacing: 1.2,
                                           ),
                                         ),
                                       ),
                                   ],
                                 ),
                               ),
                             ],
                           ),
                         ),
                         if (bio != null && bio.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Text(
                                bio, 
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                       ],
                     ),
                   );
                 },
                 childCount: speakers.length,
               ),
             ),
           ),
         ],
       );
     });
  }

  /// Builds the FAQ tab content as expansion tiles.
  Widget _buildFAQ(List faqs) {
    return Builder(builder: (context) {
      if (faqs.isEmpty) return Center(child: Text("No FAQs yet.", style: Theme.of(context).textTheme.bodyMedium));
      return CustomScrollView(
        key: const PageStorageKey<String>('faq'),
        slivers: [
          SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final f = faqs[index];
                  return ExpansionTile(
                    title: Text(f['question'], style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(f['answer'], style: Theme.of(context).textTheme.bodyMedium),
                      )
                    ],
                  );
                },
                childCount: faqs.length,
              ),
            ),
          ),
        ],
      );
    });
  }
}
