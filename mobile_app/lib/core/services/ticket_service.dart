import '../api/django_api_client.dart';

/// Service for handling Event Ticket purchases and retrieval.
///
/// **Features:**
/// - Create a ticket payment intent (Tier-based).
/// - Retrieve User's Tickets (with QR data).
class TicketService {
  final _apiClient = DjangoApiClient();

  /// Creates a payment intent for a specific tier.
  /// - Uses canonical backend endpoint: `/api/payments/create-payment-intent/`.
  /// - `eventId` is kept for backwards compatibility in callers but not required by the API.
  Future<Map<String, dynamic>> purchaseTicket(int eventId, int tierId) async {
    final data = await _apiClient.post(
      'payments/create-payment-intent/',
      data: {'tier_id': tierId},
    );
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const DjangoApiException(
      message: 'Unexpected ticket payment response.',
      type: DjangoApiErrorType.unknown,
    );
  }

  /// Retrieves all tickets purchased by the current user.
  /// - Returns a list of tickets, typically including QR code data.
  Future<List<dynamic>> getMyTickets() async {
    final data = await _apiClient.get('events/my-tickets/');
    if (data is List<dynamic>) {
      return data;
    }
    throw const DjangoApiException(
      message: 'Unexpected tickets response.',
      type: DjangoApiErrorType.unknown,
    );
  }
}
