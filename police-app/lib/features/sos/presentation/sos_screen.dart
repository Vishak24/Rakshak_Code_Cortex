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
import '../../../core/providers/settings_provider.dart';
import 'sos_controller.dart';

/// SOS Screen — Stitch design:
/// Phase 1: Full screen alert red, asterisk/star, "Contacting Emergency Services..."
/// Phase 2 (Night-Watch Secured): STATUS: SECURED, "Help is on the way", DISMISS ALERT,
/// current time + signal strength row, PATROL DISPATCH ACTIVE badge.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with SingleTickerProviderStateMixin {
  bool _isPhase2 = false;
  Timer? _timeTimer;
  String _currentTime = '';
  late AnimationController _starCtrl;
  late Animation<double> _starOpacity;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timeTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _starOpacity = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _starCtrl, curve: Curves.linear),
    );

    // TODO: wire to sosControllerProvider.triggerSos()
    Future.delayed(const Duration(milliseconds: 100), () {
      ref.read(sosControllerProvider.notifier).triggerSos();
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isPhase2 = true);
    });
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _starCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: wire to settingsProvider.languageCode
    final lang = ref.watch(settingsProvider).languageCode;
    // TODO: wire to sosControllerProvider for status
    ref.watch(sosControllerProvider);

    return PopScope(
      canPop: _isPhase2,
      child: Scaffold(
        backgroundColor:
            _isPhase2 ? AppColors.background : AppColors.alertRed,
        body: SafeArea(
          child: _isPhase2
              ? _Phase2(
                  lang: lang,
                  currentTime: _currentTime,
                )
              : _Phase1(
                  lang: lang,
                  starOpacity: _starOpacity,
                ),
        ),
      ),
    );
  }
}

// ── Phase 1: Contacting ───────────────────────────────────────────────────────

class _Phase1 extends StatelessWidget {
  final String lang;
  final Animation<double> starOpacity;

  const _Phase1({required this.lang, required this.starOpacity});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated asterisk — 120px, white, pulsing
            AnimatedBuilder(
              animation: starOpacity,
              builder: (_, child) =>
                  Opacity(opacity: starOpacity.value, child: child),
              child: Text(
                '*',
                style: GoogleFonts.inter(
                  fontSize: 120,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // "Contacting Emergency Services..."
            Text(
              lang == 'ta'
                  ? 'அவசர சேவைகளை தொடர்பு கொள்கிறது...'
                  : 'Contacting Emergency Services...',
              style: AppText.headlineSmall.copyWith(
                color: Colors.white,
                fontSize: 28,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            // RAKSHAK SENTINEL ACTIVE
            RkLabel.small(
              'RAKSHAK SENTINEL ACTIVE',
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Phase 2: Secured ──────────────────────────────────────────────────────────

class _Phase2 extends ConsumerWidget {
  final String lang;
  final String currentTime;

  const _Phase2({required this.lang, required this.currentTime});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── STATUS: SECURED header ──────────────────────────────────
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.shield,
                      color: AppColors.accentBright, size: 36),
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(Icons.check,
                        color: AppColors.accentBright, size: 14),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              RkLabel.small('STATUS: SECURED',
                  color: AppColors.accentBright),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── "Help is on the way." ─────────────────────────────────
          Text(
            lang == 'ta'
                ? 'உதவி வந்து கொண்டிருக்கிறது.'
                : 'Help is on the way.',
            style: AppText.displayLarge.copyWith(fontSize: 44),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Body text ─────────────────────────────────────────────
          Text(
            'Your location is secured. Help is on the way. Please stay in a well-lit place.',
            style: AppText.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'உங்கள் இருப்பிடம் பாதுகாப்பானது. உதவி வந்து கொண்டிருக்கிறது. வெளிச்சமான இடத்தில் இருக்கவும்.',
            style: AppText.bodyMedium.copyWith(
                color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── PATROL DISPATCH ACTIVE ────────────────────────────────
          Row(
            children: [
              RkPulse(
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
              const SizedBox(width: AppSpacing.sm),
              RkLabel.small('PATROL DISPATCH ACTIVE',
                  color: AppColors.accentBright),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── DISMISS ALERT ─────────────────────────────────────────
          RkButton(
            label: lang == 'ta' ? 'DISMISS ALERT' : 'DISMISS ALERT',
            variant: RkButtonVariant.secondary,
            onPressed: () async {
              await ref.read(sosControllerProvider.notifier).markSecured();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'SOS cancelled. Your number has been shared with the nearest patrol in case they need to follow up.',
                  ),
                  duration: Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              context.go('/sentinel');
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Time + Signal row ─────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RkLabel.small('CURRENT TIME',
                        color: AppColors.textSecondary),
                    const SizedBox(height: 4),
                    Text(
                      currentTime,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RkLabel.small('SIGNAL STRENGTH',
                        color: AppColors.textSecondary),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                        4,
                        (i) => Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Icon(
                            Icons.signal_cellular_alt,
                            color: AppColors.accentBright,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
