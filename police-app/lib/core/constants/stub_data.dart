import '../models/risk_score.dart';
import '../models/user_profile.dart';
import '../models/emergency_contact.dart';

/// Stub data for development and testing
class StubData {
  StubData._();

  // Stub delay for simulating API calls
  static const Duration apiDelay = Duration(milliseconds: 800);

  // Stub Risk Scores
  static final RiskScore lowRisk = RiskScore(
    score: 25,
    level: RiskLevel.low,
    location: 'T. Nagar, Chennai',
    timestamp: DateTime.now(),
    factors: ['Well-lit area', 'High foot traffic', 'Police presence'],
  );

  static final RiskScore mediumRisk = RiskScore(
    score: 55,
    level: RiskLevel.medium,
    location: 'Adyar, Chennai',
    timestamp: DateTime.now(),
    factors: ['Moderate lighting', 'Some activity', 'Residential area'],
  );

  static final RiskScore highRisk = RiskScore(
    score: 78,
    level: RiskLevel.high,
    location: 'Isolated Street, Chennai',
    timestamp: DateTime.now(),
    factors: ['Poor lighting', 'Low activity', 'No surveillance'],
  );

  static final RiskScore criticalRisk = RiskScore(
    score: 92,
    level: RiskLevel.critical,
    location: 'Dark Alley, Chennai',
    timestamp: DateTime.now(),
    factors: ['No lighting', 'Deserted', 'High crime history'],
  );

  // Stub User Profile
  static final UserProfile defaultUser = UserProfile(
    id: 'user_001',
    name: 'Priya Kumar',
    phone: '+91 98765 43210',
    email: 'priya.kumar@example.com',
    emergencyContacts: [
      EmergencyContact(
        id: 'contact_001',
        name: 'Raj Kumar (Father)',
        phone: '+91 98765 43211',
        relationship: 'Father',
      ),
      EmergencyContact(
        id: 'contact_002',
        name: 'Lakshmi Kumar (Mother)',
        phone: '+91 98765 43212',
        relationship: 'Mother',
      ),
      EmergencyContact(
        id: 'contact_003',
        name: 'Arun Kumar (Brother)',
        phone: '+91 98765 43213',
        relationship: 'Brother',
      ),
    ],
  );

  // Stub Emergency Contacts
  static final List<EmergencyContact> emergencyContacts = [
    EmergencyContact(
      id: 'contact_001',
      name: 'Raj Kumar (Father)',
      phone: '+91 98765 43211',
      relationship: 'Father',
    ),
    EmergencyContact(
      id: 'contact_002',
      name: 'Lakshmi Kumar (Mother)',
      phone: '+91 98765 43212',
      relationship: 'Mother',
    ),
    EmergencyContact(
      id: 'contact_003',
      name: 'Arun Kumar (Brother)',
      phone: '+91 98765 43213',
      relationship: 'Brother',
    ),
  ];

  // Stub SOS Status
  static const Map<String, dynamic> sosActive = {
    'status': 'active',
    'timestamp': '2024-01-15T20:30:00Z',
    'location': 'T. Nagar, Chennai',
    'contacts_notified': 3,
  };

  static const Map<String, dynamic> sosSecured = {
    'status': 'secured',
    'timestamp': '2024-01-15T20:35:00Z',
    'location': 'T. Nagar, Chennai',
    'response_time': '5 minutes',
  };
}
