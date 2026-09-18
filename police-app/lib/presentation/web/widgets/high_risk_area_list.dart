import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/models/zone_risk.dart';
import '../../../domain/providers/heatmap_data_provider.dart';
import '../../../domain/providers/patrol_manager_provider.dart';

class HighRiskAreaList extends ConsumerWidget {
  const HighRiskAreaList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapDataAsync = ref.watch(heatmapDataProvider);
    final patrolRecords = ref.watch(patrolManagerProvider);

    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'High-Risk Areas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref.read(heatmapDataProvider.notifier).refresh();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: heatmapDataAsync.when(
              data: (zones) {
                // Filter high-risk zones
                final highRiskZones = zones.where((z) => z.isHighRisk).toList();

                // Sort by confidence (descending)
                highRiskZones.sort((a, b) =>
                    b.assessment.confidence.compareTo(a.assessment.confidence));

                if (highRiskZones.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: Colors.green),
                        SizedBox(height: 16),
                        Text('No high-risk areas detected'),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: highRiskZones.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final zone = highRiskZones[index];
                    final isPatrolled = patrolRecords.containsKey(zone.zoneId);

                    return HighRiskAreaTile(
                      zone: zone,
                      isPatrolled: isPatrolled,
                      onMarkPatrolled: () {
                        ref
                            .read(patrolManagerProvider.notifier)
                            .markAsPatrolled(zone.zoneId);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HighRiskAreaTile extends StatelessWidget {
  final ZoneRisk zone;
  final bool isPatrolled;
  final VoidCallback onMarkPatrolled;

  const HighRiskAreaTile({
    super.key,
    required this.zone,
    required this.isPatrolled,
    required this.onMarkPatrolled,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: zone.assessment.displayColor.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPatrolled ? Icons.check_circle : Icons.location_on,
          color: isPatrolled ? Colors.green : zone.assessment.displayColor,
        ),
      ),
      title: Text(
        zone.locationName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: zone.assessment.displayColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  zone.assessment.riskLevel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(zone.assessment.confidence * 100).toStringAsFixed(0)}% confidence',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('HH:mm').format(zone.assessment.timestamp),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: isPatrolled
          ? const Chip(
              label: Text('Patrolled', style: TextStyle(fontSize: 12)),
              backgroundColor: Colors.green,
              labelStyle: TextStyle(color: Colors.white),
            )
          : ElevatedButton.icon(
              onPressed: onMarkPatrolled,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Mark Patrolled'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
    );
  }
}
