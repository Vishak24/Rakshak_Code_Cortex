import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which zones have been marked as patrolled.
/// Key: zoneId, Value: timestamp when it was marked.
class PatrolManagerNotifier
    extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => {};

  /// Marks [zoneId] as patrolled at the current time.
  void markAsPatrolled(String zoneId) {
    state = {...state, zoneId: DateTime.now()};
  }

  /// Clears the patrolled status for [zoneId].
  void clearPatrol(String zoneId) {
    final updated = Map<String, DateTime>.from(state);
    updated.remove(zoneId);
    state = updated;
  }

  /// Clears all patrol records.
  void clearAll() {
    state = {};
  }
}

/// Provider exposed to the widget tree.
/// The widget layer uses `Map<String, dynamic>` via `containsKey` checks,
/// so we expose `Map<String, DateTime>` which satisfies that contract.
final patrolManagerProvider =
    NotifierProvider<PatrolManagerNotifier, Map<String, DateTime>>(
  PatrolManagerNotifier.new,
);
