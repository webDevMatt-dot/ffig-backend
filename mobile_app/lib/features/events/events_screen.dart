import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'event_detail_screen.dart';
import '../../core/api/constants.dart'; // Import the details screen

import 'package:intl/intl.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    const String endpoint = '${baseUrl}events/';

    final headers = <String, String>{};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    try {
      final response = await http.get(Uri.parse(endpoint), headers: headers);
      if (response.statusCode == 200) {
        setState(() => _events = jsonDecode(response.body));
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("UPCOMING EVENTS")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 120,
              ),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                
                // Parse date
                DateTime date;
                try {
                    date = DateTime.parse(event['date']);
                } catch (_) {
                    date = DateTime.now(); // Fallback to current date if parsing fails
                }
                final day = DateFormat('dd').format(date);
                final month = DateFormat('MM').format(date);
                final year = DateFormat('yyyy').format(date);

                return Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EventDetailScreen(event: event),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Image.network(
                              event['image_url'],
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            // Date / Category Label (Top Right)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  // DISPLAY FORMAT: dd-MM-yyyy
                                  "$day-$month-$year",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event['title'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                event['location'],
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
