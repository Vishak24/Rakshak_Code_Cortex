import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/rk_button.dart';
import '../../../core/widgets/rk_label.dart';
import '../../../core/widgets/rk_status_chip.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/constants/pincode_map.dart';
import '../../../core/widgets/judge_mode_overlay.dart';
import 'intelligence_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Score Screen — Final intelligence result
// Shows risk score, alert prompt, AI analysis card.
// Shows Judge Mode context banner when result came from simulation.
// ─────────────────────────────────────────────────────────────────────────────

class ScoreScreen extends ConsumerWidget {
  const ScoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).languageCode;
    final state = ref.watch(intelligenceControllerProvider);

    // Judge Mode context
    final judgeHour = ref.watch(judgeHourProvider);
    final judgePincode = ref.watch(judgePincodeProvider) ?? 0;
    final isJudgeMode = judgePincode >= 600001;

    final score = state.result?.score ?? 0;
    final isCritical = score >= 75;
    final scoreColor = isCritical ? AppColors.riskHigh : AppColors.riskMedium;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                  vertical: AppSpacing.sm),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: AppColors.textSecondary, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  RkLabel.small('RAKSHAK', color: AppColors.textPrimary),
                ],
              ),
            ),

            // ── Judge Mode context banner ─────────────────────────────
            if (isJudgeMode)
              _JudgeBanner(pincode: judgePincode, hour: judgeHour),

            // ── Scrollable content ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                    vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // ── Score hero ──────────────────────────────────────
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Text(
                            score > 0 ? score.toString() : '--',
                            style: GoogleFonts.inter(
                              fontSize: 120,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              color: scoreColor,
                              letterSpacing: -0.02 * 120,
                            ),
                          ),
                          if (isCritical)
                            Positioned(
                              top: 8,
                              right: -8,
                              child: Transform.rotate(
                                angle: -0.35,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.riskHigh,
                                    borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusSm),
                                  ),
                                  child: Text(
                                    'HIGH RISK',
                                    style: AppText.labelSmallCaps.copyWith(
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // ── CRITICAL INTELLIGENCE badge ─────────────────────
                    if (isCritical)
                      Center(
                        child: RkStatusChip(
                          label: '⚠ CRITICAL INTELLIGENCE',
                          color: AppColors.riskHigh,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),

                    // ── Anomaly text ────────────────────────────────────
                    Center(
                      child: Text(
                        lang == 'ta'
                            ? 'தற்போதைய சுற்றுப்புறத்தில் அசாதாரண வடிவம் கண்டறியப்பட்டது.'
                            : 'Anomalous pattern detected in current vicinity.',
                        style: AppText.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Alert emergency services card ───────────────────
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'ta'
                                ? 'அவசர சேவைகளை எச்சரிக்கவா?'
                                : 'Alert emergency services?',
                            style: AppText.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'அவசர சேவைகளை அழைக்கவா?',
                            style: AppText.bodyMedium
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── YES button ──────────────────────────────────────
                    GestureDetector(
                      onTap: () => context.push('/sos'),
                      child: Container(
                        height: AppSpacing.buttonHeight,
                        decoration: BoxDecoration(
                          color: AppColors.riskHigh,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: Center(
                          child: Text(
                            '✦  YES',
                            style: AppText.button
                                .copyWith(color: Colors.white, letterSpacing: 1),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // ── NO button ───────────────────────────────────────
                    RkButton(
                      label: 'NO',
                      variant: RkButtonVariant.secondary,
                      onPressed: () => context.pop(),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── AI System Analysis card ─────────────────────────
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: const Border(
                          left: BorderSide(
                              color: AppColors.accentBright, width: 2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm),
                            ),
                            child: const Icon(Icons.psychology_outlined,
                                color: AppColors.accentBright, size: 18),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: RkLabel.small('SYSTEM ANALYSIS',
                                          color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        color: AppColors.riskHigh,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: RkLabel.small('LIVE MONITORING',
                                          color: AppColors.riskHigh),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  state.result != null
                                      ? state.result!.factors.join(' · ')
                                      : 'AI Sentinel has cross-referenced local incident reports with current biometric spikes. Confidence level: 94%.',
                                  style: AppText.bodyMedium.copyWith(
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Judge Mode context banner ─────────────────────────────────────────────────

class _JudgeBanner extends StatelessWidget {
  final int pincode;
  final int hour;

  const _JudgeBanner({required this.pincode, required this.hour});

  @override
  Widget build(BuildContext context) {
    final areaName = pincodeToAreaName[pincode] ?? 'Chennai';
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:00';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(
          left: BorderSide(color: AppColors.accentBright, width: 2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on,
              color: AppColors.accentBright, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$pincode · $areaName',
              style: AppText.labelSmallCaps.copyWith(
                  color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            ' · ',
            style: AppText.labelSmallCaps
                .copyWith(color: AppColors.textTertiary),
          ),
          const Icon(Icons.access_time,
              color: AppColors.accentBright, size: 14),
          const SizedBox(width: 4),
          Text(
            timeStr,
            style: AppText.labelSmallCaps.copyWith(
                color: AppColors.accentBright),
          ),
        ],
      ),
    );
  }
}
