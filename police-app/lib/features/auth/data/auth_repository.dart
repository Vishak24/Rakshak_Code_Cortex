import '../domain/auth_service.dart';

/// Stub implementation of AuthService
class AuthRepository implements AuthService {
  @override
  Future<bool> sendOtp(String phoneNumber) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));
    // Always succeed for stub
    return true;
  }

  @override
  Future<bool> verifyOtp(String phoneNumber, String otp) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));
    // Accept any 6-digit OTP for stub
    return otp.length == 6;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<bool> isAuthenticated() async {
    // For stub, always return false (user needs to login)
    return false;
  }
}
