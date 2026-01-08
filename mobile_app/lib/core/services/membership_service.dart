import 'package:flutter/material.dart';
import '../../shared_widgets/upgrade_modal.dart';

enum UserTier { free, standard, premium }

class MembershipService {
  static UserTier currentTier = UserTier.free;

  // Set Tier from String (Backend Response)
  static void setTier(String? tierName) {
    if (tierName == 'PREMIUM') {
      currentTier = UserTier.premium;
    } else if (tierName == 'STANDARD') {
      currentTier = UserTier.standard;
    } else {
      currentTier = UserTier.free;
    }
  }

  static bool get isFree => currentTier == UserTier.free;
  static bool get isStandard => currentTier == UserTier.standard;
  static bool get isPremium => currentTier == UserTier.premium;

  // Permissions Logic
  static bool get canChat => !isFree; // Standard+
  static bool get canInbox => isPremium; // Premium only
  static bool get canAdvertise => isPremium; // Premium only
  static bool get canCreateBusinessProfile => isPremium; // Premium only
  static bool get canViewFullDirectory => !isFree; // Standard+

  // Helper to show dialog
  static void showUpgradeDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => UpgradeModal(feature: feature),
    );
  }
}
