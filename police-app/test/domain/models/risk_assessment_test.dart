import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak/domain/models/risk_assessment.dart';

void main() {
  group('RiskAssessment', () {
    test('should return correct color for Low risk', () {
      final assessment = RiskAssessment(
        riskLevel: 'Low',
        confidence: 0.85,
        probabilities: {'Low': 0.85, 'Medium': 0.10, 'High': 0.05},
        timestamp: DateTime.now(),
      );
      
      expect(assessment.displayColor, const Color(0xFF4CAF50));
    });

    test('should return correct color for Medium risk', () {
      final assessment = RiskAssessment(
        riskLevel: 'Medium',
        confidence: 0.75,
        probabilities: {'Low': 0.15, 'Medium': 0.75, 'High': 0.10},
        timestamp: DateTime.now(),
      );
      
      expect(assessment.displayColor, const Color(0xFFFFC107));
    });

    test('should return correct color for High risk', () {
      final assessment = RiskAssessment(
        riskLevel: 'High',
        confidence: 0.90,
        probabilities: {'Low': 0.05, 'Medium': 0.05, 'High': 0.90},
        timestamp: DateTime.now(),
      );
      
      expect(assessment.displayColor, const Color(0xFFF44336));
    });

    test('should correctly compare risk levels', () {
      final lowRisk = RiskAssessment(
        riskLevel: 'Low',
        confidence: 0.85,
        probabilities: {},
        timestamp: DateTime.now(),
      );
      
      final highRisk = RiskAssessment(
        riskLevel: 'High',
        confidence: 0.90,
        probabilities: {},
        timestamp: DateTime.now(),
      );
      
      expect(highRisk.isHigherRiskThan(lowRisk), true);
      expect(lowRisk.isHigherRiskThan(highRisk), false);
    });

    test('should parse from JSON correctly', () {
      final json = {
        'risk_level': 'High',
        'confidence': 0.92,
        'probabilities': {
          'Low': 0.03,
          'Medium': 0.05,
          'High': 0.92,
        },
      };
      
      final assessment = RiskAssessment.fromJson(json);
      
      expect(assessment.riskLevel, 'High');
      expect(assessment.confidence, 0.92);
      expect(assessment.probabilities['High'], 0.92);
    });
  });
}
