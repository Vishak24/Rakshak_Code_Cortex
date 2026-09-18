import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';
import 'rk_button.dart';
import '../../features/intelligence/presentation/intelligence_controller.dart';
import '../../features/sentinel/presentation/sentinel_controller.dart';
import '../../core/models/risk_prediction_request.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Whether the Judge Mode panel is open.
final judgePanelOpenProvider = StateProvider<bool>((ref) => false);

/// Selected hour override (0–23).
final judgeHourProvider = StateProvider<int>((ref) => 14);

/// Selected pincode from the Judge Mode dropdown (null = nothing selected).
/// Read by score_screen.dart to show the simulation context banner.
final judgePincodeProvider = StateProvider<int?>((ref) => null);

// ── Constants ─────────────────────────────────────────────────────────────────

const double _kPanelWidth = 260.0;

// ── Dropdown items — built once at compile time ───────────────────────────────

const _kPincodeItems = <DropdownMenuItem<int>>[
  DropdownMenuItem(value: 600001, child: Text('600001 · Park Town')),
  DropdownMenuItem(value: 600002, child: Text('600002 · Sowcarpet')),
  DropdownMenuItem(value: 600003, child: Text('600003 · Royapuram')),
  DropdownMenuItem(value: 600004, child: Text('600004 · Chintadripet')),
  DropdownMenuItem(value: 600005, child: Text('600005 · Royapettah')),
  DropdownMenuItem(value: 600006, child: Text('600006 · Triplicane')),
  DropdownMenuItem(value: 600007, child: Text('600007 · Egmore')),
  DropdownMenuItem(value: 600008, child: Text('600008 · Nungambakkam')),
  DropdownMenuItem(value: 600009, child: Text('600009 · Kilpauk')),
  DropdownMenuItem(value: 600010, child: Text('600010 · Aminjikarai')),
  DropdownMenuItem(value: 600011, child: Text('600011 · Perambur')),
  DropdownMenuItem(value: 600012, child: Text('600012 · Ashok Nagar')),
  DropdownMenuItem(value: 600013, child: Text('600013 · Tiruvottiyur')),
  DropdownMenuItem(value: 600015, child: Text('600015 · Pattabiram')),
  DropdownMenuItem(value: 600017, child: Text('600017 · T. Nagar')),
  DropdownMenuItem(value: 600018, child: Text('600018 · Abiramapuram')),
  DropdownMenuItem(value: 600019, child: Text('600019 · Vyasarpadi')),
  DropdownMenuItem(value: 600020, child: Text('600020 · Saidapet')),
  DropdownMenuItem(value: 600024, child: Text('600024 · Pallavaram')),
  DropdownMenuItem(value: 600028, child: Text('600028 · Adyar')),
  DropdownMenuItem(value: 600029, child: Text('600029 · Besant Nagar')),
  DropdownMenuItem(value: 600032, child: Text('600032 · Alwarpet')),
  DropdownMenuItem(value: 600033, child: Text('600033 · Valasaravakkam')),
  DropdownMenuItem(value: 600034, child: Text('600034 · Anna Nagar West')),
  DropdownMenuItem(value: 600035, child: Text('600035 · Anna Nagar East')),
  DropdownMenuItem(value: 600036, child: Text('600036 · Arumbakkam')),
  DropdownMenuItem(value: 600040, child: Text('600040 · Nanganallur')),
  DropdownMenuItem(value: 600042, child: Text('600042 · Velachery')),
  DropdownMenuItem(value: 600044, child: Text('600044 · Perungudi')),
  DropdownMenuItem(value: 600045, child: Text('600045 · Thoraipakkam')),
  DropdownMenuItem(value: 600050, child: Text('600050 · Mogappair')),
  DropdownMenuItem(value: 600053, child: Text('600053 · Villivakkam')),
  DropdownMenuItem(value: 600056, child: Text('600056 · Kolathur')),
  DropdownMenuItem(value: 600058, child: Text('600058 · Royapuram')),
  DropdownMenuItem(value: 600061, child: Text('600061 · Mugalivakkam')),
  DropdownMenuItem(value: 600064, child: Text('600064 · Medavakkam')),
  DropdownMenuItem(value: 600078, child: Text('600078 · Ambattur')),
  DropdownMenuItem(value: 600081, child: Text('600081 · Manali')),
  DropdownMenuItem(value: 600082, child: Text('600082 · Puzhal')),
  DropdownMenuItem(value: 600083, child: Text('600083 · Madhavaram')),
  DropdownMenuItem(value: 600090, child: Text('600090 · Velachery')),
  DropdownMenuItem(value: 600096, child: Text('600096 · OMR')),
  DropdownMenuItem(value: 600099, child: Text('600099 · Kundrathur')),
  DropdownMenuItem(value: 600118, child: Text('600118 · Perumbakkam')),
];

// ── Overlay ───────────────────────────────────────────────────────────────────

/// Wraps any screen. Renders a persistent teal pull-tab on the right edge
/// and a slide-in Judge Mode panel.
/// No BackdropFilter — avoids blur/compositing errors.
class JudgeModeOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const JudgeModeOverlay({super.key, required this.child});

  @override
  ConsumerState<JudgeModeOverlay> createState() => _JudgeModeOverlayState();
}

class _JudgeModeOverlayState extends ConsumerState<JudgeModeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = ref.watch(judgePanelOpenProvider);
    final activePin = ref.watch(judgePincodeProvider);
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // ── App content ────────────────────────────────────────────────
        widget.child,

        // ── Scrim — tap outside to close ───────────────────────────────
        if (isOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  ref.read(judgePanelOpenProvider.notifier).state = false,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),

        // ── SIMULATION MODE badge — shown when a pincode is active ─────
        if (activePin != null)
          Positioned(
            right: isOpen ? _kPanelWidth + 6 : 28,
            top: topPad + 8,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentBright.withValues(alpha: 0.12),
                  border: Border.all(
                      color: AppColors.accentBright.withValues(alpha: 0.7)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'SIMULATION MODE',
                  style: AppText.labelSmallCaps.copyWith(
                    color: AppColors.accentBright,
                    fontSize: 8,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),

        // ── Pull-tab ───────────────────────────────────────────────────
        Positioned(
          right: isOpen ? _kPanelWidth : 0,
          top: topPad,
          bottom: 0,
          child: Center(
            child: Tooltip(
              message: 'Drag to simulate pincode',
              child: GestureDetector(
                onTap: () =>
                    ref.read(judgePanelOpenProvider.notifier).state = !isOpen,
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx < -4) {
                    ref.read(judgePanelOpenProvider.notifier).state = true;
                  } else if (details.delta.dx > 4) {
                    ref.read(judgePanelOpenProvider.notifier).state = false;
                  }
                },
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) =>
                      Opacity(opacity: _pulseAnim.value, child: child),
                  child: Container(
                    width: 22,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: AppColors.accentBright,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(AppSpacing.radiusMd),
                        bottomLeft: Radius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.drag_handle,
                          color: AppColors.accentDark,
                          size: 13,
                        ),
                        const SizedBox(height: 5),
                        RotatedBox(
                          quarterTurns: 1,
                          child: Text(
                            'JM',
                            style: AppText.labelSmallCaps.copyWith(
                              color: AppColors.accentDark,
                              fontSize: 9,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Slide-in panel ─────────────────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          right: isOpen ? 0 : -_kPanelWidth,
          top: 0,
          bottom: 0,
          width: _kPanelWidth,
          child: const _JudgePanel(),
        ),
      ],
    );
  }
}

// ── Panel ─────────────────────────────────────────────────────────────────────

class _JudgePanel extends ConsumerStatefulWidget {
  const _JudgePanel();

  @override
  ConsumerState<_JudgePanel> createState() => _JudgePanelState();
}

class _JudgePanelState extends ConsumerState<_JudgePanel> {
  // Default to T. Nagar for judge mode demos; user can change via dropdown
  int? _selectedPincode = 600017;
  bool _isSimulating = false;

  Future<void> _simulate(BuildContext context) async {
    // ── Step 1: Validate ────────────────────────────────────────────────
    if (_selectedPincode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a pincode.'),
          backgroundColor: Color(0xFF93000A),
        ),
      );
      return;
    }

    final pincode = _selectedPincode!;
    final hour = ref.read(judgeHourProvider);

    // Read current lat/lon from sentinel state (fallback if pincode has no coords)
    final sentinelState = ref.read(sentinelControllerProvider);
    final lat = sentinelState.latitude;
    final lng = sentinelState.longitude;

    // Build the Judge Mode request — forJudge uses pincode coords when available
    final request = RiskPredictionRequest.forJudge(lat, lng, pincode, hour);

    // ── Step 2: Close panel ─────────────────────────────────────────────
    ref.read(judgePanelOpenProvider.notifier).state = false;

    // ── Step 3: Reset intelligence state so the analyzing screen starts fresh
    ref.read(intelligenceControllerProvider.notifier).reset();

    // ── Step 4: Navigate to the analyzing screen ────────────────────────
    if (!context.mounted) return;
    GoRouter.of(context).push('/intelligence');

    // ── Step 5: Call the backend with the full Judge Mode request ────────
    setState(() => _isSimulating = true);
    try {
      await ref
          .read(intelligenceControllerProvider.notifier)
          .scanWithRequest(request);

      // Sync the judge-mode pincode into sentinel state so the rest of the
      // system (SOS flow, police app, dashboard) sees the selected pincode.
      ref.read(sentinelControllerProvider.notifier).overridePincode(pincode);

      // Also refresh the sentinel home screen score
      ref.read(sentinelControllerProvider.notifier).loadRiskScore();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Simulation failed. Check connection.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hour = ref.watch(judgeHourProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () {},
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: _kPanelWidth,
            constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer.withValues(alpha: 0.97),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.radiusLg),
                bottomLeft: Radius.circular(AppSpacing.radiusLg),
              ),
              border: const Border(
                left: BorderSide(color: AppColors.accentBright, width: 2),
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ─────────────────────────────────────────
                    Text(
                      'JUDGE MODE',
                      style: AppText.labelSmallCaps.copyWith(
                        color: AppColors.accentBright,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Divider(color: AppColors.ghostBorder, height: 1),
                    const SizedBox(height: AppSpacing.md),

                    // ── HOUR label + current value ─────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'HOUR',
                          style: AppText.labelSmallCaps
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        Text(
                          '${hour.toString().padLeft(2, '0')}:00',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentBright,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // ── Hour slider ────────────────────────────────────
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.accentBright,
                        inactiveTrackColor: AppColors.surfaceHigh,
                        thumbColor: AppColors.accentBright,
                        overlayColor:
                            AppColors.accentBright.withValues(alpha: 0.15),
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: hour.toDouble(),
                        min: 0,
                        max: 23,
                        divisions: 23,
                        onChanged: (v) =>
                            ref.read(judgeHourProvider.notifier).state =
                                v.round(),
                      ),
                    ),

                    // Tick labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['0', '6', '12', '18', '23']
                          .map((t) => Text(
                                t,
                                style: AppText.labelSmallCaps
                                    .copyWith(fontSize: 9),
                              ))
                          .toList(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Pincode dropdown ───────────────────────────────
                    DropdownButtonFormField<int>(
                      initialValue: _selectedPincode,
                      dropdownColor: const Color(0xFF0D1B2A),
                      iconEnabledColor: AppColors.accentBright,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                      decoration: InputDecoration(
                        labelText: 'SELECT PINCODE',
                        labelStyle: GoogleFonts.inter(
                          color: AppColors.accentBright.withValues(alpha: 0.7),
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          borderSide: BorderSide(
                            color:
                                AppColors.accentBright.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          borderSide: const BorderSide(
                            color: AppColors.accentBright,
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0D1B2A),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      hint: Text(
                        'SELECT PINCODE · AREA',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      isExpanded: true,
                      menuMaxHeight: 320,
                      items: _kPincodeItems,
                      onChanged: (value) {
                        setState(() => _selectedPincode = value);
                        // Sync to provider so score_screen can show the banner
                        ref.read(judgePincodeProvider.notifier).state = value;
                      },
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── SIMULATE button ────────────────────────────────
                    RkButton(
                      label: _isSimulating ? 'SIMULATING...' : 'SIMULATE',
                      isLoading: _isSimulating,
                      onPressed:
                          _isSimulating ? null : () => _simulate(context),
                    ),

                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Developer simulation tool for testing geo-fenced activity triggers.',
                      style: AppText.labelSmallCaps.copyWith(
                        fontSize: 9,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
