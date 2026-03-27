import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/admin_api_service.dart';

class AdminTicketsScreen extends StatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  State<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends State<AdminTicketsScreen> {
  final AdminApiService _apiService = AdminApiService();
  List<dynamic> _tickets = []; // Keep this to hold raw fetched tickets
  List<dynamic> _filteredTickets = [];
  Map<int, List<dynamic>> _groupedTickets = {};
  List<int> _upcomingEventIds = [];
  List<int> _pastEventIds = [];
  Map<int, Map<String, dynamic>> _eventMetadata = {};
  bool _isLoading = true;
  String? _error;
  String _searchQuery = "";
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    try {
      final tickets = await _apiService.fetchAdminTickets();
      if (mounted) {
        setState(() {
          _tickets = tickets; // Store raw tickets
          _groupTickets(tickets); // Group them
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _groupTickets(List<dynamic> tickets) {
    _groupedTickets.clear();
    _eventMetadata.clear();
    _upcomingEventIds.clear();
    _pastEventIds.clear();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var ticket in tickets) {
      final eventId = ticket['event_id'] as int;
      if (!_groupedTickets.containsKey(eventId)) {
        _groupedTickets[eventId] = [];
        _eventMetadata[eventId] = {
          'title': ticket['event_title'],
          'date': ticket['event_date'],
        };
      }
      _groupedTickets[eventId]!.add(ticket);
    }

    // Sort event IDs into upcoming and past
    for (var eventId in _eventMetadata.keys) {
      final dateStr = _eventMetadata[eventId]!['date'] as String?;
      bool isPast = false;
      if (dateStr != null) {
        final eventDate = DateTime.tryParse(dateStr);
        if (eventDate != null && eventDate.isBefore(today)) {
          isPast = true;
        }
      }

      if (isPast) {
        _pastEventIds.add(eventId);
      } else {
        _upcomingEventIds.add(eventId);
      }
    }

    // Sort upcoming events by date (soonest first)
    _upcomingEventIds.sort((a, b) {
      final dateA = DateTime.tryParse(_eventMetadata[a]!['date'] ?? '') ?? DateTime(2100);
      final dateB = DateTime.tryParse(_eventMetadata[b]!['date'] ?? '') ?? DateTime(2100);
      return dateA.compareTo(dateB);
    });

    // Sort past events by date (most recent first)
    _pastEventIds.sort((a, b) {
      final dateA = DateTime.tryParse(_eventMetadata[a]!['date'] ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(_eventMetadata[b]!['date'] ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });
  }

  void _filterTickets(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredTickets = [];
      } else {
        final lowercaseQuery = query.toLowerCase();
        _filteredTickets = _tickets.where((ticket) {
          final buyerName = (ticket['buyer_name'] ?? '').toString().toLowerCase();
          final buyerEmail = (ticket['buyer_email'] ?? '').toString().toLowerCase();
          final eventTitle = (ticket['event_title'] ?? '').toString().toLowerCase();
          final id = (ticket['id'] ?? '').toString().toLowerCase();
          
          return buyerName.contains(lowercaseQuery) ||
                 buyerEmail.contains(lowercaseQuery) ||
                 eventTitle.contains(lowercaseQuery) ||
                 id.contains(lowercaseQuery);
        }).toList();
      }
    });
  }

  void _showQRCodeDialog(Map<String, dynamic> ticket) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          "Ticket QR Code",
          style: GoogleFonts.lato(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: ticket['id'] ?? '',
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ticket['buyer_name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "${ticket['event_title']} - ${ticket['tier_name']}",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_filteredTickets.isEmpty) {
      return const Center(child: Text("No matching tickets found."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTickets.length,
      itemBuilder: (context, index) {
        final ticket = _filteredTickets[index];
        return _buildTicketTileExtended(ticket);
      },
    );
  }

  Widget _buildTicketTileExtended(Map<String, dynamic> ticket) {
    final date = DateTime.tryParse(ticket['purchase_date'] ?? '');
    final formattedDate = date != null ? DateFormat.yMMMd().format(date) : 'Unknown Date';
    final currency = (ticket['currency'] as String?)?.toUpperCase() ?? 'USD';
    final price = double.tryParse(ticket['price']?.toString() ?? '0') ?? 0.0;
    final formattedPrice = NumberFormat.simpleCurrency(name: currency).format(price);

    return InkWell(
      onTap: () => _showQRCodeDialog(ticket),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: ticket['buyer_photo'] != null 
                        ? NetworkImage(ticket['buyer_photo'])
                        : null,
                    child: ticket['buyer_photo'] == null 
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket['buyer_name'] ?? 'Unknown User',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          ticket['buyer_email'] ?? '',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formattedPrice,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket['event_title'] ?? 'Unknown Event',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          ticket['tier_name'] ?? 'General',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (ticket['status'] == 'USED') 
                          ? Colors.grey.withValues(alpha: 0.1) 
                          : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket['status'] ?? 'ACTIVE',
                      style: TextStyle(
                        color: (ticket['status'] == 'USED') ? Colors.grey : Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Search tickets...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: _filterTickets,
              )
            : Text("PURCHASED TICKETS", style: GoogleFonts.lato(letterSpacing: 2, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _filterTickets("");
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadTickets, child: const Text("Retry"))
          ],
        ),
      );
    }

    if (_tickets.isEmpty) { // Check raw tickets, if none fetched, then no grouped tickets either
      return const Center(child: Text("No tickets have been purchased yet."));
    }

    if (_isSearching && _searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    return RefreshIndicator(
      onRefresh: _loadTickets,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_upcomingEventIds.isNotEmpty) ...[
            _buildSectionHeader("Active & Upcoming Events"),
            ..._upcomingEventIds.map((id) => _buildEventFolder(id)),
            const SizedBox(height: 24),
          ],
          if (_pastEventIds.isNotEmpty) ...[
            _buildSectionHeader("Past Event Tickets"),
            ..._pastEventIds.map((id) => _buildEventFolder(id, isPast: true)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.lato(
          color: Colors.grey,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEventFolder(int eventId, {bool isPast = false}) {
    final metadata = _eventMetadata[eventId]!;
    final tickets = _groupedTickets[eventId]!;
    final dateStr = metadata['date'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
    final formattedDate = date != null ? DateFormat.yMMMd().format(date) : 'Unknown Date';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isPast 
              ? Colors.grey.withValues(alpha: 0.1) 
              : Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Icon(
            isPast ? Icons.history : Icons.event,
            color: isPast ? Colors.grey : Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          metadata['title'] ?? 'Unknown Event',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("$formattedDate • ${tickets.length} Ticket(s)"),
        children: tickets.map((ticket) => _buildTicketTile(ticket)).toList(),
      ),
    );
  }

  Widget _buildTicketTile(Map<String, dynamic> ticket) {
    final date = DateTime.tryParse(ticket['purchase_date'] ?? '');
    final formattedDate = date != null ? DateFormat.yMMMd().format(date) : 'Unknown Date';
    final currency = (ticket['currency'] as String?)?.toUpperCase() ?? 'USD';
    final price = double.tryParse(ticket['price']?.toString() ?? '0') ?? 0.0;
    final formattedPrice = NumberFormat.simpleCurrency(name: currency).format(price);

    return InkWell(
      onTap: () => _showQRCodeDialog(ticket),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: ticket['buyer_photo'] != null 
                      ? NetworkImage(ticket['buyer_photo'])
                      : null,
                  child: ticket['buyer_photo'] == null 
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket['buyer_name'] ?? 'Unknown User',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        ticket['tier_name'] ?? 'General',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formattedPrice,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
          ],
        ),
      ),
    );
  }
}
