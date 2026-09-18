import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_endpoints.dart';
import '../../../core/models/risk_prediction_request.dart';
import '../../../core/models/risk_score.dart';
import '../../../core/models/risk_score_response.dart';
import '../domain/sentinel_service.dart';

/// Live implementation of SentinelService — calls POST /predict
class SentinelRepository implements SentinelService {
  bool _nightWatchActive = false;

  // Current location state — set by the controller after GPS acquisition
  double _lat = 13.0827;
  double _lng = 80.2707;
  int _pincode = 0;
  String _areaName = '';

  // ── Getters for location state ──────────────────────────────────────────
  double get latitude => _lat;
  double get longitude => _lng;
  int get pincode => _pincode;
  String get areaName => _areaName;

  /// Update the cached location (called by controller after GPS/geocode)
  void updateLocation({
    required double lat,
    required double lng,
    required int pincode,
    required String areaName,
  }) {
    _lat = lat;
    _lng = lng;
    _pincode = pincode;
    _areaName = areaName;
  }

  /// Call POST /predict with the current location
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
    throw Exception('Prediction failed: ${response.statusCode}');
  }

  @override
  Future<RiskScore> getCurrentRiskScore() async {
    final request = RiskPredictionRequest.fromGps(_lat, _lng, _pincode);
    final apiResponse = await predict(request);
    return apiResponse.toRiskScore(location: '$_pincode · $_areaName');
  }

  @override
  Future<bool> activateNightWatch() async {
    _nightWatchActive = true;
    return true;
  }

  @override
  Future<bool> deactivateNightWatch() async {
    _nightWatchActive = false;
    return true;
  }

  @override
  Future<bool> isNightWatchActive() async {
    return _nightWatchActive;
  }

  Future<String> callGemmaCheckin(String zone, String userInput) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.gemmaCheckin),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_input': userInput,
        'zone': zone,
        'latitude': _lat,
        'longitude': _lng,
      }),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['reasoning'] as String? ?? '';
    }
    throw Exception('Checkin failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> callGemmaEscalate(
      String user, String zone, String reason) async {
    final response = await http.post(
      Uri.parse(ApiEndpoints.gemmaEscalate),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user': user, 'zone': zone, 'reason': reason}),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Escalate failed: ${response.statusCode}');
  }
}
