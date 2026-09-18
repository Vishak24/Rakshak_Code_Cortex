import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/emergency_contact.dart';
import '../data/user_repository.dart';
import '../domain/user_service.dart';

/// User state
class UserState {
  final UserProfile? profile;
  final List<EmergencyContact> contacts;
  final bool isLoading;
  final String? error;

  const UserState({
    this.profile,
    this.contacts = const [],
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    UserProfile? profile,
    List<EmergencyContact>? contacts,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      profile: profile ?? this.profile,
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// User controller
class UserController extends StateNotifier<UserState> {
  final UserService _userService;

  UserController(this._userService) : super(const UserState());

  Future<void> loadUserProfile() async {
    state = state.copyWith(isLoading: true);

    try {
      final profile = await _userService.getUserProfile();
      final contacts = await _userService.getEmergencyContacts();
      state = state.copyWith(
        profile: profile,
        contacts: contacts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> addEmergencyContact(EmergencyContact contact) async {
    try {
      final success = await _userService.addEmergencyContact(contact);
      if (success) {
        state = state.copyWith(
          contacts: [...state.contacts, contact],
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeEmergencyContact(String contactId) async {
    try {
      final success = await _userService.removeEmergencyContact(contactId);
      if (success) {
        state = state.copyWith(
          contacts: state.contacts.where((c) => c.id != contactId).toList(),
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// User service provider
final userServiceProvider = Provider<UserService>((ref) {
  return UserRepository();
});

/// User controller provider
final userControllerProvider =
    StateNotifierProvider<UserController, UserState>((ref) {
  return UserController(ref.watch(userServiceProvider));
});
