/// A patrol unit as returned by GET /patrols.
///
/// The backend computes `position` on every read from the unit's route and
/// elapsed time, so these rows move without any client-side simulation.
class Patrol {
  final String id;
  final String name;
  final String officer;
  final String vehicle;
  final String status;
  final String zone;
  final String zoneName;

  /// Live position — null only if the backend omitted it.
  final double? lat;
  final double? lng;

  /// Seconds to the assigned incident while Responding; null otherwise.
  final int? etaSeconds;

  /// The SOS this unit is currently diverted to, if any.
  final String? assignedSosId;

  const Patrol({
    required this.id,
    required this.vehicle,
    required this.status,
    required this.zone,
    this.name = '',
    this.officer = '',
    this.zoneName = '',
    this.lat,
    this.lng,
    this.etaSeconds,
    this.assignedSosId,
  });

  bool get hasPosition => lat != null && lng != null;

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory Patrol.fromJson(Map<String, dynamic> json) {
    final pos = json['position'] as Map?;
    return Patrol(
      id:            json['patrol_id']?.toString() ?? '',
      name:          json['name']?.toString() ?? '',
      officer:       json['officer']?.toString() ?? '',
      vehicle:       json['vehicle']?.toString() ?? '',
      status:        json['status']?.toString() ?? 'Patrolling',
      zone:          json['zone']?.toString() ?? '',
      zoneName:      json['zone_name']?.toString() ?? '',
      lat:           _toDouble(pos?['lat']),
      lng:           _toDouble(pos?['lng']),
      etaSeconds:    _toInt(json['eta_seconds']),
      assignedSosId: json['assigned_sos_id']?.toString(),
    );
  }
}
