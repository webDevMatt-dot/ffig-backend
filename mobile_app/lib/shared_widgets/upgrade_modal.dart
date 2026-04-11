import 'package:flutter/material.dart';
import '../features/premium/locked_screen.dart';
import '../core/services/membership_service.dart';

/// A promotional dialog that encourages users to upgrade their membership.
/// - **Trigger:** Displayed when a user tries to access a restricted feature (e.g., VVIP content, Member Directory).
/// - **Actions:** 'Maybe Later' (Dismiss) or 'Upgrade Now' (Navigates to LockedScreen/Premium options).
class UpgradeModal extends StatelessWidget {
  final String message;
  final String feature;
  final UserTier requiredTier;

  const UpgradeModal({
    super.key,
    required this.message,
    this.feature = '',
    this.requiredTier = UserTier.standard,
  });

  List<String> get _standardBullets => const [
        "Community Chat access",
        "Post and view Stories",
        "Community member networking",
        "10% event ticket discount",
      ];

  List<String> get _premiumBullets => const [
        "Everything in Standard",
        "Direct Inbox messaging",
        "Business Profile in directory",
        "Marketing and VVIP promo tools",
        "Full member profile visibility",
        "20% event ticket discount",
      ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(requiredTier == UserTier.premium ? "Go Premium" : "Unlock with Standard"),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_person, size: 36, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature.isEmpty ? "Membership feature locked" : "$feature is locked",
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            _planCard(
              context: context,
              title: "Standard · \$600/year",
              bullets: _standardBullets,
              highlighted: requiredTier == UserTier.standard,
            ),
            const SizedBox(height: 10),
            _planCard(
              context: context,
              title: "Premium · \$800/year",
              bullets: _premiumBullets,
              highlighted: requiredTier == UserTier.premium,
            ),
          ],
        ),
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

  Widget _planCard({
    required BuildContext context,
    required String title,
    required List<String> bullets,
    required bool highlighted,
  }) {
    final borderColor = highlighted ? Theme.of(context).colorScheme.primary : Colors.grey.shade300;
    final background = highlighted ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : Colors.transparent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...bullets.take(4).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• "),
                    Expanded(child: Text(item, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
