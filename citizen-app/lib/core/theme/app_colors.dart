import 'package:flutter/material.dart';

/// Rakshak Sentinel Color Palette — Stitch "Sentinel Glow" design system
class AppColors {
  AppColors._();

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color background       = Color(0xFF0A0F1E); // deep navy void
  static const Color surface          = Color(0xFF0E1322);
  static const Color surfaceContainer = Color(0xFF1A1F2F);
  static const Color surfaceHigh      = Color(0xFF25293A);
  static const Color surfaceHighest   = Color(0xFF2F3445);

  // Legacy aliases kept so untouched files compile
  static const Color primary          = Color(0xFF0A0F1E);
  static const Color primaryLight     = Color(0xFF1A1F2F);
  static const Color surfaceLight     = Color(0xFF1A1F2F);

  // ── Accent ───────────────────────────────────────────────────────────────
  static const Color accent           = Color(0xFF00D4B4); // electric teal seed
  static const Color accentBright     = Color(0xFF46F1CF); // primary on surface
  static const Color accentDark       = Color(0xFF00382E); // text on teal bg

  // ── Risk ─────────────────────────────────────────────────────────────────
  static const Color riskLow          = Color(0xFF22C55E);
  static const Color riskMedium       = Color(0xFFF59E0B);
  static const Color riskHigh         = Color(0xFFFF3B5C);
  static const Color riskCritical     = Color(0xFFFF3B5C);

  // ── Functional ───────────────────────────────────────────────────────────
  static const Color success          = Color(0xFF22C55E);
  static const Color warning          = Color(0xFFF59E0B);
  static const Color error            = Color(0xFFFF3B5C);
  static const Color alertRed         = Color(0xFF93000A); // danger bg
  static const Color info             = Color(0xFF46F1CF);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary      = Color(0xFFFFFFFF);
  static const Color textSecondary    = Color(0xB3FFFFFF); // 70% white
  static const Color textTertiary     = Color(0x66FFFFFF); // 40% white

  // ── Borders ──────────────────────────────────────────────────────────────
  /// Ghost border — 1px, used on inputs only
  static const Color ghostBorder      = Color(0x263B4A45); // rgba(59,74,69,0.15)
  static const Color border           = Color(0xFF1F2937); // legacy alias
  static const Color divider          = Color(0xFF111827); // legacy alias

  // ── Shadows ──────────────────────────────────────────────────────────────
  /// Ambient shadow: #000 @ 40%, blur 40, spread -10
  static List<BoxShadow> ambientShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.40),
      blurRadius: 40,
      spreadRadius: -10,
    ),
  ];

  // ── Glassmorphism ─────────────────────────────────────────────────────────
  /// Floating elements: surfaceContainer @ 85% opacity + blur(20)
  static Color get glassBackground =>
      surfaceContainer.withValues(alpha: 0.85);
}
