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
    final color = isError ? Colors.redAccent.shade100 : FfigTheme.primaryBrown;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.lato(
                fontSize: 16,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, // Premium Black
                  foregroundColor: FfigTheme.primaryBrown, // Gold Text
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "DISMISS",
                  style: GoogleFonts.lato(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
