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
  int _quantity = 1;

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
      MaterialPageRoute(builder: (context) => CheckoutScreen(event: widget.event, tier: tier, quantity: _quantity))
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (tier['discounted_price'] != null && 
                                  double.parse(tier['discounted_price'].toString()) < price) ...[
                                Text(
                                  "${(tier['currency'] ?? 'usd').toString().toUpperCase()} ${price.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontSize: 14, 
                                    color: Colors.grey, 
                                    decoration: TextDecoration.lineThrough
                                  ),
                                ),
                                Text(
                                  "${(tier['currency'] ?? 'usd').toString().toUpperCase()} ${double.parse(tier['discounted_price'].toString()).toStringAsFixed(2)}",
                                  style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ] else ...[
                                Text(
                                  price == 0 
                                    ? "Free" 
                                    : "${(tier['currency'] ?? 'usd').toString().toUpperCase()} ${price.toStringAsFixed(2)}",
                                  style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedTierId != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    Text("$_quantity", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        // Max 10 per order, or check available tickets 
                        final maxAvailable = _tiers.firstWhere((t) => t['id'] == _selectedTierId)['available'] ?? 10;
                        if (_quantity < 10 && _quantity < maxAvailable) {
                          setState(() => _quantity++);
                        }
                      },
                    ),
                  ],
                ),
              if (_selectedTierId != null) const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedTierId == null ? null : _proceedToCheckout,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Builder(
                    builder: (context) {
                      String buttonText = "CONTINUE";
                      if (_selectedTierId != null) {
                        final tier = _tiers.firstWhere((t) => t['id'] == _selectedTierId);
                        final originalPrice = double.tryParse(tier['price'].toString()) ?? 0.0;
                        final discountedPrice = tier['discounted_price'] != null 
                            ? double.tryParse(tier['discounted_price'].toString()) ?? originalPrice
                            : originalPrice;
                        
                        final total = discountedPrice * _quantity;
                        final currency = (tier['currency'] ?? 'usd').toString().toUpperCase();
                        
                        if (discountedPrice > 0) {
                          buttonText = "CONTINUE - $currency ${total.toStringAsFixed(2)}";
                        } else {
                          buttonText = "CONTINUE - FREE";
                        }
                      }
                      return Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
