import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/iap_service.dart';
import '../../core/services/stripe_service.dart';
import '../../core/services/membership_service.dart';

class LockedScreen extends StatefulWidget {
  const LockedScreen({super.key});

  @override
  State<LockedScreen> createState() => _LockedScreenState();
}

class _LockedScreenState extends State<LockedScreen> {
  static const String _standardProductId = 'FFIG_STANDARD';
  static const String _premiumProductId = 'FFIG_PREMIUM';

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open payment page")),
      );
    }
  }

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final Set<String> _productIds = {_standardProductId, _premiumProductId};

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _isStoreAvailable = false;
  bool _isLoadingProducts = true;
  bool _isPurchasing = false;
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _initIap();
    
    // Listen for global purchase success from IAPService
    IAPService().purchaseSuccessNotifier.addListener(_handlePurchaseSuccess);
  }

  void _handlePurchaseSuccess() {
    if (IAPService().purchaseSuccessNotifier.value && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Success! Your account has been upgraded. Please refresh your profile.'),
          backgroundColor: Colors.green,
        ),
      );
      // Reset notifier for next time
      IAPService().purchaseSuccessNotifier.value = false;
      Navigator.of(context).pop();
    }
  }

  Future<void> _initIap() async {
    try {
      final available = await _inAppPurchase.isAvailable();
      if (!mounted) return;

      if (!available) {
        setState(() {
          _isStoreAvailable = false;
          _isLoadingProducts = false;
        });
        return;
      }

      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_productIds);

      if (!mounted) return;

      setState(() {
        _isStoreAvailable = true;
        _products = response.productDetails;
        _isLoadingProducts = false;
      });
    } catch (e) {
       if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _buy(ProductDetails? product, String tierName) async {
    if (product != null) {
      setState(() => _isPurchasing = true);
      try {
        final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } catch (e) {
        if (mounted) {
           setState(() => _isPurchasing = false);
           _showPaymentRecovery(tierName: tierName, product: product, errorMessage: "$e");
        }
      }
    } else {
      // FALLBACK TO STRIPE
      setState(() => _isPurchasing = true);
      try {
        if (kDebugMode) print("Product null, falling back to Stripe for $tierName");
        final success = await StripeService().purchaseMembership(targetTier: tierName);
        if (success && mounted) {
          _handlePurchaseSuccess();
          // Trigger dashboard update
          IAPService().purchaseSuccessNotifier.value = true;
        }
      } catch (e) {
        if (mounted) {
          _showPaymentRecovery(tierName: tierName, product: null, errorMessage: "$e");
        }
      } finally {
        if (mounted) setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isPurchasing = true);
    try {
      await IAPService().restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore request sent.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Restore failed: $e")));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _openBillingSettings() async {
    final billingUrl = defaultTargetPlatform == TargetPlatform.iOS
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions';
    await _launchURL(context, billingUrl);
  }

  Future<void> _showPaymentRecovery({
    required String tierName,
    required ProductDetails? product,
    required String errorMessage,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Payment Didn’t Go Through",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Your membership remains active until your current period ends. Update your payment method or retry to avoid interruption.",
                ),
                const SizedBox(height: 10),
                Text(
                  "Details: $errorMessage",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _buy(product, tierName);
                    },
                    child: const Text("Retry Payment"),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      setState(() => _isPurchasing = true);
                      try {
                        final success = await StripeService().purchaseMembership(targetTier: tierName);
                        if (success && mounted) {
                          _handlePurchaseSuccess();
                          IAPService().purchaseSuccessNotifier.value = true;
                        }
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Unable to process alternative card right now.")),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isPurchasing = false);
                      }
                    },
                    child: const Text("Use Another Card"),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _openBillingSettings();
                    },
                    child: const Text("Update Billing Details"),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _launchURL(
                        context,
                        'mailto:admin@femalefoundersinitiative.com?subject=Payment%20support',
                      );
                    },
                    child: const Text("Contact Support"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Obsolete: Replaced by IAPService handling
  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {}

  ProductDetails? _findProduct(String productId) {
    if (_products.isEmpty) return null;
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  @override
  void dispose() {
    IAPService().purchaseSuccessNotifier.removeListener(_handlePurchaseSuccess);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final standard = _findProduct(_standardProductId);
    final premium = _findProduct(_premiumProductId);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const Icon(Icons.workspace_premium, size: 60, color: Color(0xFFD4AF37)),
              const SizedBox(height: 16),
              Text(
                'Unlock the Network',
                style: GoogleFonts.playfairDisplay(fontSize: 30, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Upgrade to unlock community networking, direct messaging, and growth tools.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 30),

              // Option 1: Standard Plan
              _buildPlanCard(
                context,
                title: "STANDARD MEMBER",
                price: "\$600 / year",
                features: [
                  "Community Chat access",
                  "Post and view Stories",
                  "Community member networking",
                  "10% ticket discount on events",
                ],
                buttonText: standard != null ? "JOIN STANDARD" : "JOIN VIA STRIPE",
                isRecommended: false,
                onTap: () => _buy(standard, 'STANDARD'),
              ),

              const SizedBox(height: 20),

              // Option 2: Premium Plan (Highlighted)
              _buildPlanCard(
                context,
                title: "PREMIUM MEMBER",
                price: "\$800 / year",
                features: [
                  "Everything in Standard",
                  "Direct Inbox messaging",
                  "Business Profile + Marketing tools",
                  "Full member profile visibility",
                  "20% ticket discount on events",
                ],
                buttonText: premium != null ? "GO PREMIUM" : "UPGRADE VIA STRIPE",
                isRecommended: true,
                onTap: () => _buy(premium, 'PREMIUM'),
              ),

              const SizedBox(height: 40),
              Text(
                "Already upgraded? Pull to refresh your profile.",
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isPurchasing ? null : _restorePurchases,
                child: Text(
                  "RESTORE PURCHASES",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 50), // Additional padding at the bottom
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required String title,
    required String price,
    required List<String> features,
    required String buttonText,
    required bool isRecommended,
    required VoidCallback? onTap,
  }) {
    final goldColor = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isRecommended ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isRecommended ? Colors.black : Colors.grey[300]!, width: 2),
        boxShadow: isRecommended
            ? [BoxShadow(color: goldColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (isRecommended)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: goldColor, borderRadius: BorderRadius.circular(20)),
                child: const Text('RECOMMENDED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            Text(
              title,
              style: TextStyle(
                color: isRecommended ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: TextStyle(color: isRecommended ? Colors.grey[300] : Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: goldColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(color: isRecommended ? Colors.white : Colors.black87, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecommended ? goldColor : Colors.grey[100],
                  foregroundColor: isRecommended ? Colors.black : Colors.black,
                  elevation: 0,
                ),
                child: FittedBox( // Fix 2: Ensure button text fits
                  fit: BoxFit.scaleDown,
                  child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
