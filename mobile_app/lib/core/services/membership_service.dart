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

  static bool isAdmin = false;

  static bool get isFree => !isAdmin && currentTier == UserTier.free;
  static bool get isStandard => isAdmin || currentTier == UserTier.standard;
  static bool get isPremium => isAdmin || currentTier == UserTier.premium;

  // Permissions Logic based on Matrix
  static bool get canCommunityChat => !isFree; // Standard & Premium
  static bool get canInbox => isPremium; // Premium only ('Inbox or email members directly')
  
  static bool get canBuyTickets => !isFree; // Standard & Premium ('Attend and buy tickets')
  
  static bool get canAdvertise => isPremium; // Premium only
  static bool get canCreateBusinessProfile => isPremium; // Premium only
  
  // Directory: Standard sees "limited info", Premium sees all.
  // We'll treat "View Full Directory" as the ability to see contact info or interact.
  static bool get canViewFullDirectory => isPremium; // Premium only
  static bool get canViewLimitedDirectory => !isFree; // Standard & Premium

  // Helper to show dialog
  static void showUpgradeDialog(BuildContext context, String feature, {UserTier requiredTier = UserTier.standard}) {
    String message = "Unlock '$feature' by becoming an FFIG Member. Choose Standard or Premium to access.";

    if (currentTier == UserTier.standard && requiredTier == UserTier.premium) {
      message = "The '$feature' feature is exclusive to Premium Members. Upgrade to unlock.";
    }

    showDialog(
      context: context,
      builder: (context) => UpgradeModal(message: message),
    );
  }
}
