import 'package:flutter/material.dart';
import '../../core/services/membership_service.dart';
import '../../core/theme/ffig_theme.dart';

class CommunityChatScreen extends StatefulWidget {
  const CommunityChatScreen({super.key});

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {

  @override
  void initState() {
    super.initState();
    // Double check permissions (though navigation should catch it)
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (!MembershipService.canCommunityChat) {
          MembershipService.showUpgradeDialog(context, "Community Chat");
          Navigator.pop(context);
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!MembershipService.canCommunityChat) return const Scaffold(); // Safety

    return Scaffold(
      appBar: AppBar(
        title: const Text("COMMUNITY CHAT"),
        actions: [
           IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                 _buildMessage("System", "Welcome to the FFIG Community Chat! Connect with fellow founders here.", true),
                 _buildMessage("Sarah Jenkins", "Hi everyone! Excited to be part of this community.", false),
                 _buildMessage("Maria Rodriquez", "Has anyone tried the new grant application process?", false),
              ],
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessage(String sender, String text, bool isSystem) {
    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           CircleAvatar(radius: 16, backgroundColor: FfigTheme.primaryBrown, child: Text(sender[0], style: const TextStyle(color: Colors.white, fontSize: 12))),
           const SizedBox(width: 8),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(sender, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                 const SizedBox(height: 4),
                 Container(
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(
                     color: Colors.grey.withOpacity(0.05),
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: Colors.grey.withOpacity(0.1))
                   ),
                   child: Text(text),
                 )
               ],
             ),
           )
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Expanded(
             child: TextField(
               decoration: InputDecoration(
                 hintText: "Type a message...",
                 filled: true,
                 fillColor: Colors.grey.withOpacity(0.05),
                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
               ),
             ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: FfigTheme.primaryBrown,
            child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: () {}),
          )
        ],
      ),
    );
  }
}
