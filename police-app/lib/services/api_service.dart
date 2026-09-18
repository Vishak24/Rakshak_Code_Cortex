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

  /// PATCH /police/sos/{id}/status — the one lifecycle write the app makes.
  ///
  /// Returns true only on a 200 from the backend. Failures are surfaced to the
  /// officer rather than swallowed: reporting "Reached" when the control room
  /// never received it is worse than showing an error.
  static Future<bool> _setSosStatus(
    String sosId,
    String status, {
    String? officerId,
  }) async {
    try {
      final res = await http
          .patch(
            Uri.parse('${api.policeSosAccept}/$sosId/status'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'status': status,
              if (officerId != null && officerId.isNotEmpty)
                'officer_id': officerId,
            }),
          )
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Officer is on scene — flips the patrol to AtScene and adds the "Reached"
  /// event to the incident timeline the dashboard renders.
  static Future<bool> markReached(String sosId, {String? patrolId}) =>
      _setSosStatus(sosId, 'reached', officerId: patrolId);

  /// Incident closed — releases the patrol back to its route.
  static Future<bool> markResolved(String sosId, {String? patrolId}) =>
      _setSosStatus(sosId, 'resolved', officerId: patrolId);

  /// Legacy alias kept for callers that only need "close this alert".
  static Future<bool> resolveSos(String sosId, {String? patrolId}) =>
      markResolved(sosId, patrolId: patrolId);

  /// Accept a SOS alert — PATCH /police/sos/{id}/status with status=dispatched.
  /// Dispatch is automatic now, so this is only used to re-affirm assignment.
  static Future<bool> acceptSos(String sosId, {String? patrolId}) =>
      _setSosStatus(sosId, 'dispatched', officerId: patrolId);

  // ── Patrols ───────────────────────────────────────────────────────────────
  /// Returns null when the request failed, an empty list only when the backend
  /// genuinely reported no units. The caller must not read a failure as "no
  /// patrols" — that would blank the map on a single dropped packet.
  static Future<List<Patrol>?> fetchPatrols() async {
    try {
      final res = await http
          .get(Uri.parse(api.patrolsList))
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((e) => Patrol.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return null;
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
  /// Returns null when the request failed, an empty list only when the backend
  /// genuinely reported no active incidents. The distinction matters: reading a
  /// dropped request as "no incidents" would clear the officer's assignment
  /// card mid-response and flash a false "resolved" banner.
  static Future<List<SosAlert>?> fetchActiveSos({
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
    return null;   // no mock fallback — null means "ask again", not "none"
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
