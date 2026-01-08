import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/constants.dart';

class TicketService {
  final _storage = const FlutterSecureStorage();

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
