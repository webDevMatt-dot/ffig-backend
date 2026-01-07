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

  // Upload Founder Profile
  Future<void> createFounderProfile(Map<String, String> fields, dynamic imageFile) async {
    await _uploadWithImage('founder', fields, imageFile, 'photo');
  }

  // Create Flash Alert (JSON)
  Future<void> createFlashAlert(Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/alerts/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create alert: ${response.body}');
    }
  }
  
  // Create Ticker Item (JSON)
  Future<void> createTickerItem(Map<String, dynamic> data) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/ticker/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create ticker item: ${response.body}');
    }
  }

  // Helper for Multipart requests (Handles Web (Uint8List) and Mobile (File))
  Future<void> _uploadWithImage(String endpoint, Map<String, String> fields, dynamic imageFile, String fileField) async {
    final token = await _getToken();
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/$endpoint/'));
    
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(fields);

    if (imageFile != null) {
      if (kIsWeb) {
        // Web: imageFile should be Uint8List (bytes) or platform file with bytes
        // Assuming imageFile is Uint8List for simplicity in this helper, 
        // or a PlatformFile wrapper. Let's assume bytes for now.
        // We need the filename too.
         if (imageFile is List<int>) {
             request.files.add(http.MultipartFile.fromBytes(
              fileField,
              imageFile,
              filename: 'upload.jpg', // Default name
              contentType: MediaType('image', 'jpeg'),
            ));
         }
      } else if (imageFile is File) {
        // Mobile/Desktop
        request.files.add(await http.MultipartFile.fromPath(
          fileField,
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ));
      } else if (imageFile is String) {
         // Path string
         request.files.add(await http.MultipartFile.fromPath(
          fileField,
          imageFile,
          contentType: MediaType('image', 'jpeg'),
        ));
      }
    }

    final response = await request.send();
    if (response.statusCode != 201) {
      final respStr = await response.stream.bytesToString();
      throw Exception('Failed to upload: $respStr');
    }
  }
}
