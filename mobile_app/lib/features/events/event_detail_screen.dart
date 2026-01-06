import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends StatelessWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({super.key, required this.event});

  Future<void> _launchTicketUrl(BuildContext context) async {
    final urlString = event['ticket_url'];
    if (urlString != null && urlString.isNotEmpty) {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open link")));
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No ticket link available.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Big Image Header
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(event['title'], style: const TextStyle(fontSize: 16)),
              background: Image.network(event['image_url'], fit: BoxFit.cover),
            ),
          ),
          // 2. Event Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(event['date'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      const Icon(Icons.location_on, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(event['location'], style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  const Divider(height: 40),
                  Text("About this Event", style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(event['description'] ?? "No description provided.", style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 40),

                  // 1. Show Price Label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Ticket Price:", style: TextStyle(fontSize: 16)),
                        Text(
                          event['price_label'] ?? 'Free', 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Smart Button Logic
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      // Disable button if sold out
                      onPressed: (event['is_sold_out'] == true) ? null : () => _launchTicketUrl(context),
                      
                      // Change Icon/Text based on status
                      icon: Icon((event['is_sold_out'] == true) ? Icons.block : Icons.confirmation_number_outlined),
                      label: Text(
                        (event['is_sold_out'] == true) ? "SOLD OUT" : "GET TICKETS",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (event['is_sold_out'] == true) ? Colors.grey : Theme.of(context).colorScheme.primary,
                        foregroundColor: (event['is_sold_out'] == true) ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
