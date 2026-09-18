import '../../../core/models/risk_score.dart';

/// Sentinel service interface
abstract class SentinelService {
  /// Get current risk score for user's location
  Future<RiskScore> getCurrentRiskScore();

  /// Activate night watch mode
  Future<bool> activateNightWatch();

  /// Deactivate night watch mode
  Future<bool> deactivateNightWatch();

  /// Check if night watch is active
  Future<bool> isNightWatchActive();
}
