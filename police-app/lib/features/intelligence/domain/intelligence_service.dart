import '../../../core/models/risk_score.dart';

/// Intelligence service interface
abstract class IntelligenceService {
  /// Scan location for risk assessment
  Future<RiskScore> scanLocation(double latitude, double longitude);

  /// Get risk history
  Future<List<RiskScore>> getRiskHistory();
}
