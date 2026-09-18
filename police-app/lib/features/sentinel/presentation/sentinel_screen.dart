import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/rk_button.dart';
import '../../../core/widgets/rk_label.dart';
import '../../../core/widgets/rk_pulse.dart';
import '../../../core/widgets/rk_status_chip.dart';
import '../../../core/providers/settings_provider.dart';
import 'sentinel_controller.dart';

class SentinelScreen extends ConsumerStatefulWidget {
  const SentinelScreen({super.key});

  @override
  ConsumerState<SentinelScreen> createState() => _SentinelScreenState();
}

class _SentinelScreenState extends ConsumerState<SentinelScreen> {
  Timer? _timeTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timeTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _updateTime());
    Future.microtask(
        () => ref.read(sentinelControllerProvider.notifier).loadRiskScore());
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm').format(DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    super.dispose();
  }

  Color _scoreColor(int? score) {
    if (score == null) return AppColors.textTertiary;
    if (score >= 75) return AppColors.riskHigh;
    if (score >= 50) return AppColors.riskMedium;
    return AppColors.textPrimary; // LOW = white per Stitch design
  }

  String _chipLabel(int? score) {
    if (score == null) return 'UNKNOWN';
    if (score >= 75) return 'CRITICAL';
    if (score >= 50) return 'ELEVATED';
    return 'PROTECTED';
  }

  @override
  Widget build(BuildContext context) {
    // TODO: wire to settingsProvider.languageCode
    final lang = ref.watch(settingsProvider).languageCode;
    // TODO: wire to sentinelControllerProvider
    final state = ref.watch(sentinelControllerProvider);
    final score = state.riskScore?.score;
    final location = state.pincode > 0
        ? '${state.pincode} · ${state.areaName.toUpperCase()}'
        : '— · ACQUIRING LOCATION';
    final scoreColor = _scoreColor(score);
    final chipLabel = _chipLabel(score);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Subtle dot-grid background texture
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

          SafeArea(
            bottom: false, // bottom nav handles its own safe area
            child: Column(
              children: [
                // ── 1. AppBar ─────────────────────────────────────────
                _AppBar(time: _currentTime),

                // ── 2. Location label ─────────────────────────────────
                const SizedBox(height: AppSpacing.sm),
                _LocationLabel(location: location),

                // ── Scrollable content ────────────────────────────────
                if (state.isLoading)
                  const Expanded(child: _LoadingSkeleton())
                else
                  Expanded(
                    child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                    AppSpacing.screenPadding,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                              // ── 3. Shield icon ──────────────────────
                              const Icon(
                                Icons.shield,
                                color: AppColors.accentBright,
                                size: 64,
                              ),
                              const SizedBox(height: AppSpacing.sm),

                              // ── 4. Risk score number ────────────────
                              Text(
                                score?.toString() ?? '--',
                                style: GoogleFonts.inter(
                                  fontSize: 96,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                  color: scoreColor,
                                  letterSpacing: -1.5,
                                ),
                              ),

                              // ── 5. "YOUR CURRENT RISK SCORE" label ──
                              Text(
                                lang == 'ta'
                                    ? 'உங்கள் தற்போதைய ஆபத்து மதிப்பெண்'
                                    : 'YOUR CURRENT RISK SCORE',
                                style: AppText.labelSmallCaps.copyWith(
                                    color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.sm),

                              // ── 6. Status chip ──────────────────────
                              RkStatusChip(
                                  label: chipLabel, color: scoreColor),
                              const SizedBox(height: AppSpacing.lg),

                              // ── 7. SOS EMERGENCY button ─────────────
                              _SosButton(lang: lang),
                              const SizedBox(height: AppSpacing.sm),

                              // ── 8. SAFETY INTELLIGENCE button ───────
                              _IntelligenceButton(lang: lang),
                              const SizedBox(height: AppSpacing.md),

                              // ── 9. Stats row ─────────────────────────
                              _StatsRow(state: state, lang: lang),
                              const SizedBox(height: AppSpacing.md),

                              // ── 10. Suraksha Mode ─────────────────────
                              const _SurakshaSection(),
                              const SizedBox(height: AppSpacing.md),

                              // ── 11. AI monitoring banner ─────────────
                              _MonitorBanner(lang: lang),
                            ],
                          ),
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 1. AppBar ─────────────────────────────────────────────────────────────────

class _AppBar extends ConsumerWidget {
  final String time;
  const _AppBar({required this.time});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
      child: Row(
        children: [
          // Shield icon — left
          const Icon(Icons.shield, color: AppColors.accentBright, size: 20),
          const SizedBox(width: 6),
          // RAKSHAK — centered via Expanded
          Expanded(
            child: Text(
              'RAKSHAK',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 2.5,
              ),
            ),
          ),
          // Profile icon — right
          if (time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(
                time,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          GestureDetector(
            onTap: () => ref.read(settingsProvider.notifier).toggleLanguage(),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(Icons.person_outline,
                  color: AppColors.accentBright, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. Location label ─────────────────────────────────────────────────────────

class _LocationLabel extends StatelessWidget {
  final String location;
  const _LocationLabel({required this.location});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_on,
            color: AppColors.accentBright, size: 12),
        const SizedBox(width: 4),
        Text(
          location,
          style: AppText.labelSmallCaps.copyWith(
              color: AppColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}

// ── 7. SOS button ─────────────────────────────────────────────────────────────

class _SosButton extends StatelessWidget {
  final String lang;
  const _SosButton({required this.lang});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/sos'),
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.alertRed,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SOS',
              style: GoogleFonts.inter(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'EMERGENCY',
              style: AppText.labelSmallCaps.copyWith(
                color: Colors.white.withValues(alpha: 0.80),
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 8. Intelligence button ────────────────────────────────────────────────────

class _IntelligenceButton extends StatelessWidget {
  final String lang;
  const _IntelligenceButton({required this.lang});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/intelligence'),
      child: Container(
        width: double.infinity,
        height: AppSpacing.buttonHeight,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: AppColors.accentBright, width: 1.5),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                lang == 'ta' ? 'பாதுகாப்பு நுண்ணறிவு' : 'SAFETY INTELLIGENCE',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentBright,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                lang == 'ta'
                    ? 'பகுதி அச்சுறுத்தல் ஸ்கேன்'
                    : 'ugamvu · பகுதி ஸ்கேன்',
                style: AppText.labelSmallCaps.copyWith(
                    color: AppColors.textSecondary, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 9. Stats row ──────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final SentinelState state;
  final String lang;
  const _StatsRow({required this.state, required this.lang});

  @override
  Widget build(BuildContext context) {
    // TODO: wire incidents count to real data
    const incidentsToday = 3;
    final nearestStation =
        state.riskScore?.location.split('·').last.trim() ??
            state.areaName;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: lang == 'ta' ? 'இன்றைய சம்பவங்கள்' : 'INCIDENTS TODAY',
            value: incidentsToday.toString(),
            isNumeric: true,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            label: lang == 'ta' ? 'அருகிலுள்ள நிலையம்' : 'NEAREST STATION',
            value: nearestStation,
            isNumeric: false,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isNumeric;
  const _StatCard(
      {required this.label, required this.value, required this.isNumeric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RkLabel.small(label, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: isNumeric
                ? GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.0,
                  )
                : GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── 10. Monitor banner ────────────────────────────────────────────────────────

class _MonitorBanner extends StatelessWidget {
  final String lang;
  const _MonitorBanner({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: RkPulse(
            color: AppColors.accentBright,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accentBright,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            lang == 'ta'
                ? 'Rakshak AI 2.4கிமீ சுற்றளவில் உள்ளூர் துயர சமிக்ஞைகளை கண்காணிக்கிறது.'
                : 'Rakshak AI is monitoring local distress signals within a 2.4km radius.',
            style: AppText.bodyMedium.copyWith(
                color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Shimmer(width: 64, height: 64, radius: AppSpacing.radiusMd),
          const SizedBox(height: AppSpacing.md),
          _Shimmer(width: 140, height: 96, radius: AppSpacing.radiusSm),
          const SizedBox(height: AppSpacing.md),
          _Shimmer(
              width: double.infinity,
              height: 110,
              radius: AppSpacing.radiusSm),
          const SizedBox(height: AppSpacing.sm),
          _Shimmer(
              width: double.infinity,
              height: AppSpacing.buttonHeight,
              radius: AppSpacing.radiusSm),
        ],
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _Shimmer(
      {required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── 10. Suraksha Mode section ─────────────────────────────────────────────────

class _SurakshaSection extends ConsumerWidget {
  const _SurakshaSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(surakshaControllerProvider);
    final ctrl = ref.read(surakshaControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          color: AppColors.surfaceContainer,
          thickness: 1,
          height: 1,
        ),
        const SizedBox(height: AppSpacing.sm),

        Row(
          children: [
            const Icon(Icons.home_outlined,
                color: AppColors.accentBright, size: 15),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: RkLabel.small('SURAKSHA MODE',
                  color: AppColors.textSecondary),
            ),
            Transform.scale(
              scale: 0.75,
              alignment: Alignment.centerRight,
              child: Switch(
                value: s.enabled,
                onChanged: (_) => ctrl.toggle(),
                activeThumbColor: AppColors.accentBright,
                activeTrackColor:
                    AppColors.accent.withValues(alpha: 0.30),
                inactiveThumbColor: AppColors.surfaceHigh,
                inactiveTrackColor: AppColors.surfaceContainer,
              ),
            ),
          ],
        ),

        if (s.enabled) ...[
          const SizedBox(height: AppSpacing.xs),

          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              RkLabel.small('HOME: ANNA NAGAR, CHENNAI',
                  color: AppColors.textTertiary),
            ],
          ),

          const SizedBox(height: AppSpacing.xs),

          // "I'm staying out tonight" override
          Row(
            children: [
              const Icon(Icons.nightlife_outlined,
                  color: AppColors.textTertiary, size: 14),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: RkLabel.small("I'M STAYING OUT TONIGHT",
                    color: AppColors.textSecondary),
              ),
              Transform.scale(
                scale: 0.75,
                alignment: Alignment.centerRight,
                child: Switch(
                  value: s.stayingOut,
                  onChanged: (_) => ctrl.toggleStayingOut(),
                  activeThumbColor: AppColors.riskMedium,
                  activeTrackColor:
                      AppColors.riskMedium.withValues(alpha: 0.30),
                  inactiveThumbColor: AppColors.surfaceHigh,
                  inactiveTrackColor: AppColors.surfaceContainer,
                ),
              ),
            ],
          ),

          if (s.stayingOut)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: RkLabel.small('CHECK-INS SILENCED FOR TONIGHT',
                  color: AppColors.riskMedium),
            ),

          const SizedBox(height: AppSpacing.xs),

          RkButton(
            label: 'SIMULATE 10 PM CHECK',
            icon: Icons.nightlight_round,
            isLoading: s.isCheckinLoading,
            onPressed: s.isCheckinLoading || s.stayingOut ? null : ctrl.simulateCheckin,
          ),

          if (s.checkinMessage.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _CheckinCard(message: s.checkinMessage),
          ],

          if (s.checkinMessage.isNotEmpty &&
              !s.isEscalating &&
              !s.isEscalated) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _ResponseButton(
                    label: '✅ I\'m Safe',
                    color: AppColors.success,
                    onTap: ctrl.markSafe,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _ResponseButton(
                    label: '🆘 Need Help',
                    color: AppColors.riskHigh,
                    onTap: () => ctrl.escalate(),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _ResponseButton(
                    label: '📍 Share Location',
                    color: AppColors.accentBright,
                    onTap: ctrl.shareLocation,
                  ),
                ),
              ],
            ),
          ],

          if (s.isEscalating && !s.isEscalated) ...[
            const SizedBox(height: AppSpacing.md),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.riskHigh,
                  strokeWidth: 2,
                ),
              ),
            ),
          ],

          if (s.isEscalated && s.escalationMessage.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _EscalationCard(
              message: s.escalationMessage,
              unitsNotified: s.unitsNotified,
            ),
          ],
        ],
      ],
    );
  }
}

class _CheckinCard extends StatelessWidget {
  final String message;
  const _CheckinCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: const Border(
          left: BorderSide(color: AppColors.accentBright, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 12)),
              const SizedBox(width: AppSpacing.xs),
              RkLabel.small('GEMMA AI CHECK-IN',
                  color: AppColors.accentBright),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppText.bodyMedium.copyWith(
                color: AppColors.textSecondary, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _ResponseButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ResponseButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ),
      ),
    );
  }
}

class _EscalationCard extends StatelessWidget {
  final String message;
  final int unitsNotified;
  const _EscalationCard(
      {required this.message, required this.unitsNotified});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.alertRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
            color: AppColors.riskHigh.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_police_outlined,
              color: AppColors.riskHigh, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RkLabel.small('POLICE ALERTED',
                        color: AppColors.riskHigh),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.riskHigh.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '$unitsNotified UNITS',
                        style: AppText.labelSmallCaps.copyWith(
                            color: AppColors.riskHigh, fontSize: 9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: AppText.bodySmall
                      .copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dot grid background ───────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
