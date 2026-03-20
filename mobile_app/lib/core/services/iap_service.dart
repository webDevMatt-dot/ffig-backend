import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app/core/api/constants.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  void init() {
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription?.cancel();
    }, onError: (error) {
      if (kDebugMode) print('IAP Error: $error');
    });
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        if (kDebugMode) print('Purchase is pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          if (kDebugMode) print('Purchase Error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          bool valid = await _verifyPurchaseOnBackend(purchaseDetails);
          if (valid && kDebugMode) {
             print('Purchase verified successfully!');
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> _verifyPurchaseOnBackend(PurchaseDetails purchaseDetails) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null) return false;

      final serverVerificationData = purchaseDetails.verificationData.serverVerificationData;
      String platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
      
      final url = Uri.parse('${baseUrl}payments/verify-subscription/');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'platform': platform,
          'receipt_data': serverVerificationData,
          'product_id': purchaseDetails.productID,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Backend verification error: $e');
      return false;
    }
  }
}
