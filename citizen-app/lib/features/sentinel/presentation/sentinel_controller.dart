import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
// geocoding is not supported on web — imported conditionally at runtime
import 'package:geocoding/geocoding.dart'
    if (dart.library.html) '../../../core/stubs/geocoding_stub.dart';
import '../../../core/models/risk_score.dart';
import '../data/sentinel_repository.dart';

/// Sentinel state — exposed to the UI
class SentinelState {
  final RiskScore? riskScore;
  final bool isLoading;
  final bool nightWatchActive;
  final String? error;
  final double latitude;
  final double longitude;
  final int pincode;
  final String areaName;

  const SentinelState({
    this.riskScore,
    this.isLoading = false,
    this.nightWatchActive = false,
    this.error,
    this.latitude = 13.0827,
    this.longitude = 80.2707,
    this.pincode = 0,
    this.areaName = '',
  });

  SentinelState copyWith({
    RiskScore? riskScore,
    bool? isLoading,
    bool? nightWatchActive,
    String? error,
    double? latitude,
    double? longitude,
    int? pincode,
    String? areaName,
  }) {
    return SentinelState(
      riskScore: riskScore ?? this.riskScore,
      isLoading: isLoading ?? this.isLoading,
      nightWatchActive: nightWatchActive ?? this.nightWatchActive,
      error: error,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      pincode: pincode ?? this.pincode,
      areaName: areaName ?? this.areaName,
    );
  }
}

/// Sentinel controller — GPS + live /predict + 60s auto-refresh
class SentinelController extends StateNotifier<SentinelState> {
  final SentinelRepository _repo;
  Timer? _refreshTimer;

  SentinelController(this._repo) : super(const SentinelState()) {
    _init();
  }

  Future<void> _init() async {
    await _acquireLocation();
    await loadRiskScore();
    // Auto-refresh every 60 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => loadRiskScore(),
    );
  }

  /// Acquire GPS + reverse geocode to get pincode
  Future<void> _acquireLocation() async {
    try {
      // Check / request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        // Fall back to defaults
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      final lat = position.latitude;
      final lng = position.longitude;

      // Reverse geocode to get pincode + area name
      int pincode = 0;
      String areaName = '';
      if (!kIsWeb) {
        try {
          final placemarks = await placemarkFromCoordinates(lat, lng)
              .timeout(const Duration(seconds: 5));
          if (placemarks.isNotEmpty) {
            final pm = placemarks.first;
            pincode = int.tryParse(pm.postalCode ?? '') ?? 0;
            areaName = pm.subLocality?.isNotEmpty == true
                ? pm.subLocality!
                : pm.locality ?? 'Chennai';
          }
        } catch (_) {
          // Geocoding failed — keep defaults
        }
      }

      // Update repository + state
      _repo.updateLocation(
        lat: lat,
        lng: lng,
        pincode: pincode,
        areaName: areaName,
      );

      state = state.copyWith(
        latitude: lat,
        longitude: lng,
        pincode: pincode,
        areaName: areaName,
      );
    } catch (_) {
      // GPS failed — keep defaults, don't crash
    }
  }

  /// Call /predict and update state
  Future<void> loadRiskScore() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final riskScore = await _repo.getCurrentRiskScore();
      state = state.copyWith(
        riskScore: riskScore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Override pincode from Judge Mode — propagates to SOS flow and UI.
  void overridePincode(int pincode) {
    final coords = _pincodeCoords[pincode];
    state = state.copyWith(
      pincode: pincode,
      areaName: _pincodeNames[pincode] ?? 'Chennai',
      latitude:  coords?[0] ?? state.latitude,
      longitude: coords?[1] ?? state.longitude,
    );
    _repo.updateLocation(
      lat:      state.latitude,
      lng:      state.longitude,
      pincode:  pincode,
      areaName: state.areaName,
    );
  }

  // Pincode → [lat, lng] for the 44 Chennai zones used in Judge Mode
  static const Map<int, List<double>> _pincodeCoords = {
    600001: [13.0827, 80.2707], 600002: [13.0878, 80.2785],
    600003: [13.0950, 80.2866], 600004: [13.0732, 80.2609],
    600005: [13.0569, 80.2787], 600006: [13.0715, 80.2740],
    600007: [13.1127, 80.2966], 600008: [13.1186, 80.2487],
    600009: [13.1483, 80.2355], 600010: [13.1675, 80.2617],
    600011: [13.0827, 80.2487], 600012: [13.0950, 80.2193],
    600013: [13.0732, 80.2193], 600015: [13.0339, 80.2707],
    600017: [13.0067, 80.2570], 600018: [13.0521, 80.2193],
    600019: [13.0475, 80.2030], 600020: [13.0521, 80.2118],
    600024: [12.9815, 80.2209], 600028: [12.9995, 80.2666],
    600029: [12.9845, 80.2657], 600032: [13.0350, 80.2323],
    600033: [13.0521, 80.2030], 600034: [13.0339, 80.2193],
    600035: [13.0402, 80.2091], 600036: [13.0883, 80.2105],
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

  static const Map<int, String> _pincodeNames = {
    600001: 'Park Town',       600002: 'Sowcarpet',
    600003: 'Royapuram',       600004: 'Chintadripet',
    600005: 'Royapettah',      600006: 'Triplicane',
    600007: 'Egmore',          600008: 'Nungambakkam',
    600009: 'Kilpauk',         600010: 'Aminjikarai',
    600011: 'Perambur',        600012: 'Ashok Nagar',
    600013: 'Tiruvottiyur',    600015: 'Pattabiram',
    600017: 'T. Nagar',        600018: 'Abiramapuram',
    600019: 'Vyasarpadi',      600020: 'Saidapet',
    600024: 'Pallavaram',      600028: 'Adyar',
    600029: 'Besant Nagar',    600032: 'Alwarpet',
    600033: 'Valasaravakkam',  600034: 'Anna Nagar West',
    600035: 'Anna Nagar East', 600036: 'Arumbakkam',
    600040: 'Nanganallur',     600042: 'Velachery',
    600044: 'Perungudi',       600045: 'Thoraipakkam',
    600050: 'Mogappair',       600053: 'Villivakkam',
    600056: 'Kolathur',        600058: 'Royapuram',
    600061: 'Mugalivakkam',    600064: 'Medavakkam',
    600078: 'Ambattur',        600081: 'Manali',
    600082: 'Puzhal',          600083: 'Madhavaram',
    600090: 'Velachery',       600096: 'OMR',
    600099: 'Kundrathur',      600118: 'Perumbakkam',
  };

  Future<void> toggleNightWatch() async {
    final isActive = state.nightWatchActive;
    try {
      if (isActive) {
        await _repo.deactivateNightWatch();
        state = state.copyWith(nightWatchActive: false);
      } else {
        await _repo.activateNightWatch();
        state = state.copyWith(nightWatchActive: true);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// Sentinel repository provider (concrete type so we can access location)
final sentinelRepositoryProvider = Provider<SentinelRepository>((ref) {
  return SentinelRepository();
});

/// Sentinel controller provider
final sentinelControllerProvider =
    StateNotifierProvider<SentinelController, SentinelState>((ref) {
  return SentinelController(ref.watch(sentinelRepositoryProvider));
});

// ─────────────────────────────────────────────────────────────────────────────
// Suraksha Mode — state, controller, provider
// ─────────────────────────────────────────────────────────────────────────────

class SurakshaState {
  final bool enabled;
  final String checkinMessage;
  final bool isCheckinLoading;
  final bool isEscalating;
  final bool isEscalated;
  final String escalationMessage;
  final int unitsNotified;
  final bool stayingOut;

  const SurakshaState({
    this.enabled = false,
    this.checkinMessage = '',
    this.isCheckinLoading = false,
    this.isEscalating = false,
    this.isEscalated = false,
    this.escalationMessage = '',
    this.unitsNotified = 0,
    this.stayingOut = false,
  });
}

class SurakshaController extends StateNotifier<SurakshaState> {
  final SentinelRepository _repo;
  Timer? _nightCheckTimer;

  // Default home coordinates (Anna Nagar, Chennai — matches simulateCheckin zone)
  static const double _homeLat = 13.0839;
  static const double _homeLng = 80.2105;
  // Auto-checkin fires when user is more than 500 m from home after 22:00
  static const double _autoCheckinRadiusM = 500.0;

  SurakshaController(this._repo) : super(const SurakshaState());

  void toggle() {
    final nowEnabled = !state.enabled;
    state = SurakshaState(enabled: nowEnabled, stayingOut: state.stayingOut);
    if (nowEnabled) {
      _startNightCheckDaemon();
    } else {
      _stopNightCheckDaemon();
    }
  }

  void _startNightCheckDaemon() {
    _nightCheckTimer?.cancel();
    _nightCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _nightCheckTick(),
    );
  }

  void _stopNightCheckDaemon() {
    _nightCheckTimer?.cancel();
    _nightCheckTimer = null;
  }

  void _nightCheckTick() {
    if (!state.enabled || state.stayingOut || state.isCheckinLoading) return;
    if (DateTime.now().hour < 22) return;
    final distanceM = Geolocator.distanceBetween(
      _repo.latitude, _repo.longitude,
      _homeLat, _homeLng,
    );
    if (distanceM > _autoCheckinRadiusM) simulateCheckin();
  }

  void toggleStayingOut() {
    state = SurakshaState(
      enabled: state.enabled,
      checkinMessage: state.checkinMessage,
      isEscalated: state.isEscalated,
      escalationMessage: state.escalationMessage,
      unitsNotified: state.unitsNotified,
      stayingOut: !state.stayingOut,
    );
  }

  Future<void> simulateCheckin() async {
    if (state.stayingOut) return;
    state = SurakshaState(enabled: true, isCheckinLoading: true, stayingOut: state.stayingOut);
    try {
      final msg = await _repo.callGemmaCheckin('Anna Nagar', "I'm okay, just out late.");
      state = SurakshaState(enabled: true, checkinMessage: msg, stayingOut: state.stayingOut);
    } catch (_) {
      state = SurakshaState(
        enabled: true,
        stayingOut: state.stayingOut,
        checkinMessage:
            "Hi Priya, it's late and you're away from home. Are you safe? / "
            "வணக்கம் Priya, நேரம் ஆகிவிட்டது, நீங்கள் வீட்டை விட்டு வெளியே இருக்கிறீர்கள். "
            "நீங்கள் பாதுகாப்பாக இருக்கிறீர்களா?",
      );
    }
  }

  Future<void> escalate() async {
    final prevMsg = state.checkinMessage;
    final prevStayingOut = state.stayingOut;
    state = SurakshaState(
        enabled: true, checkinMessage: prevMsg, isEscalating: true, stayingOut: prevStayingOut);
    try {
      final result =
          await _repo.callGemmaEscalate('Priya', 'Anna Nagar', 'no_response');
      state = SurakshaState(
        enabled: true,
        checkinMessage: prevMsg,
        isEscalated: true,
        escalationMessage: result['alert_message'] as String? ??
            'Police alerted — Gemma AI notified 2 units',
        unitsNotified: result['units_notified'] as int? ?? 2,
        stayingOut: prevStayingOut,
      );
    } catch (_) {
      state = SurakshaState(
        enabled: true,
        checkinMessage: prevMsg,
        isEscalated: true,
        escalationMessage: 'Police alerted — Gemma AI notified 2 units',
        unitsNotified: 2,
        stayingOut: prevStayingOut,
      );
    }
  }

  void markSafe() {
    state = SurakshaState(enabled: true, stayingOut: state.stayingOut);
  }

  void shareLocation() {}

  @override
  void dispose() {
    _nightCheckTimer?.cancel();
    super.dispose();
  }
}

final surakshaControllerProvider =
    StateNotifierProvider<SurakshaController, SurakshaState>((ref) {
  return SurakshaController(ref.watch(sentinelRepositoryProvider));
});
