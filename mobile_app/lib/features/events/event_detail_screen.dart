import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ticket_flow/ticket_selection_screen.dart';
import '../../core/services/membership_service.dart';

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

  void _onGetTickets(BuildContext context) {
    if (!MembershipService.canBuyTickets) {
      MembershipService.showUpgradeDialog(context, "Ticket Purchase");
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
                expandedHeight: 350.0,
                pinned: true,
                floating: false,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 60, right: 16),
                  title: Text(
                      event['title'], 
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, shadows: [const Shadow(color: Colors.black, blurRadius: 4)])
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                       Image.network(event['image_url'], fit: BoxFit.cover, errorBuilder: (_,__,___)=> Container(color: Colors.grey)),
                       const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]))),
                    ],
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
              onPressed: (event['is_sold_out'] == true) ? null : () => _onGetTickets(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: (event['is_sold_out'] == true) ? Colors.grey : Theme.of(context).colorScheme.primary,
                foregroundColor: (event['is_sold_out'] == true) ? Colors.white : Colors.black,
              ),
              child: Text(
                (event['is_sold_out'] == true) ? "SOLD OUT" : "GET TICKETS",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
               Expanded(child: Text("${event['date']}", style: const TextStyle(fontWeight: FontWeight.bold))),
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
           if (event['is_virtual'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(Icons.video_camera_front, color: Colors.blue),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _launchExternalUrl(context, event['virtual_link']),
                      child: const Text("Join Virtual Link", style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),

           const Divider(height: 48),
           
           Text("About this Event", style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
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
                 Text(event['price_label'] ?? 'Free', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
               ],
             ),
           ),
           const SizedBox(height: 80), // Specs for scrolling
        ],
      ),
    );
  }

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
                   backgroundImage: (s['photo_url'] != null) ? NetworkImage(s['photo_url']) : null,
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
