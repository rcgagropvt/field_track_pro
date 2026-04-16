import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Colors
  static const Color primary = Color(0xFF006A61);
  static const Color primaryLight = Color(0xFF00897B);
  static const Color primaryDark = Color(0xFF004D40);
  static const Color primarySurface = Color(0xFFE0F2F1);

  // Accent
  static const Color accent = Color(0xFF00BFA5);
  static const Color accentLight = Color(0xFFB2DFDB);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE8ECF0);

  // Text
  static const Color textPrimary = Color(0xFF1A1F36);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // CRM Pipeline
  static const Color leadNew = Color(0xFF6366F1);
  static const Color leadContacted = Color(0xFF8B5CF6);
  static const Color leadQualified = Color(0xFF3B82F6);
  static const Color leadProposal = Color(0xFFF59E0B);
  static const Color leadNegotiation = Color(0xFFF97316);
  static const Color leadWon = Color(0xFF10B981);
  static const Color leadLost = Color(0xFFEF4444);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF006A61), Color(0xFF00897B)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF004D40), Color(0xFF006A61)],
  );
}


