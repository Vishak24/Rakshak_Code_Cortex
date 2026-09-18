import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Risk level enumeration
enum RiskLevel {
  low,
  medium,
  high,
  critical,
}

/// Safety assessment for the user's current zone.
///
/// **`score` is a SAFETY score: 0–100 where HIGH MEANS SAFE.** It is the
/// `safetyScore` returned by the live XGBoost model on SageMaker, passed
/// through unchanged. Anything that colours or labels it must treat a *low*
/// number as dangerous — see [color] and [safetyLabel].
class RiskScore {
  /// 0–100 safety score from the ML model. Higher = safer.
  final int score;

  /// The model's own risk label, not derived from [score].
  final RiskLevel level;

  final String location;
  final DateTime timestamp;
  final List<String> factors;

  /// Human-readable zone name from the model response, e.g. "T. Nagar".
  final String zoneName;

  /// Model confidence, 0.0–1.0.
  final double confidence;

  /// Which inference tier answered: "sagemaker" | "s3-model" | "baseline".
  final String source;

  const RiskScore({
    required this.score,
    required this.level,
    required this.location,
    required this.timestamp,
    required this.factors,
    this.zoneName = '',
    this.confidence = 0.0,
    this.source = 'model',
  });

  /// Colour for the safety score — low score = danger red, high score = green.
  Color get color {
    switch (level) {
      case RiskLevel.low:
        return AppColors.riskLow;
      case RiskLevel.medium:
        return AppColors.riskMedium;
      case RiskLevel.high:
        return AppColors.riskHigh;
      case RiskLevel.critical:
        return AppColors.riskCritical;
    }
  }

  /// Short status word shown under the score. Driven by the model's label so it
  /// can never contradict the risk level displayed beside it.
  String get safetyLabel {
    switch (level) {
      case RiskLevel.low:
        return 'SAFE';
      case RiskLevel.medium:
        return 'CAUTION';
      case RiskLevel.high:
      case RiskLevel.critical:
        return 'HIGH RISK';
    }
  }

  /// Get label based on risk level
  String get label {
    switch (level) {
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.medium:
        return 'Medium Risk';
      case RiskLevel.high:
        return 'High Risk';
      case RiskLevel.critical:
        return 'Critical Risk';
    }
  }

  /// Get label in Tamil
  String get labelTa {
    switch (level) {
      case RiskLevel.low:
        return 'குறைந்த ஆபத்து';
      case RiskLevel.medium:
        return 'நடுத்தர ஆபத்து';
      case RiskLevel.high:
        return 'அதிக ஆபத்து';
      case RiskLevel.critical:
        return 'முக்கியமான ஆபத்து';
    }
  }

  /// Create from JSON
  factory RiskScore.fromJson(Map<String, dynamic> json) {
    return RiskScore(
      score: (json['score'] as num).toInt(),
      level: RiskLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => RiskLevel.low,
      ),
      location: json['location'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      factors: List<String>.from(json['factors'] as List),
      zoneName: json['zone_name'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] as String? ?? 'model',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'level': level.name,
      'location': location,
      'timestamp': timestamp.toIso8601String(),
      'factors': factors,
      'zone_name': zoneName,
      'confidence': confidence,
      'source': source,
    };
  }

  /// Copy with
  RiskScore copyWith({
    int? score,
    RiskLevel? level,
    String? location,
    DateTime? timestamp,
    List<String>? factors,
    String? zoneName,
    double? confidence,
    String? source,
  }) {
    return RiskScore(
      score: score ?? this.score,
      level: level ?? this.level,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      factors: factors ?? this.factors,
      zoneName: zoneName ?? this.zoneName,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
    );
  }
}
