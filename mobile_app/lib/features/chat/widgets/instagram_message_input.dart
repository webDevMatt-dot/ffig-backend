import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/ffig_theme.dart';

class InstagramMessageInput extends StatefulWidget {
  final Function(String) onSend;
  final TextEditingController? controller;

  final VoidCallback? onCameraTap;
  final VoidCallback? onGalleryTap;
  final VoidCallback? onMicTap;

  const InstagramMessageInput({
    super.key,
    required this.onSend,
    this.controller,
    this.onCameraTap,
    this.onGalleryTap,
    this.onMicTap,
  });

  @override
  State<InstagramMessageInput> createState() => _InstagramMessageInputState();
}

class _InstagramMessageInputState extends State<InstagramMessageInput> {
  late TextEditingController _controller;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isTyping = _controller.text.trim().isNotEmpty;
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _controller.clear();
      setState(() => _isTyping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme-aware colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Backgrounds
    final bgColor = isDark 
        ? const Color(0xFF0D1117) // Obsidian
        : const Color(0xFFF9FAFB); // Off-White
    
    final pillColor = isDark
        ? const Color(0xFF21262D) // Lighter Obsidian
        : Colors.white;

    // Icons & Text
    final iconColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200, 
            width: 1
          )
        )
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Camera Button (Left Accent)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 12), // Increased spacing
              child: GestureDetector(
                onTap: () {
                  widget.onCameraTap?.call();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: FfigTheme.primaryBrown, // Theme Color
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
              ),
            ),
    
            // Input Pill
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300
                  )
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Increased from 4/2
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(color: textColor, fontSize: 15),
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: "Message...",
                          hintStyle: TextStyle(color: hintColor),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    
                    // Icons inside pill (Animated switching)
                    AnimatedContainer(
                      duration: 200.ms,
                      width: _isTyping ? 0 : 100, // Collapse width when typing
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(),
                      child: _isTyping 
                        ? const SizedBox() 
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                               IconButton(
                                 icon: Icon(Icons.mic, color: iconColor, size: 22),
                                 onPressed: widget.onMicTap,
                                 padding: EdgeInsets.zero,
                                 constraints: const BoxConstraints(),
                               ).animate().fade(),
                               const SizedBox(width: 12),
                               IconButton(
                                 icon: Icon(Icons.image, color: iconColor, size: 22),
                                 onPressed: widget.onGalleryTap,
                                 padding: EdgeInsets.zero,
                                 constraints: const BoxConstraints(),
                               ).animate().fade(),
                               const SizedBox(width: 12),
                               IconButton(
                                 icon: Icon(Icons.emoji_emotions_outlined, color: iconColor, size: 22),
                                 onPressed: () {},
                                 padding: EdgeInsets.zero,
                                 constraints: const BoxConstraints(),
                               ).animate().fade(),
                               const SizedBox(width: 8),
                            ],
                          ),
                    ),

                    if (_isTyping)
                       Padding(
                         padding: const EdgeInsets.only(bottom: 10.5, right: 8), // Adjusted right padding
                         child: GestureDetector(
                           onTap: _handleSend,
                           child: Text(
                             "Send", 
                             style: TextStyle(
                               color: FfigTheme.primaryBrown, // Theme Color
                               fontWeight: FontWeight.bold,
                               fontSize: 15
                             )
                           ).animate().fadeIn(duration: 200.ms).moveX(begin: 10, end: 0),
                         ),
                       )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
