import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'constants.dart';

class AdminService {
  final _storage = const FlutterSecureStorage();

  Future<bool> resetUserPassword(int userId, String newPassword) async {
    final token = await _storage.read(key: 'access_token');
    final url = Uri.parse('${baseUrl}admin/reset-password/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Admin Reset Error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Admin Reset Exception: $e');
      return false;
    }
  }
}
