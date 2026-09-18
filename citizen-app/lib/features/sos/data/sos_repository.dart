import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../config/api.dart' as api;
import '../domain/sos_service.dart';

/// Stable id for this citizen. `GET /sos/live?user_id=` is scoped by it, which
/// is how the app reads back its own incident (and only its own).
const String kCitizenUserId = 'citizen-demo';
const String kCitizenName   = 'Priya';

/// Fallback coordinates used only when GPS is unavailable (web, denied
/// permission, timeout). Without lat/lng the backend cannot pick a nearest
/// patrol, so the demo would show "Awaiting Patrol" forever.
const double _kChennaiLat = 13.0827;
const double _kChennaiLng = 80.2707;

/// Live SOS repository — talks to POST/GET /sos/live on the AWS backend.
class SosRepository implements SosService {
  bool _sosActive = false;
  String? _activeSosId;
  String? _activePincode;

  /// Try to get GPS coordinates within 5 seconds.
  /// Returns null if permission denied, timed out, or on web.
  /// Never throws — SOS must never be blocked by location failure.
  Future<({double lat, double lng})?> _getLocation() async {
    if (kIsWeb) return null; // Geolocator GPS not reliable on web

    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));

      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return null; // timeout or any error — proceed without coordinates
    }
  }

  /// Pincode → approximate centre, so a Judge-Mode pincode still produces a
  /// dispatchable location when GPS is unavailable.
  static const Map<int, List<double>> _pincodeCoords = {
    600001: [13.0827, 80.2707], 600002: [13.0878, 80.2785],
    600003: [13.0950, 80.2866], 600004: [13.0339, 80.2619],
    600005: [13.0569, 80.2787], 600006: [13.0715, 80.2740],
    600007: [13.1127, 80.2966], 600008: [13.1186, 80.2487],
    600009: [13.1483, 80.2355], 600010: [13.1675, 80.2617],
    600011: [13.0827, 80.2487], 600012: [13.0950, 80.2193],
    600013: [13.0732, 80.2193], 600015: [13.0339, 80.2707],
    600017: [13.0418, 80.2341], 600018: [13.0521, 80.2193],
    600019: [13.0475, 80.2030], 600020: [13.0521, 80.2118],
    600024: [12.9815, 80.2209], 600028: [12.9995, 80.2666],
    600029: [12.9845, 80.2657], 600032: [13.0100, 80.2100],
    600033: [13.0521, 80.2030], 600034: [13.0339, 80.2193],
    600035: [13.0330, 80.2470], 600036: [13.0100, 80.2350],
    600040: [13.0850, 80.2101], 600042: [13.0883, 80.1762],
    600044: [13.0339, 80.1575], 600045: [13.0237, 80.1762],
    600050: [12.9673, 80.1501], 600053: [12.9515, 80.1438],
    600056: [12.9625, 80.2387], 600058: [13.1127, 80.2966],
    600061: [12.9000, 80.2277], 600064: [12.9240, 80.1958],
    600078: [13.1144, 80.1606], 600081: [13.1675, 80.2617],
    600082: [13.1675, 80.2355], 600083: [13.1483, 80.2355],
    600090: [12.9815, 80.2209], 600096: [12.9625, 80.2387],
    600099: [13.1186, 80.2091], 600118: [12.9065, 80.1958],
  };

  @override
  Future<SosAssignment?> triggerSos({int? pincode}) async {
    final coords = await _getLocation();

    // Resolve a usable location: real GPS → the selected pincode's centre →
    // Chennai centre. The backend needs coordinates to dispatch a unit.
    double lat = coords?.lat ?? _kChennaiLat;
    double lng = coords?.lng ?? _kChennaiLng;
    if (coords == null && pincode != null && _pincodeCoords.containsKey(pincode)) {
      lat = _pincodeCoords[pincode]![0];
      lng = _pincodeCoords[pincode]![1];
    }

    try {
      final body = <String, dynamic>{
        'user_id':   kCitizenUserId,
        'username':  kCitizenName,
        'lat':       lat,
        'lng':       lng,
        'latitude':  lat,   // legacy field names, for backend compatibility
        'longitude': lng,
        'risk_level': 'HIGH',
        'status':     'active',
        'timestamp':  DateTime.now().toIso8601String(),
      };

      if (pincode != null) {
        body['pincode']   = pincode.toString();
        body['zone_name'] = pincode.toString();
        _activePincode    = pincode.toString();
      }

      final res = await http
          .post(
            Uri.parse(api.sosLive),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final resp = jsonDecode(res.body) as Map<String, dynamic>;
        // POST already returns the auto-dispatch result: assigned patrol,
        // officer and ETA. Keep all of it instead of discarding it.
        final assignment = SosAssignment.fromJson(resp);
        _sosActive   = true;
        _activeSosId = assignment.sosId.isNotEmpty ? assignment.sosId : null;
        return assignment;
      }
    } catch (_) {
      // fall through — reported honestly below
    }

    // The SOS did not reach the backend. Report that rather than showing a
    // fake "patrol dispatched" state the control room knows nothing about.
    return null;
  }

  /// Polls this citizen's own incident.
  ///
  /// Returns the assignment while the incident is live, and null ONLY when the
  /// backend genuinely reports no open incident — i.e. it was resolved. A
  /// network failure throws instead, because null is what tells the UI to say
  /// "You're Safe": one dropped request on venue wifi must never stand the
  /// citizen down while a patrol is still en route.
  @override
  Future<SosAssignment?> fetchStatus() async {
    final uri = Uri.parse('${api.sosLive}?user_id=$kCitizenUserId');
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('sos/live returned ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    if (data is! List) {
      throw const FormatException('sos/live did not return a list');
    }
    if (data.isEmpty) return null; // genuinely resolved

    // Prefer the incident we raised; otherwise take the newest one.
    final rows = data.cast<Map<String, dynamic>>();
    final match = _activeSosId == null
        ? rows.first
        : rows.firstWhere(
            (r) => r['sos_id']?.toString() == _activeSosId,
            orElse: () => rows.first,
          );
    return SosAssignment.fromJson(match);
  }

  @override
  Future<bool> cancelSos({String? userPhone}) async {
    var ok = false;
    if (_activeSosId != null) {
      try {
        final res = await http
            .patch(Uri.parse('${api.sosResolve}/$_activeSosId'))
            .timeout(const Duration(seconds: 8));
        ok = res.statusCode == 200;
      } catch (_) {}

      // Share the phone number so the assigned patrol can follow up.
      try {
        await http
            .post(
              Uri.parse(api.sosCancelled),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'sos_id':     _activeSosId ?? '',
                'user_phone': userPhone ?? '',
                'pincode':    _activePincode ?? '',
                'reason':     'User cancelled',
                'timestamp':  DateTime.now().toIso8601String(),
              }),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    _sosActive = false;
    _activeSosId = null;
    _activePincode = null;
    return ok;
  }

  @override
  Future<bool> isSosActive() async => _sosActive;
}
