import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak/domain/models/time_context.dart';

void main() {
  group('TimeContext', () {
    test('should correctly calculate night time (20:00-05:59)', () {
      // Night time: 22:00
      final nightTime = DateTime(2024, 1, 15, 22, 30);
      final context = TimeContext.fromDateTime(nightTime);
      
      expect(context.hour, 22);
      expect(context.isNight, 1);
    });

    test('should correctly calculate day time (06:00-19:59)', () {
      // Day time: 14:00
      final dayTime = DateTime(2024, 1, 15, 14, 30);
      final context = TimeContext.fromDateTime(dayTime);
      
      expect(context.hour, 14);
      expect(context.isNight, 0);
    });

    test('should correctly identify weekend (Saturday)', () {
      // Saturday
      final saturday = DateTime(2024, 1, 13, 12, 0); // Jan 13, 2024 is Saturday
      final context = TimeContext.fromDateTime(saturday);
      
      expect(context.dayOfWeek, 6);
      expect(context.isWeekend, 1);
    });

    test('should correctly identify weekday (Monday)', () {
      // Monday
      final monday = DateTime(2024, 1, 15, 12, 0); // Jan 15, 2024 is Monday
      final context = TimeContext.fromDateTime(monday);
      
      expect(context.dayOfWeek, 1);
      expect(context.isWeekend, 0);
    });

    test('should convert to JSON correctly', () {
      final context = TimeContext(
        hour: 14,
        dayOfWeek: 3,
        isNight: 0,
        isWeekend: 0,
      );
      
      final json = context.toJson();
      
      expect(json['hour'], 14);
      expect(json['day_of_week'], 3);
      expect(json['is_night'], 0);
      expect(json['is_weekend'], 0);
    });
  });
}
