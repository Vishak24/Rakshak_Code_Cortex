import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Risk level enumeration
enum RiskLevel {
  low,
  medium,
  high,
  critical,
}

/// Risk score model
class RiskScore {
  final int score; // 0-100
  final RiskLevel level;
  final String location;
  final DateTime timestamp;
  final List<String> factors;

  const RiskScore({
    required this.score,
    required this.level,
    required this.location,
    required this.timestamp,
    required this.factors,
  });

  /// Get color based on risk level
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
      score: json['score'] as int,
      level: RiskLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => RiskLevel.low,
      ),
      location: json['location'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      factors: List<String>.from(json['factors'] as List),
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
    };
  }

  /// Copy with
  RiskScore copyWith({
    int? score,
    RiskLevel? level,
    String? location,
    DateTime? timestamp,
    List<String>? factors,
  }) {
    return RiskScore(
      score: score ?? this.score,
      level: level ?? this.level,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      factors: factors ?? this.factors,
    );
  }
}
