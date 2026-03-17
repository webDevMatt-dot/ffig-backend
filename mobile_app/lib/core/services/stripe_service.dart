import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StripeService {
  static final StripeService _instance = StripeService._internal();
  factory StripeService() => _instance;
  StripeService._internal();

  // Replace with your actual backend URL depending on environment
  final String _baseUrl = kDebugMode 
      ? 'http://10.0.2.2:8000/api/payments' // Android Emulator local address
      : 'https://femalefoundersinitiativeglobal.onrender.com/api/payments';

  final _storage = const FlutterSecureStorage();

  /// Processes a ticket purchase using the native Stripe Payment Sheet.
  /// 
  /// 1. Calls our backend `/create-payment-intent/` to get the `clientSecret`.
  /// 2. Initializes the native Payment Sheet with `Stripe.instance.initPaymentSheet`.
  /// 3. Presents the sheet (`Stripe.instance.presentPaymentSheet`).
  Future<bool> purchaseTicket({required int tierId}) async {
    try {
      // 1. Get token
      final token = await _storage.read(key: 'access_token');
      if (token == null) throw Exception("User not authenticated.");

      // 2. Call backend to create PaymentIntent
      final url = Uri.parse('$_baseUrl/create-payment-intent/');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'tier_id': tierId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to create payment intent: ${response.body}");
      }

      final data = jsonDecode(response.body);
      final clientSecret = data['clientSecret'];

      if (clientSecret == null) {
        throw Exception("Server did not return a valid client secret.");
      }

      // 3. Initialize the native payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Female Founders Initiative',
          // Set to true for Apple Pay / Google Pay support
          // googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'US', testEnv: true),
          // applePay: const PaymentSheetApplePay(merchantCountryCode: 'US'),
        ),
      );

      // 4. Present the payment sheet
      await Stripe.instance.presentPaymentSheet();
      
      return true; // Payment succeeded!
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        if (kDebugMode) print("User canceled the payment sheet.");
        return false;
      }
      if (kDebugMode) print("Stripe Exception: ${e.error.localizedMessage}");
      rethrow;
    } catch (e) {
      if (kDebugMode) print("General Exception during payment: $e");
      rethrow;
    }
  }

  /// Request a Stripe Connect onboarding link for event organizers
  Future<String?> getConnectOnboardingLink() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) return null;

      final url = Uri.parse('$_baseUrl/connect/create-account/');
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'];
      }
      return null;
    } catch (e) {
      if (kDebugMode) print("Error getting Connect link: $e");
      return null;
    }
  }

  /// Check the onboarding status of the current user's connected account
  Future<Map<String, dynamic>?> getConnectStatus() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) return null;

      final url = Uri.parse('$_baseUrl/connect/status/');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print("Error checking Connect status: $e");
      return null;
    }
  }
  /// Process a free ticket registration
  Future<bool> registerFreeTicket({required int tierId}) async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) throw Exception("User not authenticated.");

      final url = Uri.parse('$_baseUrl/free-registration/');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'tier_id': tierId}),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? "Failed to register for free ticket.");
      }
    } catch (e) {
      if (kDebugMode) print("Error during free registration: $e");
      rethrow;
    }
  }
}
