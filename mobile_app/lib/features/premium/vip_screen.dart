import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/constants.dart'; // Your baseUrl

/// A screen displaying exclusive VIP resources.
///
/// **Features:**
/// - Tabbed view for Magazines, Masterclasses, and Newsletters.
/// - Fetches content based on category code.
class VipScreen extends StatefulWidget {
  const VipScreen({super.key});

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Tabs for the top bar
  final List<String> _tabs = ["Magazines", "Masterclasses", "Newsletters"];
  final List<String> _codes = ["MAG", "CLASS", "NEWS"]; // Matches Django Model keys

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("VIP Exclusive"),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _codes.map((code) => _ResourceList(categoryCode: code)).toList(),
      ),
    );
  }
}

// --- SUB-WIDGET TO FETCH LISTS ---
class _ResourceList extends StatefulWidget {
  final String categoryCode;
  const _ResourceList({required this.categoryCode});

  @override
  State<_ResourceList> createState() => _ResourceListState();
}

class _ResourceListState extends State<_ResourceList> {
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  /// Fetches resource items for the specific category.
  /// - Uses `http` to query `/resources/?category=CODE`.
  /// - Updates local list of items.
  Future<void> _fetchItems() async {
    try {
      // API CALL: Ask for only this category
      final url = '${baseUrl}resources/?category=${widget.categoryCode}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
          _items = jsonDecode(response.body);
          _isLoading = false;
        });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) throw 'Could not launch $url';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text("No content yet. Check back soon!"));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _launchURL(item['url']),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. THUMBNAIL (If it exists)
                if (item['thumbnail_url'] != null)
                  Image.network(
                    item['thumbnail_url'],
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (c,e,s) => Container(height: 150, color: Colors.grey[900], child: const Icon(Icons.star, color: Colors.white54, size: 50)),
                  ),
                
                // 2. TEXT CONTENT
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(item['description'], maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 16),
                      Row(
                        children: const [
                          Text("ACCESS NOW", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 16, color: Colors.amber)
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
