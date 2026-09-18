/// Snapshot of time-derived feature flags used by the ML prediction model.
class TimeContext {
  final int hour;
  final int dayOfWeek; // 0 = Sunday … 6 = Saturday
  final int isWeekend; // 1 or 0
  final int isNight;   // 1 if hour >= 20 || hour < 6
  final int isEvening; // 1 if hour >= 17 && hour < 20
  final int isRushHour; // 1 if (8–10) or (17–19)

  const TimeContext({
    required this.hour,
    required this.dayOfWeek,
    required this.isWeekend,
    required this.isNight,
    required this.isEvening,
    required this.isRushHour,
  });

  /// Creates a [TimeContext] from the current wall-clock time.
  factory TimeContext.now() {
    final now = DateTime.now();
    final h   = now.hour;
    final dow = now.weekday % 7; // DateTime.weekday: 1=Mon…7=Sun → 0=Sun…6=Sat
    return TimeContext(
      hour:       h,
      dayOfWeek:  dow,
      isWeekend:  (dow == 0 || dow == 6) ? 1 : 0,
      isNight:    (h >= 20 || h < 6)     ? 1 : 0,
      isEvening:  (h >= 17 && h < 20)    ? 1 : 0,
      isRushHour: ((h >= 8 && h <= 10) || (h >= 17 && h <= 19)) ? 1 : 0,
    );
  }

  /// Creates a [TimeContext] for a specific hour (used by Judge Mode).
  factory TimeContext.forHour(int hour) {
    final now = DateTime.now();
    final dow = now.weekday % 7;
    return TimeContext(
      hour:       hour,
      dayOfWeek:  dow,
      isWeekend:  (dow == 0 || dow == 6) ? 1 : 0,
      isNight:    (hour >= 20 || hour < 6)     ? 1 : 0,
      isEvening:  (hour >= 17 && hour < 20)    ? 1 : 0,
      isRushHour: ((hour >= 8 && hour <= 10) || (hour >= 17 && hour <= 19)) ? 1 : 0,
    );
  }
}
