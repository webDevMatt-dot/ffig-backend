import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FfigTheme {
  // --- PREMIUM COLOR PALETTE ---
  // "Matte Black" - Deep, rich, not pure black
  static const Color matteBlack = Color(0xFF0F0F0F); 
  static const Color darkGrey = Color(0xFF1A1A1A);
  
  // "Soft Gold" - Elegant, desaturated gold
  static const Color gold = Color(0xFFD4AF37);
  static const Color paleGold = Color(0xFFF3E5AB);

  // "Alabaster/Snow" - Clean modern background
  static const Color alabaster = Color(0xFFFAFAFA);
  static const Color pureWhite = Color(0xFFFFFFFF);
  
  static const Color textDark = Color(0xFF0A0A0A);
  static const Color textGrey = Color(0xFF666666);
  static const Color textLight = Color(0xFF999999);

  // --- TEXT STYLES (Modern / React.js Vibe) ---
  // Using 'Inter' for that clean, technical, high-end web feel.
  static TextTheme get textTheme {
    return TextTheme(
      // Big Headings
      displayLarge: GoogleFonts.inter(
        fontSize: 36, fontWeight: FontWeight.w800, color: textDark, letterSpacing: -1.0, height: 1.1,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28, fontWeight: FontWeight.w700, color: textDark, letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 24, fontWeight: FontWeight.w600, color: textDark, letterSpacing: -0.5,
      ),
      
      // Body Text
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w500, color: textDark, height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400, color: textGrey, height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w500, color: textLight,
      ),

      // Buttons / Labels
      labelLarge: GoogleFonts.inter( 
        fontSize: 14, fontWeight: FontWeight.w600, color: textDark, letterSpacing: 0.5,
      ),
    );
  }

  // --- THEME DATA ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: alabaster,
      
      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        primary: gold,
        onPrimary: matteBlack, 
        secondary: matteBlack,
        onSecondary: Colors.white,
        background: alabaster,
        surface: pureWhite,
        onSurface: textDark,
        outline: Colors.grey.shade200,
      ),

      // Typography
      textTheme: textTheme,

      // AppBar Theme (Clean & Minimal)
      appBarTheme: AppBarTheme(
        backgroundColor: alabaster,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false, // Left aligned is more "Web"
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: textDark,
        ),
        iconTheme: const IconThemeData(color: textDark),
      ),

      // Input Decoration (Modern Web Style)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pureWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(color: textLight, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: const BorderSide(color: gold, width: 1),
        ),
        errorBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
      ),

      // Button Theme (Slick & Rounded)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: matteBlack, // High contrast black buttons
          foregroundColor: Colors.white,
          elevation: 0, 
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), 
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textDark,
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textDark,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // Card Theme (Soft Shadows)
      cardTheme: CardThemeData(
        color: pureWhite,
        elevation: 0, // Flat aesthetic with border often better for web
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade100,
        thickness: 1,
        space: 24,
      ),
    );
  }

  // --- DARK THEME DATA (VVIP Night Mode) ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: matteBlack, // #0F0F0F or #0A0A0A
      
      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
        primary: gold,
        onPrimary: matteBlack,
        secondary: gold,
        onSecondary: matteBlack,
        background: matteBlack,
        surface: const Color(0xFF1E1E1E), // Dark Gunmetal for cards
        onSurface: const Color(0xFFF0F0F0), // Off-white text
        outline: gold.withOpacity(0.3), // Subtle gold outlines
      ),

      // Typography
      textTheme: textTheme.apply(
        bodyColor: const Color(0xFFCED4DA), // Light Grey for body
        displayColor: const Color(0xFFF8F9FA), // Off-White for headings
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: matteBlack,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C), // Dark Grey Fill
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(color: Colors.grey[500], fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: const BorderSide(color: gold, width: 1),
        ),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold, // Gold buttons on dark
          foregroundColor: matteBlack, // Black text on gold
          elevation: 4,
          shadowColor: gold.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), 
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: const BorderSide(color: gold),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: gold,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E), // Gunmetal
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: gold.withOpacity(0.1), width: 1), // Subtle gold border
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade800,
        thickness: 1,
        space: 24,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF141414),
        selectedItemColor: gold,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
}
