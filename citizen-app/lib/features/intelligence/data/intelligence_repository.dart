import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_endpoints.dart';
import '../../../core/models/risk_prediction_request.dart';
import '../../../core/models/risk_score.dart';
import '../../../core/models/risk_score_response.dart';
import '../domain/intelligence_service.dart';

class IntelligenceRepository implements IntelligenceService {
  /// Call POST /predict with a fully-built request
  Future<RiskScoreResponse> predict(RiskPredictionRequest request) async {
    final response = await http
        .post(
          Uri.parse(ApiEndpoints.predict),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(request.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return RiskScoreResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw HttpException('Prediction failed (${response.statusCode})');
  }

  @override
  Future<RiskScore> scanLocation(double latitude, double longitude) async {
    final request = RiskPredictionRequest.fromGps(
      latitude,
      longitude,
      0, // GPS-derived lookup; no hardcoded default
    );

    final apiResponse = await predict(request);
    return apiResponse.toRiskScore();
  }

  /// Scan with explicit pincode (used by Judge Mode and sentinel-aware flows)
  Future<RiskScore> scanLocationWithPincode(
    double latitude,
    double longitude,
    int pincode,
  ) async {
    final request = RiskPredictionRequest.fromGps(latitude, longitude, pincode);
    final apiResponse = await predict(request);
    return apiResponse.toRiskScore();
  }

  /// Scan with a fully custom request (Judge Mode hour override)
  Future<RiskScore> scanWithRequest(RiskPredictionRequest request) async {
    final apiResponse = await predict(request);
    return apiResponse.toRiskScore();
  }

  @override
  Future<List<RiskScore>> getRiskHistory() async {
    return const [];
  }
}
