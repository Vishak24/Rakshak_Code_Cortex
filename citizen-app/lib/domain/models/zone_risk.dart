import 'package:flutter/material.dart';

/// Risk assessment for a single geographic zone.
class RiskAssessment {
  /// Human-readable risk level: 'Low', 'Medium', 'High', 'Critical'.
  final String riskLevel;

  /// Confidence score in the range [0.0, 1.0].
  final double confidence;

  /// When this assessment was computed.
  final DateTime timestamp;

  const RiskAssessment({
    required this.riskLevel,
    required this.confidence,
    required this.timestamp,
  });

  /// Colour used for map circles and list tiles.
  Color get displayColor {
    switch (riskLevel) {
      case 'Critical':
        return Colors.red;
      case 'High':
        return Colors.orange;
      case 'Medium':
        return Colors.yellow;
      default:
        return Colors.green;
    }
  }

  factory RiskAssessment.fromJson(Map<String, dynamic> json) {
    return RiskAssessment(
      riskLevel:  json['risk_level'] as String? ?? 'Low',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      timestamp:  json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

/// A geographic zone with its current risk assessment.
class ZoneRisk {
  /// Unique identifier for this zone (e.g. pincode string or area slug).
  final String zoneId;

  /// Human-readable location name shown in the list.
  final String locationName;

  final double latitude;
  final double longitude;

  final RiskAssessment assessment;

  const ZoneRisk({
    required this.zoneId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.assessment,
  });

  /// Returns true when the risk level is 'High' or 'Critical'.
  bool get isHighRisk =>
      assessment.riskLevel == 'High' || assessment.riskLevel == 'Critical';

  factory ZoneRisk.fromJson(Map<String, dynamic> json) {
    return ZoneRisk(
      zoneId:       json['zone_id'] as String,
      locationName: json['location_name'] as String,
      latitude:     (json['latitude'] as num).toDouble(),
      longitude:    (json['longitude'] as num).toDouble(),
      assessment:   RiskAssessment.fromJson(
          json['assessment'] as Map<String, dynamic>),
    );
  }
}
