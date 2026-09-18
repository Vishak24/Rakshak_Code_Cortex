import '../constants/pincode_map.dart';

/// Request payload for POST /predict
class RiskPredictionRequest {
  final double latitude;
  final double longitude;
  final int pincode;
  final int hour;
  final int dayOfWeek;
  final int isWeekend;
  final int isNight;
  final int isEvening;
  final int isRushHour;
  final int reportingDelayMinutes;
  final int responseTimeMinutes;
  final int victimAge;
  final int signalCountLast7d;
  final int signalCountLast30d;
  final double signalDensityRatio;
  final int areaEncoded;
  final int neighborhoodEncoded;

  const RiskPredictionRequest({
    required this.latitude,
    required this.longitude,
    required this.pincode,
    required this.hour,
    required this.dayOfWeek,
    required this.isWeekend,
    required this.isNight,
    required this.isEvening,
    required this.isRushHour,
    this.reportingDelayMinutes = 20,
    this.responseTimeMinutes = 15,
    this.victimAge = 25,
    this.signalCountLast7d = 5,
    this.signalCountLast30d = 20,
    this.signalDensityRatio = 0.25,
    required this.areaEncoded,
    required this.neighborhoodEncoded,
  });

  /// Build from live GPS coordinates + pincode. Time derived from now.
  static RiskPredictionRequest fromGps(
    double lat,
    double lng,
    int pincode,
  ) {
    final now = DateTime.now();
    final hour = now.hour;
    final dow = now.weekday % 7; // 0=Sunday … 6=Saturday
    return RiskPredictionRequest(
      latitude: lat,
      longitude: lng,
      pincode: pincode,
      hour: hour,
      dayOfWeek: dow,
      isWeekend: (dow == 0 || dow == 6) ? 1 : 0,
      isNight: (hour >= 22 || hour <= 5) ? 1 : 0,
      isEvening: (hour >= 17 && hour <= 21) ? 1 : 0,
      isRushHour: [8, 9, 17, 18, 19].contains(hour) ? 1 : 0,
      areaEncoded: pincodeToAreaEncoded[pincode] ?? 0,
      neighborhoodEncoded: pincodeToNeighborhoodEncoded[pincode] ?? 0,
    );
  }

  /// Build for Judge Mode — hour is overridden by the slider.
  /// Uses pincode-specific coordinates when available.
  static RiskPredictionRequest forJudge(
    double lat,
    double lng,
    int pincode,
    int hour,
  ) {
    final now = DateTime.now();
    final dow = now.weekday % 7;
    // Use the pincode's known coordinates if available, else fall back to GPS
    final effectiveLat = pincodeToLat[pincode] ?? lat;
    final effectiveLng = pincodeToLon[pincode] ?? lng;
    return RiskPredictionRequest(
      latitude: effectiveLat,
      longitude: effectiveLng,
      pincode: pincode,
      hour: hour,
      dayOfWeek: dow,
      isWeekend: (dow == 0 || dow == 6) ? 1 : 0,
      isNight: (hour >= 22 || hour <= 5) ? 1 : 0,
      isEvening: (hour >= 17 && hour <= 21) ? 1 : 0,
      isRushHour: [8, 9, 17, 18, 19].contains(hour) ? 1 : 0,
      areaEncoded: pincodeToAreaEncoded[pincode] ?? 0,
      neighborhoodEncoded: pincodeToNeighborhoodEncoded[pincode] ?? 0,
    );
  }

  /// Legacy factory kept for backward compat with existing callers.
  factory RiskPredictionRequest.fromLocation({
    required double latitude,
    required double longitude,
    int pincode = 0,
  }) =>
      fromGps(latitude, longitude, pincode);

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'pincode': pincode,
        'hour': hour,
        'day_of_week': dayOfWeek,
        'is_weekend': isWeekend,
        'is_night': isNight,
        'is_evening': isEvening,
        'is_rush_hour': isRushHour,
        'reporting_delay_minutes': reportingDelayMinutes,
        'response_time_minutes': responseTimeMinutes,
        'victim_age': victimAge,
        'signal_count_last_7d': signalCountLast7d,
        'signal_count_last_30d': signalCountLast30d,
        'signal_density_ratio': signalDensityRatio,
        'area_encoded': areaEncoded,
        'neighborhood_encoded': neighborhoodEncoded,
      };
}
