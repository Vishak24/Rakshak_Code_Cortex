import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Rakshak Sentinel Typography — Inter only, editorial scale
/// Rule: jump from very large to very small. No middle-ground sizes.
class AppText {
  AppText._();

  // ── Display ──────────────────────────────────────────────────────────────
  /// 3.5rem / 56px — critical status, risk score hero
  static TextStyle displayLarge = GoogleFonts.inter(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: AppColors.textPrimary,
    letterSpacing: -0.02 * 56,
  );

  /// 2.75rem / 44px — secondary hero text
  static TextStyle displayMedium = GoogleFonts.inter(
    fontSize: 44,
    fontWeight: FontWeight.w700,
    height: 1.1,
    color: AppColors.textPrimary,
    letterSpacing: -0.02 * 44,
  );

  // Legacy aliases so existing code compiles
  static TextStyle display1 = displayLarge;
  static TextStyle display2 = displayMedium;

  // ── Headlines ─────────────────────────────────────────────────────────────
  /// 1.5rem / 24px — section headers
  static TextStyle headlineSmall = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  // Legacy aliases
  static TextStyle h1 = GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, height: 1.25, color: AppColors.textPrimary, letterSpacing: -0.5);
  static TextStyle h2 = headlineSmall;
  static TextStyle h3 = GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4, color: AppColors.textPrimary);
  static TextStyle h4 = GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, color: AppColors.textPrimary);

  // ── Body ──────────────────────────────────────────────────────────────────
  /// 0.875rem / 14px — standard body
  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  // Legacy aliases
  static TextStyle bodyLarge = GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.textPrimary);
  static TextStyle bodySmall = GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.textSecondary);

  // ── Labels ────────────────────────────────────────────────────────────────
  /// 0.6875rem / 11px — uppercase caps, metadata, chips
  static TextStyle labelSmallCaps = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.4,
    color: AppColors.textSecondary,
    letterSpacing: 0.05 * 11,
  );

  // Legacy aliases
  static TextStyle labelLarge  = GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4, color: AppColors.textPrimary, letterSpacing: 0.5);
  static TextStyle labelMedium = GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4, color: AppColors.textSecondary, letterSpacing: 0.5);
  static TextStyle labelSmall  = labelSmallCaps;

  // ── Buttons ───────────────────────────────────────────────────────────────
  static TextStyle button = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.5,
  );

  static TextStyle buttonSmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.5,
  );

  // ── Misc ──────────────────────────────────────────────────────────────────
  static TextStyle caption = GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4, color: AppColors.textSecondary);
  static TextStyle overline = GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, height: 1.4, color: AppColors.textTertiary, letterSpacing: 1.5);
}
