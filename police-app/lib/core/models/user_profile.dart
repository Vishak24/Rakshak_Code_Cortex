import 'emergency_contact.dart';

/// User profile model
class UserProfile {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final List<EmergencyContact> emergencyContacts;

  const UserProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.emergencyContacts = const [],
  });

  /// Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      emergencyContacts: (json['emergency_contacts'] as List?)
              ?.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'emergency_contacts': emergencyContacts.map((e) => e.toJson()).toList(),
    };
  }

  /// Copy with
  UserProfile copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    List<EmergencyContact>? emergencyContacts,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }
}
