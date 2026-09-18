import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/providers/heatmap_data_provider.dart';
import '../widgets/police_heatmap_widget.dart';
import '../widgets/high_risk_area_list.dart';
import '../widgets/live_clock_widget.dart';

class PoliceDashboardScreen extends ConsumerWidget {
  const PoliceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapNotifier = ref.read(heatmapDataProvider.notifier);
    final lastUpdate = heatmapNotifier.lastUpdate;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rakshak Police Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (lastUpdate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Last updated: ${DateFormat('HH:mm:ss').format(lastUpdate)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(heatmapDataProvider.notifier).refresh();
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 900;

          if (isWideScreen) {
            // Desktop layout: side-by-side
            return Row(
              children: [
                // Left panel: Clock and High-Risk List
                SizedBox(
                  width: 400,
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: LiveClockWidget(),
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: HighRiskAreaList(),
                        ),
                      ),
                    ],
                  ),
                ),
                // Right panel: Heatmap
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Card(
                      elevation: 4,
                      child: PoliceHeatmapWidget(),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Mobile/Tablet layout: stacked
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LiveClockWidget(),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Card(
                      elevation: 4,
                      child: const PoliceHeatmapWidget(),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: HighRiskAreaList(),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
