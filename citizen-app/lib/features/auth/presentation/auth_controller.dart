import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/auth_service.dart';

/// Auth state
enum AuthStatus {
  initial,
  sendingOtp,
  otpSent,
  verifying,
  authenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final String? error;
  final String? phoneNumber;

  const AuthState({
    this.status = AuthStatus.initial,
    this.error,
    this.phoneNumber,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? error,
    String? phoneNumber,
  }) {
    return AuthState(
      status: status ?? this.status,
      error: error,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}

/// Auth controller
class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthController(this._authService) : super(const AuthState());

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(
      status: AuthStatus.sendingOtp,
      phoneNumber: phoneNumber,
    );

    try {
      final success = await _authService.sendOtp(phoneNumber);
      if (success) {
        state = state.copyWith(status: AuthStatus.otpSent);
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          error: 'Failed to send OTP',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> verifyOtp(String otp) async {
    if (state.phoneNumber == null) return;

    state = state.copyWith(status: AuthStatus.verifying);

    try {
      final success = await _authService.verifyOtp(state.phoneNumber!, otp);
      if (success) {
        state = state.copyWith(status: AuthStatus.authenticated);
      } else {
        state = state.copyWith(
          status: AuthStatus.error,
          error: 'Invalid OTP',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const AuthState();
  }
}

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthRepository();
});

/// Auth controller provider
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});
