import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/risk_score.dart';
import '../../../core/models/risk_prediction_request.dart';
import '../data/intelligence_repository.dart';

/// Intelligence state
enum ScanStatus {
  idle,
  scanning,
  complete,
  error,
}

class IntelligenceState {
  final ScanStatus status;
  final RiskScore? result;
  final String? error;
  final double progress; // 0.0 to 1.0

  const IntelligenceState({
    this.status = ScanStatus.idle,
    this.result,
    this.error,
    this.progress = 0.0,
  });

  IntelligenceState copyWith({
    ScanStatus? status,
    RiskScore? result,
    String? error,
    double? progress,
  }) {
    return IntelligenceState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

/// Intelligence controller
class IntelligenceController extends StateNotifier<IntelligenceState> {
  final IntelligenceRepository _repo;

  IntelligenceController(this._repo) : super(const IntelligenceState());

  /// Standard scan — uses GPS lat/lon + default pincode
  Future<void> scanLocation(double latitude, double longitude,
      {String lang = 'en', int pincode = 0}) async {
    state = state.copyWith(status: ScanStatus.scanning, progress: 0.0);

    try {
      // Animate progress while awaiting the real HTTP call
      var progressTimer = 0.0;
      final ticker =
          Stream.periodic(const Duration(milliseconds: 300), (i) => i)
              .take(9)
              .listen((_) {
        progressTimer = (progressTimer + 0.1).clamp(0.0, 0.9);
        state = state.copyWith(progress: progressTimer);
      });

      final result =
          await _repo.scanLocationWithPincode(latitude, longitude, pincode);
      await ticker.cancel();

      state = state.copyWith(
        status: ScanStatus.complete,
        result: result,
        progress: 1.0,
      );
    } on TimeoutException {
      state = state.copyWith(
        status: ScanStatus.error,
        error: AppStrings.get(AppStrings.timeoutError, lang),
      );
    } on SocketException {
      state = state.copyWith(
        status: ScanStatus.error,
        error: AppStrings.get(AppStrings.networkError, lang),
      );
    } on HttpException {
      state = state.copyWith(
        status: ScanStatus.error,
        error: AppStrings.get(AppStrings.serverError, lang),
      );
    } catch (e) {
      state = state.copyWith(
        status: ScanStatus.error,
        error: AppStrings.get(AppStrings.networkError, lang),
      );
    }
  }

  /// Judge Mode scan — uses a fully custom request with hour override
  Future<void> scanWithRequest(RiskPredictionRequest request,
      {String lang = 'en'}) async {
    state = state.copyWith(status: ScanStatus.scanning, progress: 0.0);

    try {
      var progressTimer = 0.0;
      final ticker =
          Stream.periodic(const Duration(milliseconds: 300), (i) => i)
              .take(9)
              .listen((_) {
        progressTimer = (progressTimer + 0.1).clamp(0.0, 0.9);
        state = state.copyWith(progress: progressTimer);
      });

      final result = await _repo.scanWithRequest(request);
      await ticker.cancel();

      state = state.copyWith(
        status: ScanStatus.complete,
        result: result,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        status: ScanStatus.error,
        error: AppStrings.get(AppStrings.networkError, lang),
      );
    }
  }

  void reset() {
    state = const IntelligenceState();
  }
}

/// Intelligence repository provider (concrete type)
final intelligenceRepositoryProvider = Provider<IntelligenceRepository>((ref) {
  return IntelligenceRepository();
});

/// Intelligence controller provider
final intelligenceControllerProvider =
    StateNotifierProvider<IntelligenceController, IntelligenceState>((ref) {
  return IntelligenceController(ref.watch(intelligenceRepositoryProvider));
});
