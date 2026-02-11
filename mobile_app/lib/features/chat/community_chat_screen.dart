import 'package:flutter/material.dart';
import '../../core/services/membership_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'chat_screen.dart';
import '../../core/api/constants.dart';

class CommunityChatScreen extends StatefulWidget {
  const CommunityChatScreen({super.key});

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  bool _isLoading = true;
  int? _conversationId;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  /// Initializes the community chat.
  /// - Checks permissions via `MembershipService`.
  /// - Fetches the community conversation ID from `/chat/community/`.
  Future<void> _initChat() async {
    // 1. Check Permissions
    if (!MembershipService.canCommunityChat) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
          MembershipService.showUpgradeDialog(context, "Community Chat");
          Navigator.pop(context);
       });
       return;
    }

    // 2. Fetch Community Conversation ID
    try {
      final token = await const FlutterSecureStorage().read(key: 'access_token');
      final response = await http.get(
        Uri.parse('${baseUrl}chat/community/'),
        headers: {'Authorization': 'Bearer $token'}
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
           setState(() {
             _conversationId = data['id'];
             _isLoading = false;
           });
        }
      } else {
        throw Exception("Failed to load chat: ${response.statusCode} | ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("COMMUNITY CHAT")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_conversationId != null) {
      // Reuse the generic ChatScreen
      return ChatScreen(
        conversationId: _conversationId,
        recipientName: "Community Chat",
        isCommunity: true,
      );
    }
    
    return Scaffold(
      appBar: AppBar(title: const Text("COMMUNITY CHAT")),
      body: const Center(child: Text("Unable to load community chat.")),
    );
  }
}

