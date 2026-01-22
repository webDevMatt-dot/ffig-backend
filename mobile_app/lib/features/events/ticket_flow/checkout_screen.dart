import 'package:flutter/material.dart';
import '../../../../core/services/ticket_service.dart';
import 'ticket_confirmation_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final Map<String, dynamic> tier;

  const CheckoutScreen({super.key, required this.event, required this.tier});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _ticketService = TicketService();
  bool _isLoading = false;
  
  // Mock Form Fields
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  Future<void> _processPayment() async {
    // Validate (Mock)
    if (_cardNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter card details")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simulate Payment Delay
      await Future.delayed(const Duration(seconds: 2));

      // Call API
      final ticket = await _ticketService.purchaseTicket(
        widget.event['id'], 
        widget.tier['id']
      );

      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => TicketConfirmationScreen(ticket: ticket, event: widget.event))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Purchase Failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(widget.tier['price'].toString()) ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text("Checkout")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Order Summary", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text(widget.event['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${widget.tier['name']} Ticket"),
                trailing: Text("\$${price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
            
            Text("Payment Method", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: "Card Number",
                prefixIcon: Icon(Icons.credit_card),
                border: OutlineInputBorder(),
                hintText: "0000 0000 0000 0000",
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: "Expiry (MM/YY)", border: OutlineInputBorder()),
                    keyboardType: TextInputType.datetime,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: "CVV", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text("PAY \$${price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            const Center(child: Text("Secure Payment Encrypted", style: TextStyle(color: Colors.grey, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}
