import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'checkout_screen.dart';

class TicketSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  const TicketSelectionScreen({super.key, required this.event});

  @override
  State<TicketSelectionScreen> createState() => _TicketSelectionScreenState();
}

class _TicketSelectionScreenState extends State<TicketSelectionScreen> {
  // Mock data derived from event['ticket_tiers']
  List<dynamic> _tiers = [];
  int? _selectedTierId;

  @override
  void initState() {
    super.initState();
    _tiers = widget.event['ticket_tiers'] ?? [];
  }

  void _proceedToCheckout() {
    if (_selectedTierId == null) return;
    
    final tier = _tiers.firstWhere((t) => t['id'] == _selectedTierId);
    
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => CheckoutScreen(event: widget.event, tier: tier))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Tickets")),
      body: _tiers.isEmpty 
          ? const Center(child: Text("No tickets available for this event."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tiers.length,
              itemBuilder: (context, index) {
                final tier = _tiers[index];
                final isSelected = _selectedTierId == tier['id'];
                final price = double.tryParse(tier['price'].toString()) ?? 0.0;
                
                return Card(
                  color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.transparent, 
                      width: 2
                    )
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () => setState(() => _selectedTierId = tier['id']),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tier['name'], style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text("${tier['available']} remaining", style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text(
                            price == 0 ? "Free" : "\$${price.toStringAsFixed(2)}",
                            style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _selectedTierId == null ? null : _proceedToCheckout,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("CONTINUE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
