import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import '../models/sos_alert.dart';
import '../models/zone.dart';
import '../services/api_service.dart';
import '../utils/kml_parser.dart';

class OptimisedRouteScreen extends StatefulWidget {
  final LatLng officerPos;
  final List<SosAlert> alerts;

  const OptimisedRouteScreen({
    super.key,
    required this.officerPos,
    required this.alerts,
  });

  @override
  State<OptimisedRouteScreen> createState() => _OptimisedRouteScreenState();
}

class _OptimisedRouteScreenState extends State<OptimisedRouteScreen> {
  static const _bg      = Color(0xFF0d1117);
  static const _surface = Color(0xFF161b22);
  static const _border  = Color(0xFF30363d);
  static const _teal    = Color(0xFF00d4b4);
  static const _textPri = Color(0xFFf0f6fc);
  static const _textMut = Color(0xFF8b949e);

  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _stops = [];
  bool _loading = true;
  String _totalDist = '—';
  String _eta = '—';
  late Future<List<Polygon>> _kmlZonesFuture;

  // Backend route data
  String? _backendArea;
  double? _backendDistKm;
  int?    _backendEtaMins;
  String? _backendMapsUrl;

  // Patrol optimizer data
  List<Map<String, dynamic>> _deploymentZones = [];
  bool _optimizerLoading = false;

  @override
  void initState() {
    super.initState();
    _kmlZonesFuture = loadKmlZones();
    _buildRoute();
    _fetchBackendRoute();
    _fetchPatrolOptimizer();
  }

  Future<void> _fetchPatrolOptimizer() async {
    setState(() => _optimizerLoading = true);

    // Build zone payload from high/medium risk zones
    final zones = Zone.chennaiZones
        .where((z) => z.riskLevel == 'HIGH' || z.riskLevel == 'MEDIUM')
        .map((z) => {
              'pincode': z.pincode,
              'name': z.name,
              'lat': z.lat,
              'lng': z.lng,
              'risk_level': z.riskLevel,
            })
        .toList();

    // Build patrol payload from current alerts as proxy for active patrols
    final patrols = widget.alerts
        .where((a) => a.lat != null && a.lng != null)
        .map((a) => {
              'id': a.id,
              'lat': a.lat,
              'lng': a.lng,
              'status': a.status,
            })
        .toList();

    try {
      final data = await ApiService.fetchPatrolOptimizedRoutes(
        zones: zones,
        patrols: patrols,
      );

      // Response may contain deployment_zones, suggested_zones, zones, or assignments
      final raw = data['deployment_zones']
          ?? data['suggested_zones']
          ?? data['zones']
          ?? data['assignments']
          ?? [];

      if (mounted && raw is List) {
        setState(() {
          _deploymentZones = raw
              .whereType<Map<String, dynamic>>()
              .toList();
        });
      }
    } catch (_) {
      // Optimizer endpoint not yet live — fail silently
    } finally {
      if (mounted) setState(() => _optimizerLoading = false);
    }
  }

  Future<void> _fetchBackendRoute() async {
    final primary = widget.alerts.firstWhere(
      (a) => a.lat != null && a.lng != null,
      orElse: () => SosAlert(id: '', zoneName: '', riskLevel: '', timestamp: DateTime.now(), status: ''),
    );
    if (primary.lat == null) return;

    final sosId = primary.sosId ?? primary.id;
    if (sosId.isEmpty) return;

    final data = await ApiService.fetchRoute(
      fromLat: widget.officerPos.latitude,
      fromLng: widget.officerPos.longitude,
      toLat:   primary.lat!,
      toLng:   primary.lng!,
      sosId:   sosId,
    );

    if (mounted && data.isNotEmpty) {
      setState(() {
        _backendArea    = data['destination_area']?.toString();
        _backendDistKm  = (data['distance_km'] as num?)?.toDouble();
        _backendEtaMins = (data['eta_minutes'] as num?)?.toInt();
        _backendMapsUrl = data['google_maps_url']?.toString();
      });
    }
  }

  List<LatLng> _greedyOrder(LatLng start, List<LatLng> targets) {
    final remaining = List<LatLng>.from(targets);
    final ordered = <LatLng>[];
    var current = start;
    while (remaining.isNotEmpty) {
      remaining.sort((a, b) {
        final da = _dist(current, a);
        final db = _dist(current, b);
        return da.compareTo(db);
      });
      ordered.add(remaining.removeAt(0));
      current = ordered.last;
    }
    return ordered;
  }

  double _dist(LatLng a, LatLng b) {
    final dlat = a.latitude - b.latitude;
    final dlng = a.longitude - b.longitude;
    return dlat * dlat + dlng * dlng;
  }

  Future<void> _buildRoute() async {
    // Collect waypoints: SOS alerts + top 3 high-risk zones
    final alertPoints = widget.alerts
        .where((a) => a.lat != null && a.lng != null)
        .map((a) => LatLng(a.lat!, a.lng!))
        .toList();

    final highRiskZones = Zone.chennaiZones
        .where((z) => z.riskLevel == 'HIGH')
        .take(3)
        .map((z) => LatLng(z.lat, z.lng))
        .toList();

    final allTargets = [...alertPoints, ...highRiskZones];
    if (allTargets.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final ordered = _greedyOrder(widget.officerPos, allTargets);

    // Build stops list
    final stops = <Map<String, dynamic>>[];
    for (int i = 0; i < ordered.length; i++) {
      final pt = ordered[i];
      // Find matching alert or zone
      final alert = widget.alerts.firstWhere(
        (a) => a.lat != null && (a.lat! - pt.latitude).abs() < 0.001,
        orElse: () => SosAlert(id: '', zoneName: '', riskLevel: '', timestamp: DateTime.now(), status: ''),
      );
      final zone = Zone.chennaiZones.firstWhere(
        (z) => (z.lat - pt.latitude).abs() < 0.001,
        orElse: () => const Zone(pincode: '', name: 'Unknown', riskLevel: 'LOW', lat: 0, lng: 0),
      );
      final name = alert.zoneName.isNotEmpty ? alert.zoneName : zone.name;
      final risk = alert.riskLevel.isNotEmpty ? alert.riskLevel : zone.riskLevel;
      stops.add({'name': name, 'risk': risk, 'eta': '${(i + 1) * 4} min', 'point': pt});
    }

    // Fetch OSRM route
    final allPoints = [widget.officerPos, ...ordered];
    final coords = allPoints.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url = 'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson';

    List<LatLng> routePoints = allPoints;
    double totalKm = 0;

    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        routePoints = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        final distM = (data['routes'][0]['distance'] as num).toDouble();
        final durS  = (data['routes'][0]['duration'] as num).toDouble();
        totalKm = distM / 1000;
        final eta = DateTime.now().add(Duration(seconds: durS.toInt()));
        _eta = '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _routePoints = routePoints;
        _stops = stops;
        _totalDist = totalKm > 0 ? '${totalKm.toStringAsFixed(1)} KM' : '${(stops.length * 1.8).toStringAsFixed(1)} KM';
        if (_eta == '—') {
          final eta = DateTime.now().add(Duration(minutes: stops.length * 5));
          _eta = '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
        }
        _loading = false;
      });
    }
  }

  Color _riskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'HIGH':   return const Color(0xFFef4444);
      case 'MEDIUM': return const Color(0xFFf59e0b);
      default:       return const Color(0xFF22c55e);
    }
  }

  Future<void> _startNavigation() async {
    if (_backendMapsUrl != null && _backendMapsUrl!.isNotEmpty) {
      try {
        await launchUrl(Uri.parse(_backendMapsUrl!), mode: LaunchMode.externalApplication);
        return;
      } catch (_) {}
    }
    if (_stops.isEmpty) return;
    final waypoints = _stops
        .map((s) => (s['point'] as LatLng))
        .map((p) => '${p.latitude},${p.longitude}')
        .join('|');
    final dest = _stops.last['point'] as LatLng;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${dest.latitude},${dest.longitude}'
      '&waypoints=$waypoints',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _textPri,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Optimised Route', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Sector ${_stops.length} stops', style: const TextStyle(fontSize: 11, color: _textMut)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF22c55e).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF22c55e).withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.gps_fixed, color: Color(0xFF22c55e), size: 12),
                SizedBox(width: 4),
                Text('GPS LOCKED', style: TextStyle(color: Color(0xFF22c55e), fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00d4b4)))
          : Column(
              children: [
                // Destination area (backend)
                if (_backendArea != null)
                  Container(
                    color: _surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: _teal, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Destination: $_backendArea',
                          style: const TextStyle(color: _textMut, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                // Distance + ETA bar
                Container(
                  color: _surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.route, color: _teal, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${_backendDistKm != null ? '${_backendDistKm!.toStringAsFixed(1)} KM' : _totalDist} TOTAL  ·  '
                        '${_backendEtaMins != null ? '$_backendEtaMins MIN ETA' : '$_eta ETA'}',
                        style: const TextStyle(
                          color: _textPri,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Map
                SizedBox(
                  height: 260,
                  child: FutureBuilder<List<Polygon>>(
                    future: _kmlZonesFuture,
                    builder: (context, snapshot) {
                      return FlutterMap(
                        options: MapOptions(
                          initialCenter: widget.officerPos,
                          initialZoom: 11,
                          backgroundColor: _bg,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png',
                            userAgentPackageName: 'com.rakshak.app',
                          ),
                          // KML zone polygons (risk-coloured)
                          if (snapshot.hasData)
                            PolygonLayer(polygons: snapshot.data!),
                          if (_routePoints.length > 1)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  color: const Color(0xFFf59e0b),
                                  strokeWidth: 3,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: widget.officerPos,
                                width: 32, height: 32,
                                child: const Icon(Icons.person_pin_circle, color: Color(0xFF3b82f6), size: 28),
                              ),
                              ..._stops.map((s) {
                                final pt = s['point'] as LatLng;
                                final color = _riskColor(s['risk'] as String);
                                return Marker(
                                  point: pt,
                                  width: 28, height: 28,
                                  child: Icon(Icons.location_on, color: color, size: 24),
                                );
                              }),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Patrol sequence
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _stops.length,
                    itemBuilder: (_, i) {
                      final stop = _stops[i];
                      final color = _riskColor(stop['risk'] as String);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: color),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(stop['name'] as String, style: const TextStyle(color: _textPri, fontWeight: FontWeight.w600)),
                                  Text('ETA: ${stop['eta']}', style: const TextStyle(color: _textMut, fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                stop['risk'] as String,
                                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Deployment zones from patrol optimizer
                if (_optimizerLoading || _deploymentZones.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _teal.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: _teal, size: 14),
                              const SizedBox(width: 6),
                              const Text(
                                'AI DEPLOYMENT SUGGESTIONS',
                                style: TextStyle(
                                  color: _teal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                              const Spacer(),
                              if (_optimizerLoading)
                                const SizedBox(
                                  width: 12, height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: _teal,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_deploymentZones.isEmpty && !_optimizerLoading)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
                            child: Text(
                              'No suggestions available',
                              style: TextStyle(color: _textMut, fontSize: 12),
                            ),
                          ),
                        ..._deploymentZones.map((zone) {
                          final name     = zone['name']?.toString()
                              ?? zone['zone_name']?.toString()
                              ?? zone['pincode']?.toString()
                              ?? 'Zone';
                          final priority = zone['priority']?.toString()
                              ?? zone['risk_level']?.toString()
                              ?? zone['risk']?.toString()
                              ?? '';
                          final reason   = zone['reason']?.toString()
                              ?? zone['rationale']?.toString()
                              ?? '';
                          final color    = _riskColor(priority);
                          return Container(
                            margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: color.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.place, color: color, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: _textPri,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (reason.isNotEmpty)
                                        Text(
                                          reason,
                                          style: const TextStyle(color: _textMut, fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ),
                                if (priority.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      priority.toUpperCase(),
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),

                // Start navigation button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _startNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: const Color(0xFF00382e),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text(
                        'START NAVIGATION',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
