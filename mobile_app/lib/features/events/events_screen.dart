import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'event_detail_screen.dart';
import 'event_detail_screen.dart';
import '../../core/api/constants.dart'; // Import the details screen
import 'package:cached_network_image/cached_network_image.dart';

import 'package:intl/intl.dart';

/// Displays a list of All Events (Upcoming and Past).
///
/// **Features:**
/// - Fetches events from `events/` endpoint.
/// - Separates events into "Upcoming" and "Past" sections based on date.
/// - Displays generic event cards with image, date, and location.
/// - Navigates to `EventDetailScreen` on tap.
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

  /// Fetches all events from the backend.
  /// - Uses `FlutterSecureStorage` for auth token.
  /// - Sets `_events` state on success.
  /// - Handles loading state `_isLoading`.
  Future<void> _fetchEvents() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    final String endpoint = '${baseUrl}events/';

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
      appBar: AppBar(title: const Text("EVENTS")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildEventsList(),
    );
  }

  /// Builds the main list view.
  /// - Splits events into Upcoming and Past.
  /// - Renders grouped sections.
  Widget _buildEventsList() {
    final now = DateTime.now();
    final upcomingEvents = <dynamic>[];
    final pastEvents = <dynamic>[];

    // Partition events
    for (final event in _events) {
      try {
        final eventDate = DateTime.parse(event['date']);
        if (eventDate.isAfter(now)) {
          upcomingEvents.add(event);
        } else {
          pastEvents.add(event);
        }
      } catch (_) {
        upcomingEvents.add(event);
      }
    }

    return ListView(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 120,
      ),
      children: [
        // Upcoming Events Section
        ..._buildEventSection(upcomingEvents, "UPCOMING EVENTS", context),

        // Past Events Section
        if (pastEvents.isNotEmpty) ...[
          const SizedBox(height: 32),
          ..._buildEventSection(pastEvents, "PAST EVENTS", context),
        ],
      ],
    );
  }

  /// Generates a list of event cards for a section.
  /// - `events`: List of event data.
  /// - `title`: Section header title.
  List<Widget> _buildEventSection(
      List<dynamic> events, String title, BuildContext context) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.grey[700],
                letterSpacing: 0.3,
              ),
        ),
      ),
      ...List.generate(events.length, (index) {
        final event = events[index];

        // Parse date
        DateTime date;
        try {
          date = DateTime.parse(event['date']);
        } catch (_) {
          date = DateTime.now();
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
                    CachedNetworkImage(
                      imageUrl: event['image_url'],
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
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
      }),
    ];
  }
}
