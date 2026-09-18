import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/rk_label.dart';
import '../../../core/providers/settings_provider.dart';
import 'intelligence_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Intelligence Screen — Loading / Analyzing
// Arc sweeps to riskIndex, scan rows appear sequentially, chips fade in.
// Minimum display time: 2400ms (Future.wait pattern).
// ─────────────────────────────────────────────────────────────────────────────

class IntelligenceScreen extends ConsumerStatefulWidget {
  const IntelligenceScreen({super.key});

  @override
  ConsumerState<IntelligenceScreen> createState() =>
      _IntelligenceScreenState();
}

class _IntelligenceScreenState extends ConsumerState<IntelligenceScreen>
    with TickerProviderStateMixin {
  // Arc animation
  late AnimationController _arcCtrl;
  late Animation<double> _arcAnim;

  // Percentage counter
  int _displayedPercent = 0;
  Timer? _counterTimer;

  // Scan row visibility
  final List<bool> _rowVisible = [false, false, false];
  final List<bool> _rowDone = [false, false, false];
  bool _chipsVisible = false;

  bool _apiDone = false;

  @override
  void initState() {
    super.initState();

    _arcCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _arcAnim = CurvedAnimation(parent: _arcCtrl, curve: Curves.easeOutCubic);

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Minimum display time + API call run in parallel
    final minDelay = Future<void>.delayed(const Duration(milliseconds: 2400));

    // Row 1 appears at 400ms, completes at 1000ms
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _rowVisible[0] = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _rowDone[0] = true);

    // Row 2 appears at 900ms from start (100ms after row 1 appears)
    // We're at 1000ms now, row 2 should have appeared at 900ms.
    // Show it immediately (it's already past 900ms).
    setState(() => _rowVisible[1] = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _rowDone[1] = true);

    // Row 3 appears at 1500ms from start — we're at ~1600ms, show immediately
    setState(() => _rowVisible[2] = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _rowDone[2] = true;
      _chipsVisible = true;
    });

    // Wait for both minimum time and API
    await minDelay;

    // Wait until API is done (controller state is complete/error)
    while (!_apiDone && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;

    // Arc always sweeps 0→100% (analysis progress, not risk score)
    _arcCtrl.forward();
    _startCounter(100);

    // Wait for arc animation to finish
    await Future<void>.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;

    context.pushReplacement('/score');
  }

  void _startCounter(int target) {
    _counterTimer?.cancel();
    final steps = 36; // ~50ms per step over 1800ms
    int step = 0;
    _counterTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      step++;
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _displayedPercent = (target * step / steps).round().clamp(0, target);
      });
      if (step >= steps) t.cancel();
    });
  }

  @override
  void dispose() {
    _arcCtrl.dispose();
    _counterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).languageCode;
    final state = ref.watch(intelligenceControllerProvider);

    // Mark API done when controller reaches complete/error
    if ((state.status == ScanStatus.complete ||
            state.status == ScanStatus.error) &&
        !_apiDone) {
      _apiDone = true;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.md,
          ),
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_ios_new,
                        color: AppColors.textSecondary, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  RkLabel.small('SENTINEL INTELLIGENCE ACTIVE',
                      color: AppColors.accentBright),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Arc progress (220px) ──────────────────────────────────
              SizedBox(
                width: 220,
                height: 220,
                child: AnimatedBuilder(
                  animation: _arcAnim,
                  builder: (_, __) => CustomPaint(
                    painter: _ArcPainter(progress: _arcAnim.value),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_displayedPercent%',
                            style: AppText.displayLarge.copyWith(
                              color: AppColors.textPrimary,
                              fontFeatures: [
                                const FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          RkLabel.small('ANALYZING',
                              color: AppColors.accentBright),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Scan rows ─────────────────────────────────────────────
              ..._buildScanRows(lang),

              const SizedBox(height: AppSpacing.lg),

              // ── Chips (fade in after all rows done) ───────────────────
              AnimatedOpacity(
                opacity: _chipsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (_apiDone && state.result != null
                                  ? _riskColor(state.result!.score)
                                  : AppColors.textSecondary)
                              .withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(
                            color: _apiDone && state.result != null
                                ? _riskColor(state.result!.score)
                                : AppColors.textSecondary,
                          ),
                        ),
                        child: Text(
                          _apiDone && state.result != null
                              ? 'THREAT: ${state.result!.level.name.toUpperCase()}'
                              : 'THREAT LEVEL: —',
                          style: AppText.labelSmallCaps.copyWith(
                            color: _apiDone && state.result != null
                                ? _riskColor(state.result!.score)
                                : AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentBright.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          border: Border.all(color: AppColors.accentBright),
                        ),
                        child: Text(
                          'ENCRYPTION: AES-256',
                          style: AppText.labelSmallCaps
                              .copyWith(color: AppColors.accentBright),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── System integrity bar ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RkLabel.small('SYSTEM INTEGRITY',
                            color: AppColors.textSecondary),
                        RkLabel.small(
                          _apiDone ? 'COMPLETE' : 'PROCESSING...',
                          color: AppColors.accentBright,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedBuilder(
                      animation: _arcAnim,
                      builder: (_, __) => ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        child: LinearProgressIndicator(
                          value: _arcAnim.value,
                          minHeight: 4,
                          backgroundColor: AppColors.surfaceHigh,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.accentBright),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildScanRows(String lang) {
    const labels = [
      ('Scanning active location...', 'இருப்பிடத்தை ஸ்கேன் செய்கிறது...'),
      ('Analyzing threat patterns...', 'அச்சுறுத்தல் வடிவங்களை பகுப்பாய்வு செய்கிறது...'),
      ('Calculating Police ETA...', 'காவல் ரோந்து ETA கணக்கிடுகிறது...'),
    ];

    return List.generate(3, (i) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: AnimatedOpacity(
          opacity: _rowVisible[i] ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: _ScanRow(
            labelEn: labels[i].$1,
            labelTa: labels[i].$2,
            isDone: _rowDone[i],
            lang: lang,
          ),
        ),
      );
    });
  }

  Color _riskColor(int score) {
    if (score >= 75) return AppColors.riskHigh;
    if (score >= 50) return AppColors.riskMedium;
    return AppColors.riskLow;
  }
}

// ── Scan row ──────────────────────────────────────────────────────────────────

class _ScanRow extends StatelessWidget {
  final String labelEn;
  final String labelTa;
  final bool isDone;
  final String lang;

  const _ScanRow({
    required this.labelEn,
    required this.labelTa,
    required this.isDone,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: isDone
            ? const Border(
                left: BorderSide(color: AppColors.accentBright, width: 2))
            : null,
      ),
      child: Row(
        children: [
          // Dot — pulsing while pending, solid when done
          _ScanDot(isDone: isDone),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              lang == 'ta' ? labelTa : labelEn,
              style: AppText.bodyMedium.copyWith(
                color: isDone
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          if (isDone)
            Text(
              'OK',
              style: AppText.labelSmallCaps.copyWith(
                color: AppColors.accentBright,
                letterSpacing: 1,
              ),
            )
          else
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                color: AppColors.accentBright,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Animated dot ──────────────────────────────────────────────────────────────

class _ScanDot extends StatefulWidget {
  final bool isDone;
  const _ScanDot({required this.isDone});

  @override
  State<_ScanDot> createState() => _ScanDotState();
}

class _ScanDotState extends State<_ScanDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
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
    if (widget.isDone) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.accentBright,
          shape: BoxShape.circle,
        ),
      );
    }
    return AnimatedBuilder(
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
    );
  }
}

// ── Arc painter ───────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0

  const _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Track — surfaceContainer
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.surfaceContainer
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    // Arc — teal progress
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}
