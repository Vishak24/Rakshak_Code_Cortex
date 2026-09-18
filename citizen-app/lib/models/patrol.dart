class Patrol {
  final String id;
  final String vehicle;
  final String status;
  final String zone;

  const Patrol({
    required this.id,
    required this.vehicle,
    required this.status,
    required this.zone,
  });

  factory Patrol.fromJson(Map<String, dynamic> json) {
    return Patrol(
      id:      json['patrol_id']?.toString() ?? '',
      vehicle: json['vehicle']?.toString() ?? '',
      status:  json['status']?.toString() ?? 'patrolling',
      zone:    json['zone']?.toString() ?? '',
    );
  }
}
