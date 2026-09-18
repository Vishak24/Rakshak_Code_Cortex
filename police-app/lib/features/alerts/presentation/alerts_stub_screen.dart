import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/rk_label.dart';
import '../../../core/widgets/rk_pulse.dart';

/// Alerts Screen — placeholder matching app style.
/// Bottom nav active on Alerts.
class AlertsStubScreen extends StatelessWidget {
  const AlertsStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.shield,
                      color: AppColors.accentBright, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'RAKSHAK',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              RkLabel.small('ALERTS / எச்சரிக்கைகள்',
                  color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.lg),

              // Placeholder content
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RkPulse(
                        color: AppColors.accentBright,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.accentBright.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd),
                          ),
                          child: const Icon(Icons.notifications_outlined,
                              color: AppColors.accentBright, size: 24),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      RkLabel.small('NO ACTIVE ALERTS',
                          color: AppColors.textSecondary),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Alert feed coming soon.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
