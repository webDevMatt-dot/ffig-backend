import 'package:flutter/material.dart';
import '../../core/services/ticket_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays the User's Purchased Tickets.
///
/// **Features:**
/// - Fetches tickets via `TicketService`.
/// - Displays Event Name, Ticket Tier, and QR Code for entry.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final _ticketService = TicketService();
  bool _isLoading = true;
  List<dynamic> _tickets = [];

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  /// Fetches the user's tickets from the backend.
  /// - Uses `TicketService` to get data.
  /// - Updates `_tickets` state for rendering.
  Future<void> _fetchTickets() async {
    try {
      final data = await _ticketService.getMyTickets();
      setState(() => _tickets = data);
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Could not launch virtual link')),
         );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Tickets")),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _tickets.isEmpty 
              ? const Center(child: Text("You haven't purchased any tickets yet."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tickets.length,
                  itemBuilder: (context, index) {
                    final t = _tickets[index];
                    final isUsed = t['status'] == 'USED';

                    return Opacity(
                      opacity: isUsed ? 0.5 : 1.0,
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ExpansionTile(
                           leading: Icon(
                             Icons.confirmation_number, 
                             color: isUsed ? Colors.grey : Colors.purple
                           ),
                           title: Row(
                             children: [
                               Expanded(
                                 child: Text(
                                   t['eventName'] ?? 'Event Ticket', 
                                   style: const TextStyle(fontWeight: FontWeight.bold)
                                 ),
                               ),
                               if (isUsed)
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                   decoration: BoxDecoration(
                                     color: Colors.grey,
                                     borderRadius: BorderRadius.circular(4),
                                   ),
                                   child: const Text(
                                     "USED", 
                                     style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                   ),
                                 ),
                             ],
                           ),
                           subtitle: Text("${t['tierName']}"),
                           children: [
                             Padding(
                               padding: const EdgeInsets.all(24.0),
                               child: Column(
                                 children: [
                                   if (isUsed) ...[
                                     const Icon(Icons.check_circle, color: Colors.grey, size: 64),
                                     const SizedBox(height: 16),
                                     const Text("This ticket was used", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                   ] else if (t['isVirtual'] == true) ...[
                                     const Icon(Icons.videocam, size: 60, color: Color(0xFF8B4513)),
                                     const SizedBox(height: 16),
                                     const Text(
                                       "Virtual Event",
                                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                     ),
                                     const SizedBox(height: 8),
                                     if (t['virtualLink'] != null && t['virtualLink'].toString().isNotEmpty)
                                       InkWell(
                                         onTap: () => _launchUrl(t['virtualLink']),
                                         child: const Text(
                                           "Join Virtual Meeting",
                                           style: TextStyle(
                                             color: Colors.blue,
                                             fontSize: 16,
                                             decoration: TextDecoration.underline,
                                             fontWeight: FontWeight.bold,
                                           ),
                                         ),
                                       )
                                     else
                                       const Text("Link not yet available."),
                                   ] else ...[
                                     QrImageView(
                                       data: t['qr_code_data'] ?? '',
                                       size: 200,
                                     ),
                                     const SizedBox(height: 16),
                                     const Text("Show this QR code at the entrance"),
                                   ],
                                   if (t['first_name'] != null || t['last_name'] != null) ...[
                                     const SizedBox(height: 16),
                                     const Divider(),
                                     const SizedBox(height: 8),
                                     Text(
                                       "Guest: ${t['first_name'] ?? ''} ${t['last_name'] ?? ''}".trim(), 
                                       style: const TextStyle(fontWeight: FontWeight.bold)
                                     ),
                                     if (t['email'] != null)
                                       Text("Email: ${t['email']}"),
                                   ],
                                 ],
                               ),
                             )
                           ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
