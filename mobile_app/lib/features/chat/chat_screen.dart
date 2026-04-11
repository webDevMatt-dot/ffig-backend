import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:async'; // For timer
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/ffig_theme.dart';
import '../../core/api/constants.dart';
import '../../shared_widgets/user_avatar.dart';
import '../community/public_profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../premium/widgets/story_viewer.dart';
import '../premium/widgets/full_screen_media_viewer.dart';

/// The Main Chat Interface.
class ChatScreen extends StatefulWidget {
  final int? conversationId;
  final int? recipientId;
  final String recipientName;
  final bool isCommunity;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.recipientId,
    required this.recipientName,
    this.isCommunity = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  List<dynamic> _messages = [];
  List<dynamic> _groupedMessages = [];
  int? _activeConversationId;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<int> _searchResults = [];
  int _currentSearchIndex = 0;

  Timer? _searchDebounce;
  Timer? _timer;
  bool _isLoading = true;
  Map<String, dynamic>? _replyMessage;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  bool _showScrollToBottom = false;
  int? _highlightedMessageId;
  bool _isSendingAttachment = false;
  bool _isEmojiVisible = false;
  bool _isTypingMessage = false;

  static const List<String> _emojiPalette = [
    '😀',
    '😁',
    '😂',
    '🤣',
    '😃',
    '😄',
    '😅',
    '😆',
    '😉',
    '😊',
    '😋',
    '😎',
    '😍',
    '😘',
    '🥰',
    '😗',
    '😙',
    '😚',
    '🙂',
    '🤗',
    '🤩',
    '🤔',
    '🤨',
    '😐',
    '😑',
    '😶',
    '🙄',
    '😏',
    '😣',
    '😥',
    '😮',
    '🤐',
    '😯',
    '😪',
    '😫',
    '🥱',
    '😴',
    '😌',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🫠',
    '🤭',
    '🫢',
    '🫣',
    '🤫',
    '🤥',
    '😇',
    '🥳',
    '🥺',
    '😢',
    '😭',
    '😤',
    '😠',
    '😡',
    '🤬',
    '🤯',
    '😳',
    '🥵',
    '🥶',
    '👍',
    '👎',
    '👏',
    '🙌',
    '🙏',
    '💪',
    '👀',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🤎',
    '💔',
    '🔥',
    '✨',
    '🎉',
    '✅',
    '❌',
    '💯',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleComposerTextChanged);
    _activeConversationId = widget.conversationId;
    _fetchMessages();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => _fetchMessages(silent: true),
    );
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus && _isEmojiVisible) {
        setState(() => _isEmojiVisible = false);
      }
    });

    _itemPositionsListener.itemPositions.addListener(() {
      final positions = _itemPositionsListener.itemPositions.value;
      if (positions.isNotEmpty) {
        final isAtBottom = positions.any((p) => p.index == 0);
        if (_showScrollToBottom == isAtBottom) {
          setState(() => _showScrollToBottom = !isAtBottom);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchDebounce?.cancel();
    _controller.removeListener(_handleComposerTextChanged);
    _controller.dispose();
    _searchController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _handleComposerTextChanged() {
    final isTypingNow = _controller.text.trim().isNotEmpty;
    if (isTypingNow != _isTypingMessage) {
      setState(() => _isTypingMessage = isTypingNow);
    }
  }

  void _groupMessages() {
    final List<dynamic> grouped = [];
    DateTime? lastDate;

    for (var msg in _messages) {
      final createdAt = DateTime.parse(msg['created_at']).toLocal();
      final date = DateTime(createdAt.year, createdAt.month, createdAt.day);

      if (lastDate == null || date != lastDate) {
        grouped.add({'is_header': true, 'date': date});
        lastDate = date;
      }
      grouped.add(msg);
    }
    _groupedMessages = grouped;
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return "Today";
    if (date == yesterday) return "Yesterday";
    return DateFormat('MMMM d, yyyy').format(date);
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (_activeConversationId == null && widget.recipientId != null) {
      final id = await _fetchConversationIdByRecipient(widget.recipientId!);
      if (id != null) {
        setState(() => _activeConversationId = id);
      } else {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }
    if (_activeConversationId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final token = await const FlutterSecureStorage().read(key: 'access_token');
    final String url =
        '${baseUrl}chat/conversations/$_activeConversationId/messages/';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _messages = jsonDecode(response.body);
            _groupMessages();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print(e);
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<int?> _fetchConversationIdByRecipient(int recipientId) async {
    try {
      final token = await const FlutterSecureStorage().read(
        key: 'access_token',
      );
      final response = await http.get(
        Uri.parse('${baseUrl}chat/conversations/?recipient_id=$recipientId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) return data[0]['id'];
      }
    } catch (e) {
      if (kDebugMode) print("Error resolving chat: $e");
    }
    return null;
  }

  Future<void> _checkAndOpenStory(int storyId) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final response = await http.get(
        Uri.parse('${baseUrl}members/stories/$storyId/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final storyData = jsonDecode(response.body);
        final domain = baseUrl.replaceAll('/api/', '');
        if (storyData['media_url'] != null) {
          String url = storyData['media_url'].toString();
          if (url.startsWith('/')) storyData['media_url'] = '$domain$url';
        }
        if (storyData['user_photo'] != null) {
          String photo = storyData['user_photo'].toString();
          if (photo.startsWith('/')) storyData['user_photo'] = '$domain$photo';
        }
        if (mounted) {
          showGeneralDialog(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'Story',
            barrierColor: Colors.black,
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (_, __, ___) => StoryViewer(
              stories: [storyData],
              initialIndex: 0,
              onGlobalClose: () => Navigator.pop(context),
            ),
          );
        }
      }
    } catch (e) {
      /* ignore */
    }
  }

  String? _normalizeImageUrl(dynamic rawUrl) {
    if (rawUrl == null) return null;
    final url = rawUrl.toString().trim();
    if (url.isEmpty || url == 'null') return null;
    final domain = baseUrl.replaceAll('/api/', '');
    if (url.startsWith('/')) return '$domain$url';
    return url;
  }

  String? _normalizeAttachmentUrl(dynamic rawUrl) {
    return _normalizeImageUrl(rawUrl);
  }

  String _messageTextForDisplay(Map<String, dynamic> msg) {
    final type = (msg['message_type'] ?? 'text').toString().toLowerCase();
    final text = (msg['text'] ?? '').toString();
    if (text.trim().isNotEmpty) return text;
    switch (type) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      case 'document':
        return 'Document';
      case 'audio':
        return 'Voice message';
      default:
        return 'Message';
    }
  }

  String _filenameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : url;
      return segment.isEmpty ? 'Document' : segment;
    } catch (_) {
      final parts = url.split('/');
      return parts.isNotEmpty ? parts.last : 'Document';
    }
  }

  void _toggleEmojiKeyboard() {
    if (_isEmojiVisible) {
      setState(() => _isEmojiVisible = false);
      FocusScope.of(context).requestFocus(_messageFocusNode);
      return;
    }
    _messageFocusNode.unfocus();
    setState(() => _isEmojiVisible = true);
  }

  void _insertEmoji(String emoji) {
    final oldValue = _controller.value;
    final fullText = oldValue.text;
    final start = oldValue.selection.start < 0
        ? fullText.length
        : oldValue.selection.start;
    final end = oldValue.selection.end < 0
        ? fullText.length
        : oldValue.selection.end;

    final newText = fullText.replaceRange(start, end, emoji);
    final newOffset = start + emoji.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  Widget _buildEmojiPanel(bool isDark) {
    return Container(
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171D25) : const Color(0xFFF2F2F5),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black12,
            width: 0.6,
          ),
        ),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        itemCount: _emojiPalette.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemBuilder: (_, index) {
          final emoji = _emojiPalette[index];
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _insertEmoji(emoji),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 24, height: 1.0),
              ),
            ),
          );
        },
      ),
    );
  }

  String _displayNameFromUser(
    Map<String, dynamic>? user, {
    String fallback = 'User',
  }) {
    final firstName = (user?['first_name'] ?? user?['name'] ?? '')
        .toString()
        .trim();
    final lastName = (user?['last_name'] ?? user?['surname'] ?? '')
        .toString()
        .trim();
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) return fullName;
    return (user?['username'] ?? user?['email'] ?? fallback).toString();
  }

  Map<String, dynamic>? _getDmRecipientFromMessages() {
    if (widget.isCommunity || widget.recipientId == null) return null;
    for (final raw in _messages.reversed) {
      final msg = raw as Map<String, dynamic>;
      final sender = msg['sender'] as Map<String, dynamic>?;
      final senderIdRaw = sender?['id'] ?? sender?['user_id'];
      final senderId = senderIdRaw is int
          ? senderIdRaw
          : int.tryParse(senderIdRaw?.toString() ?? '');
      if (senderId == widget.recipientId) return sender;
    }
    return null;
  }

  Future<void> _sendMessage() async {
    if (_isSendingAttachment) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_isEmojiVisible) {
      setState(() => _isEmojiVisible = false);
    }
    _controller.clear();

    final token = await const FlutterSecureStorage().read(key: 'access_token');
    final String url = '${baseUrl}chat/messages/send/';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'recipient_id': widget.recipientId,
          'conversation_id': _activeConversationId,
          if (_replyMessage != null) 'reply_to_id': _replyMessage!['id'],
        }),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (_activeConversationId == null)
          setState(() => _activeConversationId = data['conversation_id']);
        setState(() => _replyMessage = null);
        _fetchMessages(silent: true);
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_itemScrollController.isAttached)
            _itemScrollController.scrollTo(
              index: 0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
        });
      }
    } catch (e) {
      if (kDebugMode) print(e);
    }
  }

  Future<void> _sendAttachmentRequest({
    String? path,
    List<int>? bytes,
    required String filename,
    required String messageType,
  }) async {
    if (_isSendingAttachment) return;
    setState(() => _isSendingAttachment = true);

    final messenger = ScaffoldMessenger.of(context);
    final token = await const FlutterSecureStorage().read(key: 'access_token');
    final String url = '${baseUrl}chat/messages/send/';
    final String caption = _controller.text.trim();
    _controller.clear();

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';

      if (widget.recipientId != null) {
        request.fields['recipient_id'] = widget.recipientId.toString();
      }
      if (_activeConversationId != null) {
        request.fields['conversation_id'] = _activeConversationId.toString();
      }
      if (_replyMessage != null) {
        request.fields['reply_to_id'] = _replyMessage!['id'].toString();
      }
      if (caption.isNotEmpty) {
        request.fields['text'] = caption;
      }
      request.fields['message_type'] = messageType;

      if (bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes('attachment', bytes, filename: filename),
        );
      } else if (path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachment',
            path,
            filename: filename,
          ),
        );
      } else {
        throw Exception('No attachment payload provided.');
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        setState(() => _replyMessage = null);
        try {
          final data = jsonDecode(responseBody);
          if (_activeConversationId == null &&
              data is Map &&
              data['conversation_id'] != null) {
            final dynamic rawConversationId = data['conversation_id'];
            final int? conversationId = rawConversationId is int
                ? rawConversationId
                : int.tryParse(rawConversationId.toString());
            if (conversationId != null) {
              setState(() => _activeConversationId = conversationId);
            }
          }
        } catch (_) {}
        await _fetchMessages(silent: true);
        Future.delayed(const Duration(milliseconds: 120), () {
          if (_itemScrollController.isAttached) {
            _itemScrollController.scrollTo(
              index: 0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to send attachment: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print(e);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send attachment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingAttachment = false);
      }
    }
  }

  Future<void> _pickPhotoFromGallery() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    await _sendAttachmentRequest(
      path: picked.path,
      filename: picked.name,
      messageType: 'image',
    );
  }

  Future<void> _openCameraAndCapture() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked == null) return;
    await _sendAttachmentRequest(
      path: picked.path,
      filename: picked.name,
      messageType: 'image',
    );
  }

  Future<void> _pickVideoFromGallery() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked == null) return;
    await _sendAttachmentRequest(
      path: picked.path,
      filename: picked.name,
      messageType: 'video',
    );
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: kIsWeb,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'csv',
        'zip',
      ],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path != null) {
      await _sendAttachmentRequest(
        path: file.path!,
        filename: file.name,
        messageType: 'document',
      );
      return;
    }

    if (file.bytes != null) {
      await _sendAttachmentRequest(
        bytes: file.bytes!,
        filename: file.name,
        messageType: 'document',
      );
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      "Share",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _attachmentAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Photos',
                      color: const Color(0xFF1976D2),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickPhotoFromGallery();
                      },
                    ),
                    _attachmentAction(
                      icon: Icons.videocam_outlined,
                      label: 'Videos',
                      color: const Color(0xFF6A1B9A),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickVideoFromGallery();
                      },
                    ),
                    _attachmentAction(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      color: const Color(0xFF00897B),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openCameraAndCapture();
                      },
                    ),
                    _attachmentAction(
                      icon: Icons.insert_drive_file_outlined,
                      label: 'Document',
                      color: const Color(0xFF5D4037),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickDocument();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachmentAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 74,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchResults.clear();
        _currentSearchIndex = 0;
      }
    });
  }

  void _performInChatSearch(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }
    final lowerQuery = query.toLowerCase();
    List<int> results = [];
    for (int i = _groupedMessages.length - 1; i >= 0; i--) {
      final item = _groupedMessages[i];
      if (item['is_header'] == true) continue;
      if ((item['text'] ?? '').toString().toLowerCase().contains(lowerQuery))
        results.add(i);
    }
    setState(() {
      _searchResults = results;
      _currentSearchIndex = 0;
      if (results.isNotEmpty) _scrollToMessage(results[0], indexMode: true);
    });
  }

  void _nextSearchResult() {
    if (_searchResults.isEmpty) return;
    if (_currentSearchIndex < _searchResults.length - 1) {
      setState(() {
        _currentSearchIndex++;
        _scrollToMessage(_searchResults[_currentSearchIndex], indexMode: true);
      });
    }
  }

  void _prevSearchResult() {
    if (_searchResults.isEmpty) return;
    if (_currentSearchIndex > 0) {
      setState(() {
        _currentSearchIndex--;
        _scrollToMessage(_searchResults[_currentSearchIndex], indexMode: true);
      });
    }
  }

  void _scrollToMessage(int idOrIndex, {bool indexMode = false}) {
    int indexInData = indexMode
        ? idOrIndex
        : _groupedMessages.indexWhere((m) => m['id'] == idOrIndex);
    if (indexInData != -1) {
      final widgetIndex = _groupedMessages.length - 1 - indexInData;
      if (_itemScrollController.isAttached) {
        _itemScrollController.scrollTo(
          index: widgetIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        final int targetId = indexMode
            ? _groupedMessages[indexInData]['id']
            : idOrIndex;
        setState(() => _highlightedMessageId = targetId);
        Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _highlightedMessageId = null);
        });
      }
    }
  }

  Future<void> _clearChat() async {
    try {
      final token = await const FlutterSecureStorage().read(
        key: 'access_token',
      );
      final response = await http.post(
        Uri.parse('${baseUrl}chat/conversations/$_activeConversationId/clear/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _messages.clear();
          _groupedMessages.clear();
        });
      }
    } catch (e) {
      setState(() {
        _messages.clear();
        _groupedMessages.clear();
      });
    }
  }

  Future<void> _muteChat() async {
    try {
      final token = await const FlutterSecureStorage().read(
        key: 'access_token',
      );
      final response = await http.post(
        Uri.parse('${baseUrl}chat/conversations/$_activeConversationId/mute/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['is_muted'] ? "Chat muted." : "Chat unmuted."),
            ),
          );
      }
    } catch (e) {
      /* ignore */
    }
  }

  Future<void> _blockUser() async {
    try {
      final token = await const FlutterSecureStorage().read(
        key: 'access_token',
      );
      final userId = widget.recipientId;
      if (userId == null) return;
      final response = await http.post(
        Uri.parse('${baseUrl}members/block/$userId/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("User blocked.")));
        Navigator.pop(context);
      }
    } catch (e) {
      /* ignore */
    }
  }

  void _reportUser(String? username) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Report ${username ?? 'User'}"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: "Reason..."),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (reasonController.text.isNotEmpty)
                _sendReport(reasonController.text);
            },
            child: const Text("Report", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendReport(String reason) async {
    try {
      final token = await const FlutterSecureStorage().read(
        key: 'access_token',
      );
      await http.post(
        Uri.parse('${baseUrl}members/report/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reported_item_type': 'USER',
          'reported_item_id': widget.recipientId?.toString() ?? 'unknown',
          'reason': reason,
        }),
      );
    } catch (e) {
      /* ignore */
    }
  }

  Future<void> _onOpenLink(LinkableElement link) async {
    final uri = Uri.parse(link.url);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openAttachmentUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open attachment.')),
      );
    }
  }

  void _openImagePreview(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FullScreenMediaViewer(url: url)),
    );
  }

  void _openVideoPreview(String url) {
    showDialog(
      context: context,
      builder: (_) => _VideoPreviewDialog(url: url),
    );
  }

  void _openPublicProfile(Map<String, dynamic> msg) {
    final sender = msg['sender'] as Map<String, dynamic>?;
    final senderId = sender?['id'] ?? sender?['user_id'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: senderId is int
              ? senderId
              : int.tryParse(senderId.toString()),
          username: sender?['username']?.toString(),
          initialData: sender,
        ),
      ),
    );
  }

  void _openDmRecipientProfile() {
    if (widget.isCommunity || widget.recipientId == null) return;
    final recipientFromMessages = _getDmRecipientFromMessages();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: widget.recipientId,
          username:
              recipientFromMessages?['username']?.toString() ??
              widget.recipientName,
          initialData: recipientFromMessages,
        ),
      ),
    );
  }

  bool _canDeleteForEveryone(Map<String, dynamic> msg) {
    if (msg['is_me'] != true) return false;

    final dynamic serverValue = msg['can_delete_for_everyone'];
    if (serverValue is bool) return serverValue;
    if (serverValue is String) {
      final normalized = serverValue.toLowerCase().trim();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }

    // Fallback for older payloads without explicit flag.
    try {
      final createdAt = DateTime.parse(msg['created_at'].toString()).toUtc();
      final now = DateTime.now().toUtc();
      return now.difference(createdAt) <= const Duration(minutes: 15);
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteMessageForEveryone(Map<String, dynamic> msg) async {
    final dynamic rawId = msg['id'];
    final int? messageId = rawId is int
        ? rawId
        : int.tryParse(rawId.toString());
    if (messageId == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete message?'),
            content: const Text(
              'This will delete the message for everyone in this chat.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final token = await const FlutterSecureStorage().read(
        key: 'access_token',
      );
      final response = await http.delete(
        Uri.parse('${baseUrl}chat/messages/$messageId/delete/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == messageId);
          _groupMessages();
          if (_replyMessage?['id'] == messageId) {
            _replyMessage = null;
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message deleted.')));
        return;
      }

      String error = 'Could not delete message.';
      try {
        final data = jsonDecode(response.body);
        final apiError = data['error']?.toString();
        if (apiError != null && apiError.trim().isNotEmpty) error = apiError;
      } catch (_) {}

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    final isMe = msg['is_me'];
    final text = (msg['text'] ?? '').toString();
    final hasText = text.trim().isNotEmpty;
    final canDeleteForEveryone = _canDeleteForEveryone(msg);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasText)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text("Copy Text"),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text("Reply"),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyMessage = msg);
              },
            ),
            if (isMe && canDeleteForEveryone)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  "Delete for everyone",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForEveryone(msg);
                },
              ),
            if (widget.isCommunity && !isMe)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text("View Profile"),
                onTap: () {
                  Navigator.pop(context);
                  _openPublicProfile(msg);
                },
              ),
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.red),
                title: const Text(
                  "Report User",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _reportUser(_displayNameFromUser(msg['sender']));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    int? targetId = widget.recipientId;
    if (targetId == null) return;
    try {
      final token = await const FlutterSecureStorage().read(
        key: 'access_token',
      );
      final response = await http.post(
        Uri.parse('${baseUrl}members/favorites/toggle/$targetId/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['is_favorite']
                  ? "Added to favourites"
                  : "Removed from favourites",
            ),
          ),
        );
      }
    } catch (e) {
      /* ignore */
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.7),
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        title: _isSearching
            ? Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Search chat...",
                    border: InputBorder.none,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) {
                    if (_searchDebounce?.isActive ?? false)
                      _searchDebounce!.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 300),
                      () => _performInChatSearch(val),
                    );
                  },
                ),
              )
            : (() {
                final dmRecipient = _getDmRecipientFromMessages();
                final dmRecipientPhoto = _normalizeImageUrl(
                  dmRecipient?['photo'] ??
                      dmRecipient?['photo_url'] ??
                      dmRecipient?['profile_picture'],
                );
                final dmRecipientUsername = _displayNameFromUser(
                  dmRecipient,
                  fallback: widget.recipientName,
                );

                if (!widget.isCommunity) {
                  return InkWell(
                    onTap: _openDmRecipientProfile,
                    borderRadius: BorderRadius.circular(999),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserAvatar(
                          radius: 16,
                          username: dmRecipientUsername,
                          imageUrl: dmRecipientPhoto,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.recipientName.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Text(
                  widget.recipientName.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                );
              })(),
        actions: _isSearching
            ? [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up),
                  onPressed: _nextSearchResult,
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: _prevSearchResult,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _toggleSearch,
                ),
              ]
            : [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'clear') _clearChat();
                    if (value == 'mute') _muteChat();
                    if (value == 'block') _blockUser();
                    if (value == 'report') _reportUser(widget.recipientName);
                    if (value == 'favorite') _toggleFavorite();
                    if (value == 'search') _toggleSearch();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'search', child: Text("Search")),
                    if (!widget.isCommunity)
                      const PopupMenuItem(
                        value: 'favorite',
                        child: Text("Star User"),
                      ),
                    const PopupMenuItem(
                      value: 'mute',
                      child: Text("Mute Chat"),
                    ),
                    const PopupMenuItem(
                      value: 'clear',
                      child: Text("Clear Chat"),
                    ),
                    if (!widget.isCommunity)
                      const PopupMenuItem(
                        value: 'block',
                        child: Text("Block User"),
                      ),
                    if (!widget.isCommunity)
                      const PopupMenuItem(
                        value: 'report',
                        child: Text("Report User"),
                      ),
                  ],
                ),
              ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor.withOpacity(isDark ? 0.98 : 0.94),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      padding: EdgeInsets.only(
                        top:
                            kToolbarHeight +
                            MediaQuery.of(context).padding.top +
                            16, // Ensure first message isn't cut by appbar
                        bottom: 16,
                        left: 16,
                        right: 16,
                      ),
                      reverse: true,
                      itemCount: _groupedMessages.length,
                      itemBuilder: (context, index) {
                        final item =
                            _groupedMessages[_groupedMessages.length -
                                1 -
                                index];
                        if (item['is_header'] == true) {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.12)
                                    : Colors.black.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _getDateLabel(item['date']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.75),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }

                        final msg = item;
                        final isMe = msg['is_me'];
                        final isRead = msg['is_read'] ?? false;
                        final isHighlighted =
                            msg['id'] == _highlightedMessageId;
                        final username = _displayNameFromUser(msg['sender']);
                        final senderPhoto = _normalizeImageUrl(
                          msg['sender']['photo'] ??
                              msg['sender']['photo_url'] ??
                              msg['sender']['profile_picture'],
                        );
                        final createdAt = DateTime.parse(
                          msg['created_at'],
                        ).toLocal();
                        final timeString =
                            "${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}";
                        final String messageType =
                            (msg['message_type'] ?? 'text')
                                .toString()
                                .toLowerCase();
                        final String? attachmentUrl = _normalizeAttachmentUrl(
                          msg['attachment_url'],
                        );
                        final bool hasAttachment =
                            attachmentUrl != null && attachmentUrl.isNotEmpty;
                        final String safeAttachmentUrl = attachmentUrl ?? '';
                        final String messageText = (msg['text'] ?? '')
                            .toString();

                        // WhatsApp Logic:
                        // - Name: Show on the FIRST message of a sequence.
                        // - Avatar: Show on the LAST message of a sequence.

                        final int dataIndex =
                            _groupedMessages.length - 1 - index;
                        bool isFirstInSequence = true;
                        if (dataIndex > 0) {
                          final prev = _groupedMessages[dataIndex - 1];
                          if (prev['is_header'] != true &&
                              prev['sender']?['id'] == msg['sender']?['id']) {
                            isFirstInSequence = false;
                          }
                        }

                        bool isLastInSequence = true;
                        if (dataIndex < _groupedMessages.length - 1) {
                          final next = _groupedMessages[dataIndex + 1];
                          if (next['is_header'] != true &&
                              next['sender']?['id'] == msg['sender']?['id']) {
                            isLastInSequence = false;
                          }
                        }

                        final bool showSenderName =
                            widget.isCommunity && !isMe && isFirstInSequence;
                        final bool showAvatar =
                            widget.isCommunity && !isMe && isLastInSequence;

                        final replyId =
                            msg['reply_to_id'] ??
                            (msg['reply_to'] is int
                                ? msg['reply_to']
                                : (msg['reply_to'] != null
                                      ? msg['reply_to']['id']
                                      : null));
                        Map<String, dynamic>? replyContext;
                        if (replyId != null) {
                          if (msg['reply_to'] is Map)
                            replyContext = msg['reply_to'];
                          else
                            try {
                              replyContext = _messages.firstWhere(
                                (m) => m['id'] == replyId,
                                orElse: () => null,
                              );
                            } catch (_) {}
                        }

                        return Dismissible(
                          key: Key(msg['id'].toString()),
                          direction: DismissDirection.startToEnd,
                          confirmDismiss: (_) async {
                            setState(() => _replyMessage = msg);
                            return false;
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.reply,
                              color: FfigTheme.primaryBrown,
                            ),
                          ),
                          child: Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: AnimatedPadding(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: isFirstInSequence ? 6 : 1,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment
                                    .end, // WhatsApp aligns avatar to bottom
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.isCommunity && !isMe)
                                    Container(
                                      width: 42,
                                      alignment: Alignment.bottomCenter,
                                      margin: const EdgeInsets.only(bottom: 2),
                                      child: showAvatar
                                          ? UserAvatar(
                                              key: ValueKey(senderPhoto),
                                              radius: 15,
                                              username: username,
                                              imageUrl: senderPhoto,
                                            )
                                          : const SizedBox(width: 42),
                                    ),
                                  if (widget.isCommunity && !isMe)
                                    const SizedBox(width: 6),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: isMe
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        if (showSenderName)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 4,
                                              bottom: 6,
                                              top: 4,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  username,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        FfigTheme.accentBrown,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                if (msg['sender']?['tier'] ==
                                                    'PREMIUM') ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.verified,
                                                    color: Colors.amber,
                                                    size: 10,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        GestureDetector(
                                          onLongPress: () =>
                                              _showMessageOptions(msg),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            constraints: BoxConstraints(
                                              maxWidth:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.width *
                                                  0.75,
                                              minWidth: 60,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isHighlighted
                                                  ? Colors.amber.withOpacity(
                                                      0.35,
                                                    )
                                                  : (isMe
                                                        ? FfigTheme.primaryBrown
                                                        : (isDark
                                                              ? const Color(
                                                                  0xFF21262D,
                                                                )
                                                              : const Color(
                                                                  0xFFF1F4F9,
                                                                ))),
                                              borderRadius: BorderRadius.only(
                                                topLeft: const Radius.circular(
                                                  18,
                                                ),
                                                topRight: const Radius.circular(
                                                  18,
                                                ),
                                                bottomLeft: isMe
                                                    ? const Radius.circular(18)
                                                    : (isLastInSequence
                                                          ? const Radius.circular(
                                                              4,
                                                            )
                                                          : const Radius.circular(
                                                              18,
                                                            )),
                                                bottomRight: isMe
                                                    ? (isLastInSequence
                                                          ? const Radius.circular(
                                                              4,
                                                            )
                                                          : const Radius.circular(
                                                              18,
                                                            ))
                                                    : const Radius.circular(18),
                                              ),
                                              border: !isMe
                                                  ? Border.all(
                                                      color: isDark
                                                          ? Colors.white
                                                                .withOpacity(
                                                                  0.08,
                                                                )
                                                          : Colors.black
                                                                .withOpacity(
                                                                  0.05,
                                                                ),
                                                      width: 0.5,
                                                    )
                                                  : null,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(
                                                        isDark ? 0.22 : 0.08,
                                                      ),
                                                  blurRadius: !isFirstInSequence
                                                      ? 8
                                                      : 12,
                                                  offset: Offset(
                                                    0,
                                                    !isFirstInSequence ? 2 : 4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            child: IntrinsicWidth(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (msg['metadata'] != null &&
                                                      msg['metadata']['type'] ==
                                                          'story_reply')
                                                    GestureDetector(
                                                      onTap: () {
                                                        if (msg['metadata']['story_id'] !=
                                                            null)
                                                          _checkAndOpenStory(
                                                            msg['metadata']['story_id'],
                                                          );
                                                      },
                                                      child: Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 8,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.all(
                                                              4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          border: Border(
                                                            left: BorderSide(
                                                              color: isMe
                                                                  ? Colors
                                                                        .white70
                                                                  : FfigTheme
                                                                        .primaryBrown,
                                                              width: 4,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    4,
                                                                  ),
                                                              child: CachedNetworkImage(
                                                                imageUrl:
                                                                    msg['metadata']['media_url'] ??
                                                                    '',
                                                                width: 40,
                                                                height: 60,
                                                                fit: BoxFit
                                                                    .cover,
                                                                errorWidget:
                                                                    (
                                                                      c,
                                                                      u,
                                                                      e,
                                                                    ) => Container(
                                                                      width: 40,
                                                                      height:
                                                                          60,
                                                                      color: Colors
                                                                          .grey,
                                                                      child: const Icon(
                                                                        Icons
                                                                            .broken_image,
                                                                        size:
                                                                            16,
                                                                      ),
                                                                    ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  isMe
                                                                      ? "You replied to their story"
                                                                      : "Replied to your story",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: isMe
                                                                        ? Colors
                                                                              .white
                                                                        : Colors
                                                                              .black87,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 2,
                                                                ),
                                                                if (msg['metadata']['is_video'] ==
                                                                    true)
                                                                  const Icon(
                                                                    Icons
                                                                        .videocam,
                                                                    size: 12,
                                                                    color: Colors
                                                                        .grey,
                                                                  ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  if (replyContext != null)
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _scrollToMessage(
                                                            replyContext!['id'],
                                                          ),
                                                      child: Container(
                                                        width: double
                                                            .infinity, // Expand to IntrinsicWidth of parent Column
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 8,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: isMe
                                                              ? Colors.black
                                                                    .withOpacity(
                                                                      0.16,
                                                                    )
                                                              : (isDark
                                                                    ? Colors
                                                                          .white
                                                                          .withOpacity(
                                                                            0.06,
                                                                          )
                                                                    : Colors
                                                                          .black
                                                                          .withOpacity(
                                                                            0.04,
                                                                          )),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                          border: Border(
                                                            left: BorderSide(
                                                              color: isMe
                                                                  ? const Color(
                                                                      0xFFD8C3AF,
                                                                    )
                                                                  : FfigTheme
                                                                        .primaryBrown,
                                                              width: 4,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              _displayNameFromUser(
                                                                replyContext['sender'],
                                                                fallback:
                                                                    'User',
                                                              ),
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: isMe
                                                                    ? const Color(
                                                                        0xFFF4D4B8,
                                                                      )
                                                                    : FfigTheme
                                                                          .accentBrown,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              _messageTextForDisplay(
                                                                Map<
                                                                  String,
                                                                  dynamic
                                                                >.from(
                                                                  replyContext,
                                                                ),
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: isMe
                                                                    ? Colors
                                                                          .white
                                                                          .withOpacity(
                                                                            0.9,
                                                                          )
                                                                    : (isDark
                                                                          ? Colors.white70
                                                                          : Colors.black54),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  if (hasAttachment &&
                                                      messageType == 'image')
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 8,
                                                          ),
                                                      child: GestureDetector(
                                                        onTap: () =>
                                                            _openImagePreview(
                                                              safeAttachmentUrl,
                                                            ),
                                                        child: ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          child: CachedNetworkImage(
                                                            imageUrl:
                                                                safeAttachmentUrl,
                                                            width: 220,
                                                            fit: BoxFit.cover,
                                                            placeholder:
                                                                (
                                                                  c,
                                                                  _,
                                                                ) => Container(
                                                                  width: 220,
                                                                  height: 140,
                                                                  color: Colors
                                                                      .black12,
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  child: const CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                                ),
                                                            errorWidget:
                                                                (
                                                                  c,
                                                                  _,
                                                                  __,
                                                                ) => Container(
                                                                  width: 220,
                                                                  height: 120,
                                                                  color: Colors
                                                                      .black12,
                                                                  alignment:
                                                                      Alignment
                                                                          .center,
                                                                  child: const Icon(
                                                                    Icons
                                                                        .broken_image,
                                                                  ),
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (hasAttachment &&
                                                      messageType == 'video')
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 8,
                                                          ),
                                                      child: GestureDetector(
                                                        onTap: () =>
                                                            _openVideoPreview(
                                                              safeAttachmentUrl,
                                                            ),
                                                        child: Container(
                                                          width: 220,
                                                          padding:
                                                              const EdgeInsets.all(
                                                                12,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: isMe
                                                                ? Colors.black
                                                                      .withOpacity(
                                                                        0.18,
                                                                      )
                                                                : (isDark
                                                                      ? Colors
                                                                            .white
                                                                            .withOpacity(
                                                                              0.07,
                                                                            )
                                                                      : Colors
                                                                            .black
                                                                            .withOpacity(
                                                                              0.04,
                                                                            )),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              const Icon(
                                                                Icons
                                                                    .play_circle_fill,
                                                                size: 34,
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                              const SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  "Video attachment",
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color: isMe
                                                                        ? Colors
                                                                              .white
                                                                        : (isDark
                                                                              ? Colors.white
                                                                              : Colors.black87),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (hasAttachment &&
                                                      messageType == 'document')
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 8,
                                                          ),
                                                      child: GestureDetector(
                                                        onTap: () =>
                                                            _openAttachmentUrl(
                                                              safeAttachmentUrl,
                                                            ),
                                                        child: Container(
                                                          width: 220,
                                                          padding:
                                                              const EdgeInsets.all(
                                                                12,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: isMe
                                                                ? Colors.black
                                                                      .withOpacity(
                                                                        0.18,
                                                                      )
                                                                : (isDark
                                                                      ? Colors
                                                                            .white
                                                                            .withOpacity(
                                                                              0.07,
                                                                            )
                                                                      : Colors
                                                                            .black
                                                                            .withOpacity(
                                                                              0.04,
                                                                            )),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              const Icon(
                                                                Icons
                                                                    .insert_drive_file,
                                                                size: 28,
                                                                color: Colors
                                                                    .white70,
                                                              ),
                                                              const SizedBox(
                                                                width: 10,
                                                              ),
                                                              Expanded(
                                                                child: Text(
                                                                  _filenameFromUrl(
                                                                    safeAttachmentUrl,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color: isMe
                                                                        ? Colors
                                                                              .white
                                                                        : (isDark
                                                                              ? Colors.white
                                                                              : Colors.black87),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  if (messageText
                                                      .trim()
                                                      .isNotEmpty)
                                                    Linkify(
                                                      onOpen: _onOpenLink,
                                                      text: messageText,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: isMe
                                                            ? Colors.white
                                                            : (isDark
                                                                  ? Colors.white
                                                                  : Colors
                                                                        .black87),
                                                      ),
                                                      linkStyle:
                                                          const TextStyle(
                                                            color: Colors
                                                                .blueAccent,
                                                            decoration:
                                                                TextDecoration
                                                                    .none,
                                                          ),
                                                      options:
                                                          const LinkifyOptions(
                                                            humanize: false,
                                                          ),
                                                    ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Spacer(),
                                                      Text(
                                                        timeString,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: isMe
                                                              ? Colors.white70
                                                              : (isDark
                                                                    ? Colors
                                                                          .white60
                                                                    : Colors
                                                                          .grey[600]),
                                                        ),
                                                      ),
                                                      if (isMe &&
                                                          !widget
                                                              .isCommunity) ...[
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Icon(
                                                          isRead
                                                              ? Icons.done_all
                                                              : Icons.check,
                                                          size: 14,
                                                          color: isRead
                                                              ? Colors
                                                                    .blueAccent
                                                              : Colors.white70,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor.withOpacity(0.86),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.08),
                        width: 0.7,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyMessage != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.05),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.reply,
                                  color: FfigTheme.primaryBrown,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Replying to ${_displayNameFromUser(_replyMessage!['sender'])}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: FfigTheme.primaryBrown,
                                        ),
                                      ),
                                      Text(
                                        _messageTextForDisplay(
                                          Map<String, dynamic>.from(
                                            _replyMessage!,
                                          ),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () =>
                                      setState(() => _replyMessage = null),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              if (!_isTypingMessage)
                                GestureDetector(
                                  onTap: _isSendingAttachment
                                      ? null
                                      : () {
                                          if (_isEmojiVisible) {
                                            setState(
                                              () => _isEmojiVisible = false,
                                            );
                                          }
                                          _showAttachmentSheet();
                                        },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.black.withOpacity(0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.attach_file,
                                      color: _isSendingAttachment
                                          ? Colors.grey
                                          : FfigTheme.primaryBrown,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              GestureDetector(
                                onTap: _isSendingAttachment
                                    ? null
                                    : _toggleEmojiKeyboard,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.white.withOpacity(0.08)
                                        : Colors.black.withOpacity(0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isEmojiVisible
                                        ? Icons.keyboard_alt_outlined
                                        : Icons.emoji_emotions_outlined,
                                    color: _isSendingAttachment
                                        ? Colors.grey
                                        : FfigTheme.primaryBrown,
                                    size: 20,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.brightness == Brightness.dark
                                        ? const Color(0xFF212833)
                                        : Colors.black.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.08),
                                      width: 1,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _messageFocusNode,
                                    keyboardType: TextInputType.multiline,
                                    maxLines: 5,
                                    minLines: 1,
                                    enabled: !_isSendingAttachment,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    onTap: () {
                                      if (_isEmojiVisible) {
                                        setState(() => _isEmojiVisible = false);
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: "Type a message...",
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _isSendingAttachment
                                    ? null
                                    : _sendMessage,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: FfigTheme.primaryBrown,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: FfigTheme.primaryBrown
                                            .withOpacity(0.45),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: _isSendingAttachment
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isEmojiVisible) _buildEmojiPanel(isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _showScrollToBottom
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: FloatingActionButton(
                mini: true,
                backgroundColor: FfigTheme.primaryBrown,
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (_itemScrollController.isAttached)
                    _itemScrollController.scrollTo(
                      index: 0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                },
              ),
            )
          : null,
    );
  }
}

class _VideoPreviewDialog extends StatefulWidget {
  final String url;

  const _VideoPreviewDialog({required this.url});

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isReady = true;
      });
      await controller.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Video preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Could not load video.\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              )
            else if (!_isReady || _controller == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              )
            else
              AspectRatio(
                aspectRatio: _controller!.value.aspectRatio > 0
                    ? _controller!.value.aspectRatio
                    : (16 / 9),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: VideoPlayer(_controller!),
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
