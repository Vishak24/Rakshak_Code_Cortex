import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api.dart' as api;
import '../models/sos_alert.dart';
import '../models/patrol.dart';

class ApiService {
  static const _timeout = Duration(seconds: 8);

  // ── SOS ──────────────────────────────────────────────────────────────────
  static Future<List<SosAlert>> fetchLiveSos() async {
    try {
      final res = await http
          .get(Uri.parse(api.sosLive))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((e) => SosAlert.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];   // no mock fallback — empty means no live alerts
  }

  static Future<void> dispatchSos(String sosId) async {
    try {
      await http
          .post(Uri.parse('${api.sosDispatch}/$sosId'))
          .timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> resolveSos(String sosId) async {
    try {
      await http
          .patch(Uri.parse('${api.sosResolve}/$sosId'))
          .timeout(_timeout);
    } catch (_) {}
  }

  /// Accept a SOS alert — PATCH /police/sos/{id}/status with status=dispatched
  static Future<bool> acceptSos(String sosId) async {
    try {
      final res = await http
          .patch(
            Uri.parse('${api.policeSosAccept}/$sosId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'status': 'dispatched'}),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Patrols ───────────────────────────────────────────────────────────────
  static Future<List<Patrol>> fetchPatrols() async {
    try {
      final res = await http
          .get(Uri.parse(api.patrolsList))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((e) => Patrol.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Monitor screen — night mode citizens ─────────────────────────────────
  static Future<Map<String, dynamic>> fetchCitizensActive() async {
    try {
      final res = await http
          .get(Uri.parse('${api.citizensActive}?after_hour=22'))
          .timeout(_timeout);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {};
  }

  // ── Route screen — optimised route to SOS ────────────────────────────────
  static Future<Map<String, dynamic>> fetchRoute({
    required double fromLat, required double fromLng,
    required double toLat,   required double toLng,
    required String sosId,
  }) async {
    try {
      final uri = Uri.parse(api.policeRoute).replace(queryParameters: {
        'from_lat': '$fromLat', 'from_lng': '$fromLng',
        'to_lat':   '$toLat',   'to_lng':   '$toLng',
        'sos_id':   sosId,
      });
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {};
  }

  // ── Map screen — live SOS from /police/sos/active ────────────────────────
  static Future<List<SosAlert>> fetchActiveSos({
    double officerLat = 13.0827,
    double officerLng = 80.2707,
  }) async {
    try {
      final uri = Uri.parse(api.sosActive).replace(queryParameters: {
        'officer_lat': '$officerLat',
        'officer_lng': '$officerLng',
      });
      final res = await http.get(uri).timeout(_timeout);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((e) => SosAlert.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];   // no mock fallback
  }

  // ── Live heatmap ──────────────────────────────────────────────────────────
  /// GET /heatmap/live — one scored row per Chennai zone, SageMaker-backed and
  /// adjusted for recent incident density. Returns pincode -> risk level
  /// ("HIGH" | "MEDIUM" | "LOW"), empty when the backend is unreachable.
  static Future<Map<String, String>> fetchZoneRiskLevels() async {
    try {
      final res = await http.get(Uri.parse(api.heatmapLive)).timeout(_timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final rows = body is Map ? body['zones'] : body;
        if (rows is List) {
          return {
            for (final r in rows.whereType<Map>())
              if (r['pincode'] != null)
                r['pincode'].toString():
                    (r['risk_level'] ?? 'LOW').toString().toUpperCase(),
          };
        }
      }
    } catch (_) {}
    return {};
  }

  // ── Patrol Optimizer ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> fetchPatrolOptimizedRoutes({
    required List<Map<String, dynamic>> zones,
    required List<Map<String, dynamic>> patrols,
  }) async {
    final response = await http.post(
      Uri.parse(api.patrolOptimizer),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'zones': zones, 'patrols': patrols}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Patrol optimizer failed: ${response.statusCode}');
  }
}
