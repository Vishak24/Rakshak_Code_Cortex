import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sos_repository.dart';
import '../domain/sos_service.dart';
import '../../../core/widgets/judge_mode_overlay.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../sentinel/presentation/sentinel_controller.dart';

/// SOS lifecycle as the citizen sees it.
enum SosStatus {
  idle,
  triggering,
  active,     // raised; patrol assigned or awaiting
  resolved,   // patrol closed the incident — "You're Safe"
  cancelled,  // citizen stood down
  error,      // the SOS did not reach the backend
}

class SosState {
  final SosStatus status;
  final SosAssignment? assignment;
  final String? error;

  const SosState({
    this.status = SosStatus.idle,
    this.assignment,
    this.error,
  });

  SosState copyWith({
    SosStatus? status,
    SosAssignment? assignment,
    String? error,
    bool clearAssignment = false,
  }) {
    return SosState(
      status: status ?? this.status,
      assignment: clearAssignment ? null : (assignment ?? this.assignment),
      error: error,
    );
  }
}

/// Drives the citizen SOS screen.
///
/// After the SOS is raised the controller polls `GET /sos/live?user_id=` every
/// 2s. The backend recomputes ETA from the assigned patrol's live position on
/// every read, so the countdown on screen is the real remaining time, not a
/// local timer. When the incident leaves the active feed the patrol has
/// resolved it — that transition is what shows the "You're Safe" screen.
class SosController extends StateNotifier<SosState> {
  final SosService _sosService;
  final Ref _ref;
  Timer? _pollTimer;

  static const _pollInterval = Duration(seconds: 2);

  SosController(this._sosService, this._ref) : super(const SosState());

  Future<void> triggerSos() async {
    state = state.copyWith(status: SosStatus.triggering);

    // Judge-mode pincode wins; otherwise use the sentinel's GPS-derived zone.
    final judgePin = _ref.read(judgePincodeProvider);
    int? pincode = judgePin;
    if (pincode == null) {
      final sentinelPin = _ref.read(sentinelControllerProvider).pincode;
      if (sentinelPin > 0) pincode = sentinelPin;
    }

    final assignment = await _sosService.triggerSos(pincode: pincode);

    if (assignment == null) {
      state = const SosState(
        status: SosStatus.error,
        error: 'Could not reach the control room. Check your connection.',
      );
      return;
    }

    state = SosState(status: SosStatus.active, assignment: assignment);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  /// Consecutive polls that came back with an empty active feed. Standing the
  /// citizen down is irreversible on this screen, so it takes two in a row:
  /// the very first poll can land before the new incident is readable.
  int _emptyPolls = 0;

  Future<void> _refresh() async {
    if (state.status != SosStatus.active) return;

    final SosAssignment? live;
    try {
      live = await _sosService.fetchStatus();
    } catch (_) {
      // Request failed — that is not evidence the incident is over.
      // Skip this tick and keep polling.
      return;
    }

    if (live == null) {
      // Gone from the active feed → the patrol resolved it.
      if (++_emptyPolls < 2) return;
      _pollTimer?.cancel();
      state = state.copyWith(status: SosStatus.resolved);
      return;
    }
    _emptyPolls = 0;

    if (live.isResolved) {
      _pollTimer?.cancel();
      state = SosState(status: SosStatus.resolved, assignment: live);
      return;
    }

    state = SosState(status: SosStatus.active, assignment: live);
  }

  Future<void> markSecured() async {
    _pollTimer?.cancel();
    try {
      final phone = _ref.read(authControllerProvider).phoneNumber;
      await _sosService.cancelSos(userPhone: phone);
      state = state.copyWith(status: SosStatus.cancelled);
    } catch (e) {
      state = state.copyWith(status: SosStatus.error, error: e.toString());
    }
  }

  void reset() {
    _pollTimer?.cancel();
    state = const SosState();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

/// SOS service provider
final sosServiceProvider = Provider<SosService>((ref) {
  return SosRepository();
});

/// SOS controller provider
final sosControllerProvider =
    StateNotifierProvider<SosController, SosState>((ref) {
  return SosController(ref.watch(sosServiceProvider), ref);
});
