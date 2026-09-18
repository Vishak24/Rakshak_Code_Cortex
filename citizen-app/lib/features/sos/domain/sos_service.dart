/// The live state of the citizen's own SOS, as reported by the backend.
///
/// Every field here is served by the API — the backend recomputes
/// `etaSeconds` on each read from the assigned patrol's live position, so the
/// app never has to run its own countdown or guess a distance.
class SosAssignment {
  final String sosId;

  /// awaiting | dispatched | reached | resolved
  final String status;

  final String? patrolId;
  final String? officer;
  final String? vehicle;
  final int? etaSeconds;
  final String? zoneName;
  final String? pincode;

  /// Timeline event types, oldest first: SOS Created, Patrol Assigned, …
  final List<String> events;

  const SosAssignment({
    required this.sosId,
    required this.status,
    this.patrolId,
    this.officer,
    this.vehicle,
    this.etaSeconds,
    this.zoneName,
    this.pincode,
    this.events = const [],
  });

  bool get isAssigned  => patrolId != null && patrolId!.isNotEmpty;
  bool get isReached   => status == 'reached';
  bool get isResolved  => status == 'resolved';

  static String _normaliseStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'reached':
      case 'on_scene':
      case 'at_scene':
        return 'reached';
      case 'dispatched':
      case 'en_route':
        return 'dispatched';
      case 'resolved':
        return 'resolved';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'awaiting';
    }
  }

  factory SosAssignment.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'];
    return SosAssignment(
      sosId:      json['sos_id']?.toString() ?? '',
      status:     _normaliseStatus(json['status']?.toString()),
      patrolId:   json['assigned_patrol_id']?.toString(),
      officer:    json['assigned_officer']?.toString(),
      vehicle:    json['assigned_vehicle']?.toString(),
      etaSeconds: (json['eta_seconds'] as num?)?.round(),
      zoneName:   json['zone_name']?.toString(),
      pincode:    json['pincode']?.toString(),
      events: rawEvents is List
          ? rawEvents
              .map((e) => (e is Map ? e['type']?.toString() : null) ?? '')
              .where((t) => t.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

/// SOS service interface
abstract class SosService {
  /// Raise an SOS. Returns the backend's assignment (the nearest free patrol is
  /// dispatched inside this same call), or null if the request did not reach
  /// the backend.
  Future<SosAssignment?> triggerSos({int? pincode});

  /// Re-read this citizen's own live incident. Returns null once the incident
  /// leaves the active feed — which is how a resolution is observed.
  Future<SosAssignment?> fetchStatus();

  /// Cancel the active SOS — notifies the backend with the phone number so the
  /// assigned patrol can follow up.
  Future<bool> cancelSos({String? userPhone});

  /// Whether an SOS is currently active in this session.
  Future<bool> isSosActive();
}
