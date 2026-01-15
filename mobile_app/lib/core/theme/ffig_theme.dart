import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FfigTheme {
  // --- NEW COLOR PALETTE ---
  static const Color primaryBrown = Color(0xFF723e31);
  static const Color accentBrown = Color(0xFFc29a77);
  static const Color pureBlack = Color(0xFF000000);
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
      scaffoldBackgroundColor: const Color(0xFFF9FAFB), // Soft off-white
      
      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBrown,
        primary: primaryBrown,
        onPrimary: pureWhite, 
        secondary: accentBrown,
        onSecondary: pureWhite,
        background: const Color(0xFFF9FAFB),
        surface: pureWhite,
        onSurface: textDark,
        outline: Colors.grey.shade300,
      ),

      // Typography
      textTheme: textTheme,

      // AppBar Theme (Clean & Minimal)
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF9FAFB),
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false, 
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
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: const BorderSide(color: primaryBrown, width: 1),
        ),
      ),

      // Button Theme (Slick & Rounded)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrown, // Brand Brown for Light Mode
          foregroundColor: Colors.white,
          elevation: 2, 
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // Card Theme (Soft defined borders)
      cardTheme: CardThemeData(
        color: pureWhite,
        elevation: 0, 
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 24,
      ),
    );
  }

  // --- DARK THEME DATA (VVIP Night Mode - Obsidian Revamp) ---
  static ThemeData get darkTheme {
    const obsidianBg = Color(0xFF0D1117);
    const obsidianSurface = Color(0xFF161B22);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: obsidianBg, 
      
      // Color Scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBrown,
        brightness: Brightness.dark,
        primary: primaryBrown, // #723e31
        onPrimary: pureWhite,
        secondary: accentBrown, // #c29a77
        onSecondary: pureBlack,
        background: obsidianBg,
        surface: obsidianSurface, 
        onSurface: const Color(0xFFF0F6FC), // Off-white for high contrast on obsidian
        outline: Colors.white.withOpacity(0.1), 
      ),

      // Typography
      textTheme: textTheme.apply(
        bodyColor: const Color(0xFFC9D1D9), // Soft grey for body
        displayColor: pureWhite, 
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: obsidianBg.withOpacity(0.8), // Semi-transparent for glass effect
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // Input Decoration (Dark Obsidian Input)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF21262D), // Slightly lighter obsidian
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF8B949E), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), 
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(12),
           borderSide: const BorderSide(color: accentBrown, width: 1), // Focus with Gold/Tan
        ),
      ),

      // Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrown, 
          foregroundColor: pureWhite,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.5),
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
          foregroundColor: accentBrown,
          side: const BorderSide(color: accentBrown),
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
          foregroundColor: accentBrown,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),

      // Card Theme (Bento Tile Base)
      cardTheme: CardThemeData(
        color: obsidianSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // More rounded for Bento feel
          side: BorderSide(color: Colors.white.withOpacity(0.12), width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      
      dividerTheme: DividerThemeData(
        color: const Color(0xFF30363D),
        thickness: 1,
        space: 24,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF161B22),
        selectedItemColor: accentBrown,
        unselectedItemColor: Color(0xFF8B949E),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
}
