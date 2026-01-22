import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../core/api/constants.dart';
import '../../core/theme/ffig_theme.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  List<dynamic> _resources = [];
  bool _isLoading = true;
  String _selectedFilter = "ALL"; 

  final Map<String, String> _categoryLabels = {
    'GEN': 'Resource',
    'MAG': 'Magazine',
    'NEWS': 'Newsletter',
    'CLASS': 'Masterclass',
    'POD': 'Podcast',
  };

  @override
  void initState() {
    super.initState();
    _fetchResources();
  }

  Future<void> _fetchResources() async {
    setState(() => _isLoading = true);
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    
    // Build URL with filter
    String url = '${baseUrl}resources/'; // Use constant baseUrl
    
    if (_selectedFilter != "ALL") {
      url += "?category=$_selectedFilter";
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) setState(() => _resources = jsonDecode(response.body));
      }
    } catch (e) {
      if (kDebugMode) print(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "RESOURCE VAULT", 
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          )
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.iconTheme.color),
      ),
      body: Column(
        children: [
          // Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip("All", "ALL"),
                const SizedBox(width: 8),
                _buildFilterChip("Magazines", "MAG"),
                const SizedBox(width: 8),
                _buildFilterChip("Masterclasses", "CLASS"),
                const SizedBox(width: 8),
                _buildFilterChip("Newsletters", "NEWS"),
                const SizedBox(width: 8),
                _buildFilterChip("General", "GEN"),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _resources.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.library_books_outlined, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text("No resources found.", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _resources.length,
                      itemBuilder: (context, index) {
                        final res = _resources[index];
                        return _buildResourceCard(res);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return InkWell(
      onTap: () {
        if (!isSelected) {
          setState(() => _selectedFilter = value);
          _fetchResources();
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? FfigTheme.primaryBrown : theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? FfigTheme.primaryBrown : theme.dividerColor,
          ),
          boxShadow: isSelected 
             ? [BoxShadow(color: FfigTheme.primaryBrown.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]
             : null
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13
          ),
        ),
      ),
    );
  }

  Widget _buildResourceCard(dynamic res) {
     final theme = Theme.of(context);
     final isDark = theme.brightness == Brightness.dark;

     return Container(
       margin: const EdgeInsets.only(bottom: 20),
       decoration: BoxDecoration(
         color: theme.cardColor,
         borderRadius: BorderRadius.circular(16),
         border: isDark ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
         boxShadow: isDark ? null : [
           BoxShadow(
             color: Colors.black.withOpacity(0.06),
             blurRadius: 10,
             offset: const Offset(0, 4)
           ) 
         ]
       ),
       child: InkWell(
         onTap: () => _launchURL(res['url']),
         borderRadius: BorderRadius.circular(16),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // Image Container with Aspect Ratio
             ClipRRect(
               borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
               child: Stack(
                 children: [
                   res['thumbnail_url'] != null && res['thumbnail_url'].isNotEmpty
                     ? Image.network(
                         res['thumbnail_url'],
                         height: 180,
                         width: double.infinity,
                         fit: BoxFit.cover,
                         errorBuilder: (context, error, stackTrace) => Container(
                           height: 180, 
                           color: theme.colorScheme.surfaceContainerHighest,
                           child: Center(child: Icon(Icons.image_not_supported, color: theme.disabledColor)),
                         ),
                       )
                     : Container(
                       height: 180,
                       width: double.infinity,
                       color: FfigTheme.primaryBrown.withOpacity(0.1),
                       child: Icon(Icons.article_outlined, size: 64, color: FfigTheme.primaryBrown.withOpacity(0.5)),
                     ),
                   
                   // Category Badge
                   Positioned(
                     top: 12,
                     left: 12,
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                       decoration: BoxDecoration(
                         color: Colors.black.withOpacity(0.7),
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.white.withOpacity(0.2))
                       ),
                       child: Text(
                         (_categoryLabels[res['category']] ?? 'Resource').toUpperCase(),
                         style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                       ),
                     ),
                   )
                 ],
               ),
             ),
             
             // Content
             Padding(
               padding: const EdgeInsets.all(16),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     res['title'],
                     style: theme.textTheme.titleMedium?.copyWith(
                       fontSize: 18,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     res['description'],
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                     style: theme.textTheme.bodyMedium?.copyWith(
                       height: 1.4,
                     ),
                   ),
                   const SizedBox(height: 16),
                   Row(
                     children: [
                       Text(
                         "READ MORE", 
                         style: TextStyle(
                           color: FfigTheme.primaryBrown, 
                           fontWeight: FontWeight.bold, 
                           fontSize: 12,
                           letterSpacing: 1.0
                         )
                       ),
                       const SizedBox(width: 4),
                       const Icon(Icons.arrow_forward, size: 14, color: FfigTheme.primaryBrown)
                     ],
                   )
                 ],
               ),
             )
           ],
         ),
       ),
     );
  }
}
