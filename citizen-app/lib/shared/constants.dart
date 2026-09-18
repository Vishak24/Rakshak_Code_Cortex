/// Timing constants used across the web dashboard.
class TimingConstants {
  TimingConstants._();

  /// How often the live clock widget refreshes.
  static const Duration clockUpdateInterval = Duration(seconds: 1);

  /// How often the heatmap data auto-refreshes.
  static const Duration heatmapRefreshInterval = Duration(minutes: 5);
}

/// Map constants for the Chennai heatmap.
class MapConstants {
  MapConstants._();

  static const double chennaiLat  = 13.0827;
  static const double chennaiLng  = 80.2707;
  static const double defaultZoom = 11.0;

  /// Radius in metres for each heatmap circle.
  static const double heatmapRadius  = 500.0;

  /// Base opacity multiplied by the risk weight.
  static const double heatmapOpacity = 0.6;
}

/// Risk weight constants used when rendering heatmap circles.
class RiskConstants {
  RiskConstants._();

  static const double highWeight   = 1.0;
  static const double mediumWeight = 0.6;
  static const double lowWeight    = 0.3;
}
