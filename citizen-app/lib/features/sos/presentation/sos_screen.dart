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
import '../domain/sos_service.dart';
import 'sos_controller.dart';

/// SOS Screen — driven entirely by the live backend incident.
///
/// * triggering → full-red "Contacting Emergency Services…"
/// * active     → assigned patrol, live ETA (recomputed server-side), status
/// * resolved   → "You're Safe" once the patrol closes the incident
/// * error      → the SOS never reached the control room; say so plainly
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen>
    with SingleTickerProviderStateMixin {
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

    // Raise the SOS as soon as the screen opens. The backend assigns the
    // nearest free patrol inside that same call.
    Future.microtask(
        () => ref.read(sosControllerProvider.notifier).triggerSos());
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
    final lang  = ref.watch(settingsProvider).languageCode;
    final state = ref.watch(sosControllerProvider);

    final isContacting = state.status == SosStatus.idle ||
        state.status == SosStatus.triggering;

    Widget body;
    switch (state.status) {
      case SosStatus.idle:
      case SosStatus.triggering:
        body = _Phase1(lang: lang, starOpacity: _starOpacity);
        break;
      case SosStatus.active:
        body = _ActiveIncident(
          lang: lang,
          currentTime: _currentTime,
          assignment: state.assignment,
        );
        break;
      case SosStatus.resolved:
      case SosStatus.cancelled:
        body = _SafeScreen(
          lang: lang,
          assignment: state.assignment,
          wasCancelled: state.status == SosStatus.cancelled,
        );
        break;
      case SosStatus.error:
        body = _ErrorScreen(lang: lang, message: state.error);
        break;
    }

    return PopScope(
      canPop: !isContacting,
      child: Scaffold(
        backgroundColor:
            isContacting ? AppColors.alertRed : AppColors.background,
        body: SafeArea(child: body),
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

// ── Active incident: patrol assigned, live ETA ────────────────────────────────

class _ActiveIncident extends ConsumerWidget {
  final String lang;
  final String currentTime;
  final SosAssignment? assignment;

  const _ActiveIncident({
    required this.lang,
    required this.currentTime,
    required this.assignment,
  });

  String _etaDisplay(int? seconds) {
    if (seconds == null) return '—';
    if (seconds <= 0) return 'ARRIVING';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a        = assignment;
    final reached  = a?.isReached ?? false;
    final assigned = a?.isAssigned ?? false;
    final accent   = reached ? AppColors.riskLow : AppColors.accentBright;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── STATUS header ────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.shield, color: accent, size: 34),
              const SizedBox(width: AppSpacing.sm),
              RkLabel.small(
                reached ? 'STATUS: PATROL ON SCENE' : 'STATUS: SECURED',
                color: accent,
              ),
              const Spacer(),
              Text(
                currentTime,
                style: AppText.labelSmallCaps
                    .copyWith(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Headline ─────────────────────────────────────────────────
          Text(
            reached
                ? (lang == 'ta' ? 'ரோந்து வந்துவிட்டது.' : 'The patrol has arrived.')
                : (lang == 'ta' ? 'உதவி வந்து கொண்டிருக்கிறது.' : 'Help is on the way.'),
            style: AppText.displayLarge.copyWith(fontSize: 40),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            reached
                ? 'An officer is at your location. Stay where you are.'
                : 'Your location is shared with the control room. Please stay in a well-lit place.',
            style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Assigned patrol card ─────────────────────────────────────
          if (assigned)
            _PatrolCard(
              patrolId: a!.patrolId!,
              officer: a.officer,
              vehicle: a.vehicle,
              zone: a.zoneName,
              etaLabel: reached ? 'ON SCENE' : _etaDisplay(a.etaSeconds),
              reached: reached,
              accent: accent,
            )
          else
            _AwaitingCard(),

          const SizedBox(height: AppSpacing.md),

          // ── Incident status chips ────────────────────────────────────
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              RkStatusChip(
                label: reached ? 'PATROL REACHED' : 'PATROL ASSIGNED',
                color: accent,
              ),
              if (a?.sosId.isNotEmpty ?? false)
                RkStatusChip(label: a!.sosId, color: AppColors.textSecondary),
              const RkStatusChip(
                label: 'ENCRYPTION: AES-256',
                color: AppColors.accentBright,
              ),
            ],
          ),

          // ── Live timeline from the backend's own event log ───────────
          if ((a?.events.isNotEmpty ?? false)) ...[
            const SizedBox(height: AppSpacing.md),
            _Timeline(events: a!.events),
          ],

          const SizedBox(height: AppSpacing.xl),

          // ── Stand down ───────────────────────────────────────────────
          RkButton(
            label: 'I AM SAFE — STAND DOWN',
            variant: RkButtonVariant.secondary,
            onPressed: () async {
              await ref.read(sosControllerProvider.notifier).markSecured();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'SOS stood down. Your number has been shared with the assigned patrol in case they need to follow up.',
                  ),
                  duration: Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ── Assigned patrol card ──────────────────────────────────────────────────────

class _PatrolCard extends StatelessWidget {
  final String patrolId;
  final String? officer;
  final String? vehicle;
  final String? zone;
  final String etaLabel;
  final bool reached;
  final Color accent;

  const _PatrolCard({
    required this.patrolId,
    required this.officer,
    required this.vehicle,
    required this.zone,
    required this.etaLabel,
    required this.reached,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border(left: BorderSide(color: accent, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RkPulse(
                color: accent,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              RkLabel.small('PATROL ASSIGNED', color: accent),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      officer ?? patrolId,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        patrolId,
                        if (vehicle != null && vehicle!.isNotEmpty) vehicle,
                        if (zone != null && zone!.isNotEmpty) zone,
                      ].join(' · '),
                      style: AppText.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RkLabel.small(reached ? 'STATUS' : 'ETA',
                      color: AppColors.textSecondary),
                  const SizedBox(height: 2),
                  Text(
                    etaLabel,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Awaiting patrol ───────────────────────────────────────────────────────────

class _AwaitingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: const Border(
          left: BorderSide(color: AppColors.riskMedium, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RkLabel.small('AWAITING PATROL', color: AppColors.riskMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your SOS is logged at the control room. All nearby units are on '
            'other calls — the next one free is assigned automatically.',
            style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Backend event timeline ────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  final List<String> events;
  const _Timeline({required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RkLabel.small('INCIDENT STATUS', color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.sm),
          ...events.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.accentBright, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e,
                        style: AppText.bodyMedium
                            .copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Resolved: "You're Safe" ───────────────────────────────────────────────────

class _SafeScreen extends ConsumerWidget {
  final String lang;
  final SosAssignment? assignment;
  final bool wasCancelled;

  const _SafeScreen({
    required this.lang,
    required this.assignment,
    required this.wasCancelled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = assignment?.patrolId;
    final officer = assignment?.officer;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),

          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.riskLow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: const Icon(Icons.verified_user,
                color: AppColors.riskLow, size: 38),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            lang == 'ta' ? 'நீங்கள் பாதுகாப்பாக இருக்கிறீர்கள்.' : "You're Safe.",
            style: AppText.displayLarge
                .copyWith(fontSize: 44, color: AppColors.riskLow),
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            wasCancelled
                ? 'You stood the alert down. The assigned patrol has been notified.'
                : unit != null
                    ? 'Incident resolved by $unit${officer != null ? ' · $officer' : ''}.'
                    : 'The control room has closed this incident.',
            style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),

          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              const RkStatusChip(label: 'SOS COMPLETED', color: AppColors.riskLow),
              if (assignment?.sosId.isNotEmpty ?? false)
                RkStatusChip(
                    label: assignment!.sosId, color: AppColors.textSecondary),
            ],
          ),

          const Spacer(),

          RkButton(
            label: 'RETURN TO SENTINEL',
            onPressed: () {
              ref.read(sosControllerProvider.notifier).reset();
              context.go('/sentinel');
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ── Error: the SOS never reached the backend ──────────────────────────────────

class _ErrorScreen extends ConsumerWidget {
  final String lang;
  final String? message;

  const _ErrorScreen({required this.lang, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const Icon(Icons.wifi_off, color: AppColors.riskHigh, size: 44),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'SOS not sent.',
            style: AppText.displayLarge
                .copyWith(fontSize: 40, color: AppColors.riskHigh),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message ?? 'Could not reach the control room.',
            style: AppText.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'If you are in danger, call 100 now.',
            style: AppText.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
          const Spacer(),
          RkButton(
            label: 'TRY AGAIN',
            variant: RkButtonVariant.danger,
            onPressed: () =>
                ref.read(sosControllerProvider.notifier).triggerSos(),
          ),
          const SizedBox(height: AppSpacing.sm),
          RkButton(
            label: 'BACK',
            variant: RkButtonVariant.secondary,
            onPressed: () {
              ref.read(sosControllerProvider.notifier).reset();
              context.go('/sentinel');
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
