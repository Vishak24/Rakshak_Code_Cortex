import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/rk_button.dart';
import '../../../core/widgets/rk_label.dart';
import '../../../core/widgets/rk_status_chip.dart';
import '../../../core/providers/settings_provider.dart';
import 'sentinel_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Night Watch Overlay — "Help is on the way" full-screen secured state
// ─────────────────────────────────────────────────────────────────────────────

class NightWatchOverlay extends ConsumerStatefulWidget {
  const NightWatchOverlay({super.key});

  @override
  ConsumerState<NightWatchOverlay> createState() => _NightWatchOverlayState();
}

class _NightWatchOverlayState extends ConsumerState<NightWatchOverlay> {
  Timer? _clockTimer;
  Timer? _etaTimer;
  String _clockTime = '';
  int _etaSeconds = 4 * 60 + 30; // 4:30

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _etaTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_etaSeconds > 0) _etaSeconds--;
      });
    });
  }

  void _updateClock() {
    if (mounted) {
      setState(() {
        _clockTime = DateFormat('HH:mm:ss').format(DateTime.now());
      });
    }
  }

  String get _etaDisplay {
    if (_etaSeconds <= 0) return 'ARRIVING';
    final m = _etaSeconds ~/ 60;
    final s = _etaSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).languageCode;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. STATUS BAR ─────────────────────────────────────────
              _StatusBar(clockTime: _clockTime),

              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),

                    // ── 2. HERO SECTION ───────────────────────────────
                    Text(
                      lang == 'ta'
                          ? 'உதவி வந்து கொண்டிருக்கிறது.'
                          : 'Help is on the way.',
                      style: AppText.displayLarge.copyWith(
                        fontSize: 48,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your location is secured. Please stay in a well-lit place.',
                      style: AppText.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'உங்கள் இருப்பிடம் பாதுகாப்பானது. வெளிச்சமான இடத்தில் இருக்கவும்.',
                      style: AppText.bodySmall
                          .copyWith(color: AppColors.textTertiary),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── 3. ACTIVE ELEMENTS ROW ────────────────────────
                    Row(
                      children: [
                        Expanded(child: _PatrolCard()),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _SignalCard()),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: _SentinelCard()),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── 4. PATROL ETA CARD ────────────────────────────
                    _EtaCard(
                        etaDisplay: _etaDisplay,
                        isArriving: _etaSeconds <= 0),

                    const SizedBox(height: AppSpacing.md),

                    // ── 5. SIGNAL / ENCRYPTION CHIPS ─────────────────
                    Row(
                      children: const [
                        RkStatusChip(
                          label: 'THREAT LEVEL: HIGH',
                          color: AppColors.riskHigh,
                        ),
                        SizedBox(width: AppSpacing.sm),
                        RkStatusChip(
                          label: 'ENCRYPTION: AES-256',
                          color: AppColors.accentBright,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // ── 6. AI ANALYSIS CARD ───────────────────────────
                    _AiAnalysisCard(),

                    const SizedBox(height: AppSpacing.lg),

                    // ── 7. DISMISS ALERT ──────────────────────────────
                    RkButton(
                      label: 'DISMISS ALERT',
                      variant: RkButtonVariant.secondary,
                      onPressed: () {
                        ref
                            .read(sentinelControllerProvider.notifier)
                            .toggleNightWatch();
                        Navigator.of(context).pop();
                      },
                    ),

                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 1. Status bar ─────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final String clockTime;
  const _StatusBar({required this.clockTime});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainer,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.shield, color: AppColors.accentBright, size: 18),
          const SizedBox(width: AppSpacing.xs),
          RkLabel.small('STATUS: SECURED', color: AppColors.accentBright),
          const Spacer(),
          Text(
            clockTime,
            style: AppText.labelSmallCaps.copyWith(
                color: AppColors.textSecondary, fontSize: 10),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.signal_cellular_alt,
              color: AppColors.accentBright, size: 16),
        ],
      ),
    );
  }
}

// ── 3a. Patrol card ───────────────────────────────────────────────────────────

class _PatrolCard extends StatefulWidget {
  @override
  State<_PatrolCard> createState() => _PatrolCardState();
}

class _PatrolCardState extends State<_PatrolCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.3)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ActiveCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _opacity,
            builder: (_, __) => Opacity(
              opacity: _opacity.value,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.accentBright,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          RkLabel.small('PATROL\nDISPATCH',
              color: AppColors.textSecondary),
          const SizedBox(height: 4),
          RkLabel.small('ACTIVE', color: AppColors.accentBright),
        ],
      ),
    );
  }
}

// ── 3b. Signal card ───────────────────────────────────────────────────────────

class _SignalCard extends StatefulWidget {
  @override
  State<_SignalCard> createState() => _SignalCardState();
}

class _SignalCardState extends State<_SignalCard> {
  Timer? _timer;
  int _bars = 3;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!mounted) return;
      setState(() {
        _bars = (_bars % 3) + 2; // cycles 2 → 3 → 4 → 2 …
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ActiveCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final active = i < _bars;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  width: 4,
                  height: 6.0 + i * 3.0,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.accentBright
                        : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          RkLabel.small('SIGNAL\nSTRENGTH',
              color: AppColors.textSecondary),
          const SizedBox(height: 4),
          RkLabel.small('$_bars / 4', color: AppColors.accentBright),
        ],
      ),
    );
  }
}

// ── 3c. Sentinel card ─────────────────────────────────────────────────────────

class _SentinelCard extends StatefulWidget {
  @override
  State<_SentinelCard> createState() => _SentinelCardState();
}

class _SentinelCardState extends State<_SentinelCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ActiveCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Transform.rotate(
              angle: _ctrl.value * 2 * 3.14159,
              child: child,
            ),
            child: const Icon(Icons.shield,
                color: AppColors.accentBright, size: 20),
          ),
          const SizedBox(height: 6),
          RkLabel.small('SENTINEL\nACTIVE',
              color: AppColors.textSecondary),
          const SizedBox(height: 4),
          RkLabel.small('ARMED', color: AppColors.accentBright),
        ],
      ),
    );
  }
}

// ── Active card shell ─────────────────────────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  final Widget child;
  const _ActiveCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Center(child: child),
    );
  }
}

// ── 4. ETA card ───────────────────────────────────────────────────────────────

class _EtaCard extends StatelessWidget {
  final String etaDisplay;
  final bool isArriving;

  const _EtaCard({required this.etaDisplay, required this.isArriving});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_police_outlined,
              color: AppColors.accentBright, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: RkLabel.small('PATROL DISPATCH ACTIVE',
                color: AppColors.accentBright),
          ),
          Text(
            etaDisplay,
            style: AppText.labelSmallCaps.copyWith(
              color: isArriving ? AppColors.accentBright : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 6. AI analysis card ───────────────────────────────────────────────────────

class _AiAnalysisCard extends StatefulWidget {
  @override
  State<_AiAnalysisCard> createState() => _AiAnalysisCardState();
}

class _AiAnalysisCardState extends State<_AiAnalysisCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.4)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pulsing dot
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: AnimatedBuilder(
              animation: _opacity,
              builder: (_, __) => Opacity(
                opacity: _opacity.value,
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
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RkLabel.small('SYSTEM ANALYSIS',
                        color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Text(' · ', style: AppText.labelSmallCaps),
                    RkLabel.small('LIVE MONITORING',
                        color: AppColors.accentBright),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'AI Sentinel has cross-referenced local incident reports with current biometric spikes. Confidence level: 94%.',
                  style: AppText.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
