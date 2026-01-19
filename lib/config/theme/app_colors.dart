import 'package:flutter/material.dart';

/// GoFleet Driver App Color Palette
/// Uber-inspired dark theme design
class AppColors {
  AppColors._();

  // ============== Primary Colors ==============
  
  /// Pure black - Main background
  static const Color black = Color(0xFF000000);
  
  /// Charcoal - Secondary background
  static const Color charcoal = Color(0xFF141414);
  
  /// Dark gray - Card backgrounds
  static const Color darkGray = Color(0xFF1C1C1C);
  
  /// Medium gray - Elevated surfaces
  static const Color mediumGray = Color(0xFF282828);
  
  /// Light gray - Borders, dividers
  static const Color lightGray = Color(0xFF3D3D3D);
  
  /// Subtle gray - Disabled states
  static const Color subtleGray = Color(0xFF545454);

  // ============== Accent Colors ==============
  
  /// Primary green - Success, active states, primary actions
  static const Color primaryGreen = Color(0xFF34D399);
  
  /// Dark green - Pressed state for green buttons
  static const Color darkGreen = Color(0xFF059669);
  
  /// Accent blue - Links, secondary actions
  static const Color accentBlue = Color(0xFF3B82F6);
  
  /// Warning yellow - Warnings, pending states
  static const Color warningYellow = Color(0xFFFBBF24);
  
  /// Error red - Errors, failed states, destructive actions
  static const Color errorRed = Color(0xFFEF4444);
  
  /// Dark red - Pressed state for red buttons
  static const Color darkRed = Color(0xFFDC2626);

  // ============== Text Colors ==============
  
  /// Primary text - White
  static const Color textPrimary = Color(0xFFFFFFFF);
  
  /// Secondary text - Light gray
  static const Color textSecondary = Color(0xFFA3A3A3);
  
  /// Muted text - Darker gray
  static const Color textMuted = Color(0xFF737373);
  
  /// Disabled text
  static const Color textDisabled = Color(0xFF525252);

  // ============== Status Colors ==============
  
  /// Online/Active status
  static const Color statusOnline = primaryGreen;
  
  /// Offline/Inactive status
  static const Color statusOffline = subtleGray;
  
  /// Pending status
  static const Color statusPending = warningYellow;
  
  /// Delivered status
  static const Color statusDelivered = primaryGreen;
  
  /// Failed status
  static const Color statusFailed = errorRed;

  // ============== Gradient Colors ==============
  
  /// Primary gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGreen, Color(0xFF10B981)],
  );

  /// Dark gradient for backgrounds
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [charcoal, black],
  );
}
