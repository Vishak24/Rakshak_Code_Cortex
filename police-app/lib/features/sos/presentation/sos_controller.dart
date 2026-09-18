import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/sos_repository.dart';
import '../domain/sos_service.dart';
import '../../../core/widgets/judge_mode_overlay.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../sentinel/presentation/sentinel_controller.dart';

/// SOS state
enum SosStatus {
  idle,
  triggering,
  active,
  secured,
  error,
}

class SosState {
  final SosStatus status;
  final String? error;
  final Map<String, dynamic>? statusData;

  const SosState({
    this.status = SosStatus.idle,
    this.error,
    this.statusData,
  });

  SosState copyWith({
    SosStatus? status,
    String? error,
    Map<String, dynamic>? statusData,
  }) {
    return SosState(
      status: status ?? this.status,
      error: error,
      statusData: statusData ?? this.statusData,
    );
  }
}

/// SOS controller
class SosController extends StateNotifier<SosState> {
  final SosService _sosService;
  final Ref _ref;

  SosController(this._sosService, this._ref) : super(const SosState());

  Future<void> triggerSos() async {
    state = state.copyWith(status: SosStatus.triggering);

    // Judge mode pincode takes priority; fall back to sentinel GPS-derived pincode
    final judgePin = _ref.read(judgePincodeProvider);
    int? pincode = judgePin;
    if (pincode == null) {
      final sentinelPin = _ref.read(sentinelControllerProvider).pincode;
      if (sentinelPin > 0) pincode = sentinelPin;
    }

    try {
      final success = await _sosService.triggerSos(pincode: pincode);
      if (success) {
        final statusData = await _sosService.getSosStatus();
        state = state.copyWith(
          status: SosStatus.active,
          statusData: statusData,
        );
      } else {
        state = state.copyWith(
          status: SosStatus.error,
          error: 'Failed to trigger SOS',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: SosStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> markSecured() async {
    try {
      final phone = _ref.read(authControllerProvider).phoneNumber;
      await _sosService.cancelSos(userPhone: phone);
      state = state.copyWith(status: SosStatus.secured);
    } catch (e) {
      state = state.copyWith(
        status: SosStatus.error,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const SosState();
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
