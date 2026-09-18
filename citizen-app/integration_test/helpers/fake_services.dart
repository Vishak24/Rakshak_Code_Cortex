import 'package:rakshak/core/models/risk_score.dart';
import 'package:rakshak/features/sentinel/domain/sentinel_service.dart';

class FakeSentinelService implements SentinelService {
  final RiskScore _score;
  const FakeSentinelService(this._score);

  @override
  Future<RiskScore> getCurrentRiskScore() async => _score;

  @override
  Future<bool> activateNightWatch() async => true;

  @override
  Future<bool> deactivateNightWatch() async => true;

  @override
  Future<bool> isNightWatchActive() async => false;
}

class ThrowingSentinelService implements SentinelService {
  const ThrowingSentinelService();

  @override
  Future<RiskScore> getCurrentRiskScore() async =>
      throw Exception('Network error: connection refused');

  @override
  Future<bool> activateNightWatch() async => false;

  @override
  Future<bool> deactivateNightWatch() async => false;

  @override
  Future<bool> isNightWatchActive() async => false;
}
