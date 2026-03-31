import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/admin_api_service.dart';
import '../../../../shared_widgets/user_avatar.dart';

class UserPickerDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onUserSelected;
  const UserPickerDialog({super.key, required this.onUserSelected});

  @override
  State<UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<UserPickerDialog> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;
  Timer? _debounce;
  final _api = AdminApiService();

  @override
  void initState() {
    super.initState();
    _search(''); 
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (mounted) setState(() => _loading = true);
      try {
        final results = await _api.searchUsers(query);
        if (mounted) setState(() => _results = results);
      } catch (e) {
        if (kDebugMode) print("User Search Error: $e");
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 650),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Select User", 
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 24,
                  ),
                ],
              ),
            ),
            
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search by name or email...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_loading) 
                           const Padding(
                             padding: EdgeInsets.only(right: 8),
                             child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                           ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                                _searchController.clear();
                                _search('');
                                setState(() {});
                            },
                          ),
                      ],
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _search,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Result List
            Expanded(
              child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                  ? Center(child: Text("No users found", style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final user = _results[index];
                        final String first = user['first_name'] ?? '';
                        final String last = user['last_name'] ?? '';
                        final String fullName = first.isNotEmpty ? "$first $last" : (user['username'] ?? 'No Name');
                        
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          leading: UserAvatar(
                            imageUrl: user['photo_url'] ?? user['photo'],
                            firstName: user['first_name'],
                            lastName: user['last_name'],
                            username: user['username'],
                            radius: 20,
                          ),
                          title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(user['email'] ?? user['username'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          onTap: () {
                            widget.onUserSelected(user);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
