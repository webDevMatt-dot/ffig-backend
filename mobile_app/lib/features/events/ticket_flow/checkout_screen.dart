import 'package:flutter/material.dart';
import '../../../../core/services/stripe_service.dart';
import '../../home/dashboard_screen.dart';
import '../../tickets/my_tickets_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final Map<String, dynamic> tier;
  final int quantity;

  const CheckoutScreen({super.key, required this.event, required this.tier, this.quantity = 1});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isLoading = false;

  Future<void> _processPayment() async {
    setState(() => _isLoading = true);

    try {
      final stripeService = StripeService();
      final success = await stripeService.purchaseTicket(
        tierId: widget.tier['id'],
        quantity: widget.quantity,
      );

      if (success && mounted) {
        // Show success and redirect to dashboard/tickets
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Successful! Your ticket is in My Tickets.")));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MyTicketsScreen()),
          (route) => false,
        );
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Canceled or Failed.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Purchase Failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processFreeRegistration() async {
    setState(() => _isLoading = true);
    try {
      final stripeService = StripeService();
      final success = await stripeService.registerFreeTicket(
        tierId: widget.tier['id'],
        quantity: widget.quantity,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registration Successful! Your ticket is in My Tickets.")));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MyTicketsScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Registration Failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final originalPrice = double.tryParse(widget.tier['price'].toString()) ?? 0.0;
    final discountedPrice = widget.tier['discounted_price'] != null 
        ? double.tryParse(widget.tier['discounted_price'].toString()) ?? originalPrice
        : originalPrice;
    
    final hasDiscount = discountedPrice < originalPrice;
    final effectivePrice = discountedPrice;
    final total = effectivePrice * widget.quantity;
    final currency = (widget.tier['currency'] ?? 'usd').toString().toUpperCase();
    
    // Check if free ticket
    if (originalPrice <= 0.0) {
        return Scaffold(
          appBar: AppBar(title: const Text("Checkout")),
          body: Center(
              child: ElevatedButton(
                  onPressed: _isLoading ? null : _processFreeRegistration,
                  child: _isLoading 
                    ? const CircularProgressIndicator() 
                    : const Text("Get Free Ticket")
              )
          ),

        );
    }

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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.event['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text("${widget.tier['name']} Ticket x ${widget.quantity}"),
                            ],
                          ),
                        ),
                        Text("$currency ${(originalPrice * widget.quantity).toStringAsFixed(2)}", 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            decoration: hasDiscount ? TextDecoration.lineThrough : null,
                            color: hasDiscount ? Colors.grey : null,
                          ),
                        ),
                      ],
                    ),
                    if (hasDiscount) ...[
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Membership Discount", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                          Text("- $currency ${((originalPrice - discountedPrice) * widget.quantity).toStringAsFixed(2)}", 
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total (Discounted)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text("$currency ${total.toStringAsFixed(2)}", 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).primaryColor)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            Text("Secure Payment", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text("We use Stripe to securely process your payment. You will be prompted to enter your payment details below."),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text("PAY $currency ${total.toStringAsFixed(2)}", textAlign: TextAlign.center),
              ),
            ),
            const SizedBox(height: 16),
            const Center(child: Text("Powered by Stripe", style: TextStyle(color: Colors.grey, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}
