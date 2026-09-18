import 'risk_score.dart';

/// DTO for POST /predict response
class RiskScoreResponse {
  final String riskLevel;       // "Low" | "Medium" | "High"
  final int riskIndex;          // 0–100
  final double confidence;      // 0.0–1.0
  final Map<String, double> probabilities;

  const RiskScoreResponse({
    required this.riskLevel,
    required this.riskIndex,
    required this.confidence,
    required this.probabilities,
  });

  bool get isHigh   => riskLevel == 'High';
  bool get isMedium => riskLevel == 'Medium';
  bool get isLow    => riskLevel == 'Low';

  bool get isNightWatch =>
      DateTime.now().hour >= 22 && riskLevel == 'High';

  String get screenMode =>
      isNightWatch ? 'night_watch' : 'normal';

  factory RiskScoreResponse.fromJson(Map<String, dynamic> json) =>
      RiskScoreResponse(
        riskLevel: json['risk_level'] as String,
        riskIndex: (json['risk_index'] as num).toInt(),
        confidence: (json['confidence'] as num).toDouble(),
        probabilities: Map<String, double>.from(
          (json['probabilities'] as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toDouble()),
          ),
        ),
      );

  /// Maps to the app's RiskScore domain model
  RiskScore toRiskScore({String location = 'Current Location'}) {
    return RiskScore(
      score: riskIndex,
      level: _parseLevel(riskLevel),
      location: location,
      timestamp: DateTime.now(),
      factors: [
        'confidence: ${(confidence * 100).toStringAsFixed(0)}%',
        ...probabilities.entries.map(
          (e) => '${e.key}: ${(e.value * 100).toStringAsFixed(0)}%',
        ),
      ],
    );
  }

  static RiskLevel _parseLevel(String level) {
    switch (level) {
      case 'High':
        return RiskLevel.high;
      case 'Medium':
        return RiskLevel.medium;
      case 'Low':
      default:
        return RiskLevel.low;
    }
  }
}
