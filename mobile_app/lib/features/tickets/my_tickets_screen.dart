import 'package:flutter/material.dart';
import '../../core/services/ticket_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                         leading: const Icon(Icons.confirmation_number, color: Colors.purple),
                         title: Text(t['eventName'] ?? 'Event Ticket', style: const TextStyle(fontWeight: FontWeight.bold)),
                         subtitle: Text("${t['tierName']}"),
                         children: [
                           Padding(
                             padding: const EdgeInsets.all(24.0),
                             child: Column(
                               children: [
                                 QrImageView(
                                   data: t['qr_code_data'] ?? '',
                                   size: 200,
                                 ),
                                 const SizedBox(height: 16),
                                 const Text("Show this QR code at the entrance"),
                               ],
                             ),
                           )
                         ],
                      ),
                    );
                  },
                ),
    );
  }
}
