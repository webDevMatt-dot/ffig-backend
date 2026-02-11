import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/constants.dart';

/// Service for handling Event Ticket purchases and retrieval.
///
/// **Features:**
/// - Purchase Tickets (Tier-based).
/// - Retrieve User's Tickets (with QR data).
class TicketService {
  final _storage = const FlutterSecureStorage();

  /// Purchases a ticket for a specific event tier.
  /// - Sends `tier_id` to the backend.
  /// - Returns transaction data on success (201).
  Future<Map<String, dynamic>> purchaseTicket(int eventId, int tierId) async {
    final token = await _storage.read(key: 'access_token');
    final url = Uri.parse('${baseUrl}events/$eventId/purchase/');
    
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'tier_id': tierId}),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to purchase ticket: ${response.body}');
    }
  }

  /// Retrieves all tickets purchased by the current user.
  /// - Returns a list of tickets, typically including QR code data.
  Future<List<dynamic>> getMyTickets() async {
    final token = await _storage.read(key: 'access_token');
    final url = Uri.parse('${baseUrl}events/my-tickets/');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load tickets');
    }
  }
}

