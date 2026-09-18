import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/models/time_context.dart';
import '../../../shared/constants.dart';

class LiveClockWidget extends StatefulWidget {
  const LiveClockWidget({super.key});

  @override
  State<LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<LiveClockWidget> {
  Timer? _timer;
  TimeContext _currentTime = TimeContext.now();

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(
      TimingConstants.clockUpdateInterval,
      (_) {
        setState(() {
          _currentTime = TimeContext.now();
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayName = DateFormat('EEEE').format(now);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Current Time Context',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Time display
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(now),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dayName,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Indicators
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _currentTime.isNight == 1
                              ? Icons.nightlight_round
                              : Icons.wb_sunny,
                          size: 20,
                          color: _currentTime.isNight == 1
                              ? Colors.indigo
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentTime.isNight == 1 ? 'Night' : 'Day',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _currentTime.isWeekend == 1
                              ? Icons.weekend
                              : Icons.work_outline,
                          size: 20,
                          color: _currentTime.isWeekend == 1
                              ? Colors.green
                              : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentTime.isWeekend == 1 ? 'Weekend' : 'Weekday',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // Parameters
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildParameter('Hour', _currentTime.hour.toString()),
                _buildParameter('Day', _currentTime.dayOfWeek.toString()),
                _buildParameter('Night', _currentTime.isNight.toString()),
                _buildParameter('Weekend', _currentTime.isWeekend.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameter(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
