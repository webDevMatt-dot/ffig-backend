import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../api/django_api_client.dart';

class StripeService {
  static final StripeService _instance = StripeService._internal();
  factory StripeService() => _instance;
  StripeService._internal();

  final _apiClient = DjangoApiClient();

  /// Processes a ticket purchase using the native Stripe Payment Sheet.
  /// 
  /// 1. Calls our backend `/create-payment-intent/` to get the `clientSecret`.
  /// 2. Initializes the native Payment Sheet with `Stripe.instance.initPaymentSheet`.
  /// 3. Presents the sheet (`Stripe.instance.presentPaymentSheet`).
  Future<bool> purchaseTicket({required int tierId, int quantity = 1}) async {
    try {
      final data = await _apiClient.post(
        'payments/create-payment-intent/',
        data: {
          'tier_id': tierId,
          'quantity': quantity,
        },
      );

      if (data is! Map<String, dynamic>) {
        throw Exception("Unexpected payment response.");
      }
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
    } on DjangoApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (kDebugMode) print("General Exception during payment: $e");
      rethrow;
    }
  }

  /// Request a Stripe Connect onboarding link for event organizers
  Future<String?> getConnectOnboardingLink() async {
    try {
      final data = await _apiClient.post('payments/connect/create-account/');
      if (data is Map<String, dynamic>) {
        return data['url']?.toString();
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
      final data = await _apiClient.get('payments/connect/status/');
      if (data is Map<String, dynamic>) {
        return data;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print("Error checking Connect status: $e");
      return null;
    }
  }
  /// Process a free ticket registration
  Future<bool> registerFreeTicket({required int tierId, int quantity = 1, String? firstName, String? lastName, String? email}) async {
    try {
      await _apiClient.post(
        'payments/free-registration/',
        data: {
          'tier_id': tierId, 
          'quantity': quantity,
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
        },
      );
      return true;
    } on DjangoApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (kDebugMode) print("Error during free registration: $e");
      rethrow;
    }
  }

  /// Processes a membership upgrade using the native Stripe Payment Sheet.
  Future<bool> purchaseMembership({required String targetTier}) async {
    try {
      final data = await _apiClient.post(
        'payments/create-membership-payment-intent/',
        data: {'target_tier': targetTier},
      );

      if (data is! Map<String, dynamic>) {
        throw Exception("Unexpected membership payment response.");
      }
      final clientSecret = data['clientSecret'];

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Female Founders Initiative',
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return false;
      rethrow;
    } on DjangoApiException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (kDebugMode) print("Membership Payment Error: $e");
      rethrow;
    }
  }
}
