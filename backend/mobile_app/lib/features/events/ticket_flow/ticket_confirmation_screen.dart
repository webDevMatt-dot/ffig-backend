import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TicketConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final Map<String, dynamic> event;

  const TicketConfirmationScreen({super.key, required this.ticket, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Purchase Successful"), 
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 24),
              const Text("You're Going!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Ticket for ${event['title']}", style: const TextStyle(fontSize: 16, color: Colors.grey)),
              
              const SizedBox(height: 40),
              
              // Ticket Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(ticket['tierName'] ?? 'General Admission', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    QrImageView(
                      data: ticket['qr_code_data'] ?? 'INVALID',
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                    const SizedBox(height: 16),
                    Text("Ticket ID: ${ticket['id']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text("Return to Home"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
