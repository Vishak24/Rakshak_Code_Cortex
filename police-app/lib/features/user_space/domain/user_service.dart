import '../../../core/models/user_profile.dart';
import '../../../core/models/emergency_contact.dart';

/// User service interface
abstract class UserService {
  /// Get user profile
  Future<UserProfile> getUserProfile();

  /// Update user profile
  Future<bool> updateUserProfile(UserProfile profile);

  /// Get emergency contacts
  Future<List<EmergencyContact>> getEmergencyContacts();

  /// Add emergency contact
  Future<bool> addEmergencyContact(EmergencyContact contact);

  /// Remove emergency contact
  Future<bool> removeEmergencyContact(String contactId);
}
