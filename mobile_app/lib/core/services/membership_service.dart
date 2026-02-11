import 'package:flutter/material.dart';
import '../../shared_widgets/upgrade_modal.dart';

enum UserTier { free, standard, premium }

/// A Static Service Helper for managing User Tiers and Permissions (RBAC).
///
/// **Role Hierarchy:**
/// - **Free (Guest):** Read-only access to public content.
/// - **Standard:** Access to Events and Community Chat.
/// - **Premium (VVIP):** Full access including Inbox, Advertising, and Business Profile.
/// - **Admin:** Superuser access to everything.
class MembershipService {
  static UserTier currentTier = UserTier.free;

  /// Sets the current user tier based on the backend response string.
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

  // --- Tier Getters ---
  static bool get isFree => !isAdmin && currentTier == UserTier.free;
  static bool get isStandard => isAdmin || currentTier == UserTier.standard;
  static bool get isPremium => isAdmin || currentTier == UserTier.premium;

  // --- Feature Permissions (Gatekeepers) ---
  
  /// Can access community chat? (Standard+)
  static bool get canCommunityChat => !isFree; 
  
  /// Can use direct messaging? (Premium only)
  static bool get canInbox => isPremium;
  
  /// Can buy event tickets? (Standard+)
  static bool get canBuyTickets => !isFree;
  
  /// Can post VVIP Reels/Ads? (Premium only)
  static bool get canAdvertise => isPremium;
  
  /// Can create a business directory profile? (Premium only)
  static bool get canCreateBusinessProfile => isPremium;
  
  /// Can view full member directory details? (Premium only)
  static bool get canViewFullDirectory => isPremium;
  
  /// Can view limited member directory? (Premium only - currently restricted)
  static bool get canViewLimitedDirectory => isPremium;

  /// Helper used by UI to show an "Upgrade Required" dialog for locked features.
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

