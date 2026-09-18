import '../../../core/constants/stub_data.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/emergency_contact.dart';
import '../domain/user_service.dart';

/// Stub implementation of UserService
class UserRepository implements UserService {
  @override
  Future<UserProfile> getUserProfile() async {
    await Future.delayed(StubData.apiDelay);
    return StubData.defaultUser;
  }

  @override
  Future<bool> updateUserProfile(UserProfile profile) async {
    await Future.delayed(StubData.apiDelay);
    return true;
  }

  @override
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    await Future.delayed(StubData.apiDelay);
    return StubData.emergencyContacts;
  }

  @override
  Future<bool> addEmergencyContact(EmergencyContact contact) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  @override
  Future<bool> removeEmergencyContact(String contactId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }
}
