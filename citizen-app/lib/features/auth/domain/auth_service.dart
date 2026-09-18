/// Authentication service interface
abstract class AuthService {
  /// Send OTP to phone number
  Future<bool> sendOtp(String phoneNumber);

  /// Verify OTP
  Future<bool> verifyOtp(String phoneNumber, String otp);

  /// Logout
  Future<void> logout();

  /// Check if user is authenticated
  Future<bool> isAuthenticated();
}
