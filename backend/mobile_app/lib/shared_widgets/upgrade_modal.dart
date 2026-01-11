import 'package:flutter/material.dart';
import '../features/premium/locked_screen.dart';

class UpgradeModal extends StatelessWidget {
  final String message;
  const UpgradeModal({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Unlock Feature"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_person, size: 60, color: Theme.of(context).primaryColor),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text("Upgrade your membership to access extended networking, business tools, and more!"),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Maybe Later")),
        ElevatedButton(
          onPressed: () {
             Navigator.pop(context);
             Navigator.push(context, MaterialPageRoute(builder: (context) => const LockedScreen()));
          },
          child: const Text("Upgrade Now"),
        )
      ],
    );
  }
}
