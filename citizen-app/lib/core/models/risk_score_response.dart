import 'risk_score.dart';

/// DTO for POST /predict and GET /prediction/zone/{pincode}.
///
/// The live SageMaker/XGBoost service returns exactly:
///   {"safetyScore":55,"riskLevel":"MEDIUM","confidence":0.9997,
///    "zone":"T. Nagar","pincode":"600017","source":"sagemaker"}
///
/// `safetyScore` is a SAFETY value — **high means safe** (Guindy 100 = LOW risk,
/// T. Nagar 13 = HIGH risk). It is carried through unchanged and every consumer
/// reads it that way; nothing inverts it.
class RiskScoreResponse {
  /// "LOW" | "MEDIUM" | "HIGH" — the model's own label, never re-derived.
  final String riskLevel;

  /// 0–100, high = safe.
  final int safetyScore;

  /// 0.0–1.0
  final double confidence;

  /// Human-readable zone name, e.g. "T. Nagar".
  final String zone;

  /// Chennai pincode the score was computed for.
  final String pincode;

  /// "sagemaker" | "s3-model" | "baseline" — which tier answered.
  final String source;

  const RiskScoreResponse({
    required this.riskLevel,
    required this.safetyScore,
    required this.confidence,
    required this.zone,
    required this.pincode,
    required this.source,
  });

  bool get isHigh   => riskLevel == 'HIGH';
  bool get isMedium => riskLevel == 'MEDIUM';
  bool get isLow    => riskLevel == 'LOW';

  bool get isNightWatch => DateTime.now().hour >= 22 && isHigh;

  String get screenMode => isNightWatch ? 'night_watch' : 'normal';

  factory RiskScoreResponse.fromJson(Map<String, dynamic> json) {
    // Accept both camelCase (live API) and snake_case (heatmap rows) spellings
    // so one model serves /predict, /prediction/zone and /heatmap/live.
    final rawScore = json['safetyScore'] ?? json['safety_score'];
    final rawLevel = json['riskLevel'] ?? json['risk_level'];
    return RiskScoreResponse(
      riskLevel:   (rawLevel as String?)?.toUpperCase() ?? 'MEDIUM',
      safetyScore: (rawScore as num?)?.round() ?? 50,
      confidence:  (json['confidence'] as num?)?.toDouble() ?? 0.0,
      zone:        json['zone']?.toString() ?? json['zone_name']?.toString() ?? '',
      pincode:     json['pincode']?.toString() ?? '',
      source:      json['source']?.toString() ?? 'model',
    );
  }

  /// Maps to the app's RiskScore domain model.
  RiskScore toRiskScore({String? location}) {
    return RiskScore(
      score: safetyScore,
      level: _parseLevel(riskLevel),
      location: location ?? (zone.isNotEmpty ? '$pincode · $zone' : 'Current Location'),
      timestamp: DateTime.now(),
      zoneName: zone,
      confidence: confidence,
      source: source,
      factors: [
        'confidence ${(confidence * 100).toStringAsFixed(0)}%',
        'model: $source',
      ],
    );
  }

  static RiskLevel _parseLevel(String level) {
    switch (level.toUpperCase()) {
      case 'HIGH':
        return RiskLevel.high;
      case 'MEDIUM':
        return RiskLevel.medium;
      case 'LOW':
      default:
        return RiskLevel.low;
    }
  }
}
