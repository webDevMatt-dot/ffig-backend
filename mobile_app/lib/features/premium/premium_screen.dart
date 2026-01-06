import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  List<dynamic> _vipPerks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPremiumData();
  }

  Future<void> _fetchPremiumData() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    const String baseUrl = 'https://ffig-api.onrender.com/api/premium/';

    try {
      final response = await http.get(Uri.parse(baseUrl), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _vipPerks = data['exclusive_data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("VIP LOUNGE"), backgroundColor: Colors.amber, foregroundColor: Colors.black),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _vipPerks.length,
            itemBuilder: (context, index) {
              return Card(
                color: Colors.black87,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text(_vipPerks[index], style: const TextStyle(color: Colors.white)),
                ),
              );
            },
          ),
    );
  }
}
