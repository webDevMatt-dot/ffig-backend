import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ModerationType { warning, suspend, block, delete }

/// A dialog used to inform users about their account status (Warned, Suspended, Blocked).
///
/// **Usage:**
/// - **Warning:** Dismissible, serves as a gentle reminder or policy notice.
/// - **Suspend:** Blocking (cannot dismiss), shows duration.
/// - **Block:** Blocking (cannot dismiss), permanent ban.
/// - **Delete:** Blocking, account removal notice.
class ModerationDialog extends StatelessWidget {
  final ModerationType type;
  final String? message;
  final VoidCallback? onClose; // Only for Warning
  
  const ModerationDialog({
    super.key, 
    required this.type, 
    this.message,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    String title;
    String defaultMessage;
    // Determines if the user can close the dialog or is locked out
    bool isBlocking = true;

    switch (type) {
      case ModerationType.warning:
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.orange;
        title = "Account Notice";
        defaultMessage = "Your account is under review.";
        isBlocking = false;
        break;
      case ModerationType.suspend:
        icon = Icons.timer_off_outlined; // Crossed out clockish
        iconColor = Colors.orangeAccent;
        title = "Account Suspended";
        defaultMessage = "Your account has been suspended and is under review.";
        break;
      case ModerationType.block:
        icon = Icons.block; // Cancel sign
        iconColor = Colors.red;
        title = "Account Blocked";
        defaultMessage = "Your account has been blocked. Please submit an appeal to admin@femalefoundersinitiative.com";
        break;
      case ModerationType.delete:
        icon = Icons.delete_forever;
        iconColor = Colors.grey;
        title = "Account Deleted";
        defaultMessage = "Your account has been deleted.";
        break;
    }

    return PopScope(
      canPop: !isBlocking, // Prevent back button if blocking
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button only for warnings
              if (type == ModerationType.warning)
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose ?? () => Navigator.pop(context),
                  ),
                ),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: iconColor),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message ?? defaultMessage,
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Placeholder for future actions (e.g., Logout, Contact Support)
              if (isBlocking)
                 TextButton(
                   onPressed: () { 
                      // Provide a callback or let parent handle 'Logout'
                      // For now, simple text instructions.
                   }, 
                   child: const SizedBox.shrink()
                 )
            ],
          ),
        ),
      ),
    );
  }
}

