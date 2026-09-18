import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../config/api.dart' as api;
import '../../../core/constants/stub_data.dart';
import '../domain/sos_service.dart';

/// Live SOS repository — POSTs to /sos/live with real GPS, falls back gracefully.
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

  @override
  Future<bool> triggerSos({int? pincode}) async {
    // Get GPS — null if unavailable (never blocks SOS)
    final coords = await _getLocation();

    try {
      final body = <String, dynamic>{
        'lat':       coords?.lat,   // null if location unavailable
        'lng':       coords?.lng,
        'latitude':  coords?.lat,   // also send legacy field names for backend compat
        'longitude': coords?.lng,
        'risk_level': 'HIGH',
        'status':     'active',
        'timestamp':  DateTime.now().toIso8601String(),
      };

      // Include pincode (from Judge Mode or sentinel GPS-derived value)
      if (pincode != null) {
        body['pincode']    = pincode.toString();
        body['zone_name']  = pincode.toString(); // backend sets zone_name = pincode
        _activePincode     = pincode.toString();
      }

      final res = await http
          .post(
            Uri.parse(api.sosLive),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 || res.statusCode == 201) {
        _sosActive = true;
        try {
          final resp = jsonDecode(res.body) as Map<String, dynamic>;
          _activeSosId = resp['sos_id']?.toString();
        } catch (_) {}
        return true;
      }
    } catch (_) {}

    // Fallback: mark active locally so the UI proceeds even if network fails
    _sosActive = true;
    return true;
  }

  @override
  Future<bool> cancelSos({String? userPhone}) async {
    if (_activeSosId != null) {
      try {
        await http
            .patch(Uri.parse('${api.sosResolve}/$_activeSosId'))
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    // Notify backend — patrol can follow up via phone
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

    _sosActive = false;
    _activeSosId = null;
    _activePincode = null;
    return true;
  }

  @override
  Future<Map<String, dynamic>> getSosStatus() async {
    return _sosActive ? StubData.sosActive : StubData.sosSecured;
  }

  @override
  Future<bool> isSosActive() async => _sosActive;
}
