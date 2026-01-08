import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

class AdminApiService {
  static const String _baseUrl = 'https://ffig-api.onrender.com/api/home';
  final _storage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    return await _storage.read(key: 'access_token');
  }

  // Generic GET
  Future<List<dynamic>> fetchItems(String endpoint) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/$endpoint/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load items: ${response.statusCode}');
    }
  }

  // Generic DELETE
  Future<void> deleteItem(String endpoint, int id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/$endpoint/$id/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete item');
    }
  }

  // Upload Hero Item
  Future<void> createHeroItem(Map<String, String> fields, dynamic imageFile) async {
    await _uploadWithImage('hero', fields, imageFile, 'image');
  }

  // Update Hero Item
  Future<void> updateHeroItem(String id, Map<String, String> fields, dynamic imageFile) async {
    await _uploadWithImage('hero', fields, imageFile, 'image', id: id, method: 'PATCH');
  }

  // Upload Founder Profile
  Future<void> createFounderProfile(Map<String, String> fields, dynamic imageFile) async {
    await _uploadWithImage('founder', fields, imageFile, 'photo');
  }

  // Update Founder Profile
  Future<void> updateFounderProfile(String id, Map<String, String> fields, dynamic imageFile) async {
    await _uploadWithImage('founder', fields, imageFile, 'photo', id: id, method: 'PATCH');
  }

  // Create Flash Alert (JSON)
  Future<void> createFlashAlert(Map<String, dynamic> data) async {
    await _postJson('alerts', data);
  }

  // Update Flash Alert
  Future<void> updateFlashAlert(String id, Map<String, dynamic> data) async {
    await _patchJson('alerts', id, data);
  }
  
  // Create Ticker Item (JSON)
  Future<void> createTickerItem(Map<String, dynamic> data) async {
    await _postJson('ticker', data);
  }

  // Update Ticker Item
  Future<void> updateTickerItem(String id, Map<String, dynamic> data) async {
    await _patchJson('ticker', id, data);
  }

  // --- EVENTS ---
  static const String _eventsBaseUrl = 'https://ffig-api.onrender.com/api/events';

  Future<List<dynamic>> fetchEvents() async {
    final token = await _getToken();
    final response = await http.get(Uri.parse('$_eventsBaseUrl/'), headers: {'Authorization': 'Bearer $token'});
     if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load events: ${response.statusCode}');
    }
  }

  Future<void> createEvent(Map<String, dynamic> data) async {
    final token = await _getToken();
     final response = await http.post(
      Uri.parse('$_eventsBaseUrl/'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(data)
    );
     if (response.statusCode != 201) throw Exception('Failed to create event: ${response.body}');
  }

  Future<void> updateEvent(int id, Map<String, dynamic> data) async {
      final token = await _getToken();
     final response = await http.patch(
      Uri.parse('$_eventsBaseUrl/$id/'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(data)
    );
     if (response.statusCode != 200) throw Exception('Failed to update event: ${response.body}');
  }

  Future<void> createTicketTier(Map<String, dynamic> data) async {
    final token = await _getToken();
     final response = await http.post(
      Uri.parse('$_eventsBaseUrl/tiers/'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(data)
    );
     if (response.statusCode != 201) throw Exception('Failed to create tier: ${response.body}');
  }

  Future<void> deleteTicketTier(int id) async {
    final token = await _getToken();
     final response = await http.delete(
      Uri.parse('$_eventsBaseUrl/tiers/$id/'),
      headers: {'Authorization': 'Bearer $token'}
    );
     if (response.statusCode != 204) throw Exception('Failed to delete tier');
  }

  Future<void> deleteEvent(int id) async {
    final token = await _getToken();
     final response = await http.delete(Uri.parse('$_eventsBaseUrl/$id/delete/'), headers: {'Authorization': 'Bearer $token'});
     if (response.statusCode != 204) throw Exception('Failed to delete event');
  }

  // Sub-Items Generic Helpers
  Future<void> _createSubItem(String endpoint, Map<String, dynamic> data) async {
    final token = await _getToken();
     final response = await http.post(
      Uri.parse('$_eventsBaseUrl/$endpoint/'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(data)
    );
     if (response.statusCode != 201) throw Exception('Failed to create item');
  }

  Future<void> _deleteSubItem(String endpoint, int id) async {
    final token = await _getToken();
     final response = await http.delete(
      Uri.parse('$_eventsBaseUrl/$endpoint/$id/'),
      headers: {'Authorization': 'Bearer $token'}
    );
     if (response.statusCode != 204) throw Exception('Failed to delete item');
  }

  // Speakers
  Future<void> createEventSpeaker(Map<String, dynamic> data) async => _createSubItem('speakers', data);
  Future<void> deleteEventSpeaker(int id) async => _deleteSubItem('speakers', id);

  // Agenda
  Future<void> createAgendaItem(Map<String, dynamic> data) async => _createSubItem('agenda', data);
  Future<void> deleteAgendaItem(int id) async => _deleteSubItem('agenda', id);

  // FAQ
  Future<void> createEventFAQ(Map<String, dynamic> data) async => _createSubItem('faqs', data);
  Future<void> deleteEventFAQ(int id) async => _deleteSubItem('faqs', id);

  // Helpers
  Future<void> _postJson(String endpoint, Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/$endpoint/'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
     if (response.statusCode != 201) throw Exception('Failed to create: ${response.body}');
  }

  Future<void> _patchJson(String endpoint, String id, Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('$_baseUrl/$endpoint/$id/'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
     if (response.statusCode != 200) throw Exception('Failed to update: ${response.body}');
  }

  // Helper for Multipart requests (Handles Web (Uint8List) and Mobile (File))
  Future<void> _uploadWithImage(String endpoint, Map<String, String> fields, dynamic imageFile, String fileField, {String? id, String method = 'POST'}) async {
    final token = await _getToken();
    final url = id != null ? '$_baseUrl/$endpoint/$id/' : '$_baseUrl/$endpoint/';
    
    var request = http.MultipartRequest(method, Uri.parse(url));
    
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);

    if (imageFile != null) {
      if (kIsWeb) {
         if (imageFile is List<int>) {
             request.files.add(http.MultipartFile.fromBytes(
              fileField,
              imageFile,
              filename: 'upload.jpg', 
              contentType: MediaType('image', 'jpeg'),
            ));
         }
      } else if (imageFile is File) {
        request.files.add(await http.MultipartFile.fromPath(
          fileField,
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      }
    }

    final response = await request.send();
    if (response.statusCode != 200 && response.statusCode != 201) {
      final respStr = await response.stream.bytesToString();
      throw Exception('Failed to upload/update: $respStr');
    }
  }
}
