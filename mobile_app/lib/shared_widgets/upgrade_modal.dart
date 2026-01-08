import 'package:flutter/material.dart';

class UpgradeModal extends StatelessWidget {
  final String feature;
  const UpgradeModal({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Unlock Feature"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_person, size: 60, color: Theme.of(context).primaryColor),
          const SizedBox(height: 16),
          Text("The '$feature' feature is available to Standard and Premium members."),
          const SizedBox(height: 16),
          const Text("Upgrade your membership to access extended networking, business tools, and more!"),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Maybe Later")),
        ElevatedButton(
          onPressed: () {
             Navigator.pop(context);
             // TODO: Navigate to Subscription Screen
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Redirecting to Plans...")));
          },
          child: const Text("Upgrade Now"),
        )
      ],
    );
  }
}
