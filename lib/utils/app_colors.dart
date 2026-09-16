import 'package:flutter/material.dart';

/// Single source of truth for all app colors.
/// To change the theme, edit values here — all screens reference these tokens.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFFF29F05);
  static const Color onPrimary = Colors.black;

  // Backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textBody = Color(0xFF374151);

  // Icons
  static const Color icon = Color(0xFF374151);
  static const Color iconAppBar = Color(0xFF1A1A1A);

  // Borders & Dividers
  static const Color divider = Color(0xFFE5E7EB);

  // Chat
  static const Color chatBubbleSelf = Color(0xFFF29F05);
  static const Color chatBubbleOther = Color(0xFFF0F0F0);
  static const Color chatTextSelf = Colors.black;
  static const Color chatTextOther = Color(0xFF1A1A1A);

  // Input
  static const Color inputFill = Color(0xFFF5F5F5);
  static const Color inputBorder = Color(0xFFE5E7EB);

  // Navigation
  static const Color bottomNavBackground = Color(0xFFFFFFFF);
  static const Color navSelected = Color(0xFFF29F05);
  static const Color navUnselected = Color(0xFF9CA3AF);

  // Semantic
  static const Color error = Colors.red;
  static const Color success = Colors.green;
}
