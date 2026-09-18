import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../domain/models/zone_risk.dart';
import '../../../domain/providers/heatmap_data_provider.dart';
import '../../../domain/providers/patrol_manager_provider.dart';
import '../../../shared/constants.dart';

class PoliceHeatmapWidget extends ConsumerWidget {
  const PoliceHeatmapWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heatmapDataAsync = ref.watch(heatmapDataProvider);
    final patrolRecords = ref.watch(patrolManagerProvider);

    return heatmapDataAsync.when(
      data: (zones) => _HeatmapMap(zones: zones, patrolRecords: patrolRecords),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading heatmap: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(heatmapDataProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapMap extends StatelessWidget {
  final List<ZoneRisk> zones;
  final Map<String, DateTime> patrolRecords;

  const _HeatmapMap({required this.zones, required this.patrolRecords});

  List<CircleMarker> _buildCircles() {
    return zones.map((zone) {
      double weight;
      switch (zone.assessment.riskLevel) {
        case 'High':
          weight = RiskConstants.highWeight;
          break;
        case 'Medium':
          weight = RiskConstants.mediumWeight;
          break;
        case 'Low':
          weight = RiskConstants.lowWeight;
          break;
        default:
          weight = 0.1;
      }

      return CircleMarker(
        point: LatLng(zone.latitude, zone.longitude),
        radius: MapConstants.heatmapRadius,
        useRadiusInMeter: true,
        color: zone.assessment.displayColor
            .withValues(alpha: MapConstants.heatmapOpacity * weight),
        borderColor: zone.assessment.displayColor,
        borderStrokeWidth: 1.0,
      );
    }).toList();
  }

  List<Marker> _buildMarkers() {
    return zones.where((z) => z.isHighRisk).map((zone) {
      final isPatrolled = patrolRecords.containsKey(zone.zoneId);
      return Marker(
        point: LatLng(zone.latitude, zone.longitude),
        width: 36,
        height: 36,
        child: Tooltip(
          message:
              '${zone.assessment.riskLevel} — ${(zone.assessment.confidence * 100).toStringAsFixed(0)}% confidence',
          child: Icon(
            Icons.location_on,
            color: isPatrolled ? Colors.green : Colors.red,
            size: 32,
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: const MapOptions(
        initialCenter:
            LatLng(MapConstants.chennaiLat, MapConstants.chennaiLng),
        initialZoom: MapConstants.defaultZoom,
        minZoom: 9.0,
        maxZoom: 16.0,
        backgroundColor: Color(0xFF0d1117),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png',
          userAgentPackageName: 'com.rakshak.app',
        ),
        CircleLayer(circles: _buildCircles()),
        MarkerLayer(markers: _buildMarkers()),
      ],
    );
  }
}
