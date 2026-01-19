import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color kPrimaryGreen = Color(0xFF1B5E20); // Deep Forest Green
  static const Color kPrimaryLight = Color(0xFFE8F5E9); // Light Green Background
  static const Color kSecondaryGreen = Color(0xFF4CAF50); // Vibrant Green
  static const Color kPrimaryBlue = Color(0xFF1565C0); // Rich Blue
  static const Color kAccentBlue = Color(0xFF64B5F6); // Lighter Blue
  static const Color kAccentGold = Color(0xFFFFC107); // Gold for currency/warnings
  
  // Backgrounds
  static const Color kBackground = Color(0xFFF4F7F9);   // Very light blue-grey for modern feel
  static const Color kCardColor = Colors.white;
  static const Color kSurfaceColor = Color(0xFFFFFFFF);
  
  // Text
  static const Color kTextPrimary = Color(0xFF1F2937); // Dark Blue-Grey
  static const Color kTextSecondary = Color(0xFF6B7280); // Medium Grey
  static const Color kTextLight = Color(0xFF9CA3AF); // Light Grey

  // Status
  static const Color kSuccess = Color(0xFF10B981);
  static const Color kWarning = Color(0xFFF59E0B);
  static const Color kError = Color(0xFFEF4444);
  static const Color kInfo = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [kPrimaryGreen, Color(0xFF2E7D32)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFFAFAFA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Text Styles
  static const TextStyle displayLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: kTextPrimary,
    letterSpacing: -0.5,
  );
  
  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: kTextPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: kTextPrimary,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: kTextPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: kTextPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: kTextSecondary,
    height: 1.5,
  );
  
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: kTextPrimary,
  );

  // Global Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: kPrimaryGreen,
      scaffoldBackgroundColor: kBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimaryGreen,
        primary: kPrimaryGreen,
        secondary: kSecondaryGreen,
        surface: kSurfaceColor,
        background: kBackground,
        error: kError,
        brightness: Brightness.light,
      ),
      
      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: kPrimaryGreen,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      
      // Card Theme
      cardTheme: CardThemeData(
        color: kCardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 12),
        // We will add shadows manually where needed for specific glowing effects, 
        // but default card should be clean.
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide: const BorderSide(color: kPrimaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kError),
        ),
        labelStyle: const TextStyle(color: kTextSecondary),
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),
      
      // Tab Bar Theme
      tabBarTheme: const TabBarThemeData(
        labelColor: kPrimaryGreen,
        unselectedLabelColor: kTextSecondary,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: kPrimaryGreen, width: 3),
        ),
      ),
      
      // Icon Theme
      iconTheme: const IconThemeData(
        color: kTextPrimary,
        size: 24,
      ),
    );
  }
}
