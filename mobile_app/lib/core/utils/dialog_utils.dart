import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/ffig_theme.dart';

class DialogUtils {
  static void showError(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => _PremiumDialog(
        title: title,
        message: message,
        isError: true,
        icon: Icons.error_outline,
      ),
    );
  }

  static void showSuccess(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => _PremiumDialog(
        title: title,
        message: message,
        isError: false,
        icon: Icons.check_circle_outline,
      ),
    );
  }

  static Future<bool?> showConfirmation(BuildContext context, String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => _PremiumConfirmationDialog(
        title: title,
        message: message,
      ),
    );
  }

  static String getFriendlyMessage(dynamic e) {
    final str = e.toString().toLowerCase();
    if (str.contains('connection refused') || str.contains('socketexception') || str.contains('failed host lookup')) {
      return "Unable to connect to the server. Please check your internet connection or ensure the backend is running.";
    }
    if (str.contains('401') || str.contains('unauthorized')) {
      return "Your session has expired. Please log in again.";
    }
    if (str.contains('403') || str.contains('permission')) {
      return "You do not have permission to perform this action.";
    }
    if (str.contains('500') || str.contains('internal server error')) {
      return "Server error. Our team has been notified. Please try again later.";
    }
    return e.toString().replaceAll('ClientException with ', '').replaceAll('Exception: ', '');
  }
}

class _PremiumDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool isError;
  final IconData icon;

  const _PremiumDialog({
    required this.title,
    required this.message,
    required this.isError,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isError ? Colors.redAccent.shade100 : FfigTheme.primaryBrown;
    final bgColor = Theme.of(context).colorScheme.surface;
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final messageColor = isDark ? Colors.white70 : Colors.black54;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: bgColor,
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15), // Slightly more visible for dark mode
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: messageColor,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FfigTheme.primaryBrown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "DISMISS",
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;

  const _PremiumConfirmationDialog({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).colorScheme.surface;
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final messageColor = isDark ? Colors.white70 : Colors.black54;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: bgColor,
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.help_outline, size: 40, color: Colors.orangeAccent),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: messageColor,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                    child: const Text(
                      "CANCEL",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FfigTheme.primaryBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "CONFIRM",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
