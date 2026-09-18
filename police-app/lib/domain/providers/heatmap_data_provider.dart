import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/zone_risk.dart';

/// Stub heatmap data — replace with real API calls when backend is ready.
final _stubZones = <ZoneRisk>[
  ZoneRisk(
    zoneId: '600001',
    locationName: "Park Town",
    latitude: 13.0827,
    longitude: 80.2707,
    assessment: RiskAssessment(
      riskLevel: 'Critical',
      confidence: 0.91,
      timestamp: DateTime.now(),
    ),
  ),
  ZoneRisk(
    zoneId: '600003',
    locationName: "Royapuram",
    latitude: 13.0732,
    longitude: 80.2609,
    assessment: RiskAssessment(
      riskLevel: 'High',
      confidence: 0.78,
      timestamp: DateTime.now(),
    ),
  ),
  ZoneRisk(
    zoneId: '600017',
    locationName: "T.Nagar",
    latitude: 13.0418,
    longitude: 80.2341,
    assessment: RiskAssessment(
      riskLevel: 'High',
      confidence: 0.82,
      timestamp: DateTime.now(),
    ),
  ),
  ZoneRisk(
    zoneId: '600011',
    locationName: "Perambur",
    latitude: 13.1143,
    longitude: 80.2329,
    assessment: RiskAssessment(
      riskLevel: 'Medium',
      confidence: 0.65,
      timestamp: DateTime.now(),
    ),
  ),
  ZoneRisk(
    zoneId: '600040',
    locationName: "Nanganallur",
    latitude: 13.0850,
    longitude: 80.2101,
    assessment: RiskAssessment(
      riskLevel: 'Medium',
      confidence: 0.58,
      timestamp: DateTime.now(),
    ),
  ),
  ZoneRisk(
    zoneId: '600020',
    locationName: "Saidapet",
    latitude: 13.0012,
    longitude: 80.2565,
    assessment: RiskAssessment(
      riskLevel: 'Low',
      confidence: 0.44,
      timestamp: DateTime.now(),
    ),
  ),
];

/// Notifier that holds the async list of [ZoneRisk] objects.
class HeatmapDataNotifier
    extends AsyncNotifier<List<ZoneRisk>> {
  DateTime? _lastUpdate;

  /// The timestamp of the most recent successful data load.
  DateTime? get lastUpdate => _lastUpdate;

  @override
  Future<List<ZoneRisk>> build() async {
    return _fetch();
  }

  Future<List<ZoneRisk>> _fetch() async {
    // TODO: replace with real API call to the predict endpoint
    await Future.delayed(const Duration(milliseconds: 600));
    _lastUpdate = DateTime.now();
    return _stubZones;
  }

  /// Triggers a manual refresh of the heatmap data.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// Provider exposed to the widget tree.
final heatmapDataProvider =
    AsyncNotifierProvider<HeatmapDataNotifier, List<ZoneRisk>>(
  HeatmapDataNotifier.new,
);
