import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sos_alert.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

// ── Nominatim pincode boundary fetcher ───────────────────────────────────────
// Fetches polygon boundaries from OSM Nominatim — no file assets needed.

Future<List<Polygon>> fetchPincodePolygon(String pincode, String risk) async {
  try {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=$pincode,Chennai,Tamil+Nadu,India'
      '&format=geojson&polygon_geojson=1&limit=1',
    );
    final res = await http
        .get(url, headers: {'User-Agent': 'Rakshak/1.0'})
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return [];

    final geo      = jsonDecode(res.body) as Map<String, dynamic>;
    final features = geo['features'] as List<dynamic>;
    if (features.isEmpty) return [];

    final fillColor = risk == 'HIGH'
        ? const Color(0xFFef4444).withValues(alpha: 0.40)
        : risk == 'MEDIUM'
            ? const Color(0xFFf59e0b).withValues(alpha: 0.35)
            : const Color(0xFF22c55e).withValues(alpha: 0.25);

    final borderColor = risk == 'HIGH'
        ? const Color(0xFFef4444)
        : risk == 'MEDIUM'
            ? const Color(0xFFf59e0b)
            : const Color(0xFF22c55e);

    final polygons = <Polygon>[];
    final geom     = features[0]['geometry'] as Map<String, dynamic>;
    final type     = geom['type'] as String;
    final coords   = geom['coordinates'] as List<dynamic>;

    final rings = <List<dynamic>>[];
    if (type == 'Polygon') {
      rings.add(coords[0] as List<dynamic>);
    } else if (type == 'MultiPolygon') {
      for (final p in coords) {
        rings.add((p as List<dynamic>)[0] as List<dynamic>);
      }
    }

    for (final ring in rings) {
      final points = ring.map((c) {
        final coord = c as List<dynamic>;
        return LatLng(
          (coord[1] as num).toDouble(),
          (coord[0] as num).toDouble(),
        );
      }).toList();
      if (points.length >= 3) {
        polygons.add(Polygon(
          points:            points,
          color:             fillColor,
          borderColor:       borderColor,
          borderStrokeWidth: 1.5,
          isFilled:          true,
        ));
      }
    }
    return polygons;
  } catch (_) {
    return [];
  }
}

// ── MapScreen ─────────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  final String officerBadge;
  final String officerName;

  const MapScreen({
    super.key,
    required this.officerBadge,
    required this.officerName,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  static const _bg      = Color(0xFF0d1117);
  static const _surface = Color(0xFF161b22);
  static const _teal    = Color(0xFF00d4b4);
  static const _red     = Color(0xFFef4444);
  static const _textPri = Color(0xFFf0f6fc);
  static const _textMut = Color(0xFF8b949e);

  // Zone risk — seeded with defaults, updated every 60s from /heatmap/live
  Map<String, String> _zoneRisk = {
    '600017': 'HIGH',
    '600081': 'HIGH',
    '600006': 'MEDIUM',
    '600004': 'MEDIUM',
    '600058': 'LOW',
  };

  // Cached polygon ring geometry per pincode (avoids re-fetching Nominatim)
  final Map<String, List<List<LatLng>>> _polygonRings = {};

  int _tab = 0;
  LatLng _officerPos = const LatLng(13.0827, 80.2707);
  List<SosAlert> _alerts    = [];
  List<Polygon>  _kmlPolygons = [];
  bool _zonesLoading = true;
  Timer? _pollTimer;
  Timer? _riskTimer;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  final MapController _mapController = MapController();

  // ── Active incident — set when officer accepts a SOS ─────────────────────
  SosAlert? _activeIncident;
  bool _accepting = false;   // true while PATCH is in-flight

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(_pulseCtrl);

    _initLocation();
    _loadZones();
    _pollSos();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollSos());
    // Refresh zone risk scores every 60 seconds from /heatmap/live
    _riskTimer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshRisk());
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (mounted) setState(() => _officerPos = pos);
  }

  Future<void> _loadZones() async {
    final all = <Polygon>[];
    for (final entry in _zoneRisk.entries) {
      final polys = await fetchPincodePolygon(entry.key, entry.value);
      all.addAll(polys);
      // Cache ring geometry so we can recolor without re-fetching Nominatim
      _polygonRings[entry.key] = polys.map((p) => p.points).toList();
      // Nominatim rate limit: 1 req/sec
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (mounted) setState(() { _kmlPolygons = all; _zonesLoading = false; });
  }

  /// Poll GET /heatmap/live every 60s and recolor zones when a level changes.
  Future<void> _refreshRisk() async {
    final levels = await ApiService.fetchZoneRiskLevels();
    if (levels.isEmpty || !mounted) return;

    var changed = false;
    for (final code in _zoneRisk.keys.toList()) {
      final level = levels[code];
      if (level != null && _zoneRisk[code] != level) {
        _zoneRisk[code] = level;
        changed = true;
      }
    }

    if (changed) _rebuildPolygons();
  }

  /// Rebuild Polygon objects from cached ring geometry with updated risk colors.
  void _rebuildPolygons() {
    final all = <Polygon>[];
    for (final entry in _polygonRings.entries) {
      final risk        = _zoneRisk[entry.key] ?? 'LOW';
      final fillColor   = risk == 'HIGH'
          ? const Color(0xFFef4444).withValues(alpha: 0.40)
          : risk == 'MEDIUM'
              ? const Color(0xFFf59e0b).withValues(alpha: 0.35)
              : const Color(0xFF22c55e).withValues(alpha: 0.25);
      final borderColor = risk == 'HIGH'
          ? const Color(0xFFef4444)
          : risk == 'MEDIUM'
              ? const Color(0xFFf59e0b)
              : const Color(0xFF22c55e);
      for (final points in entry.value) {
        if (points.length >= 3) {
          all.add(Polygon(
            points:            points,
            color:             fillColor,
            borderColor:       borderColor,
            borderStrokeWidth: 1.5,
            isFilled:          true,
          ));
        }
      }
    }
    if (mounted) setState(() => _kmlPolygons = all);
  }

  // ── SOS deduplication — same pattern as dashboard useSosEvents ──────────
  final Set<String> _seenSosIds = {};

  Future<void> _pollSos() async {
    // Use GET /sos/live — same endpoint as the dashboard
    final fresh = await ApiService.fetchLiveSos();
    if (!mounted) return;

    // Merge: add new IDs, keep existing accepted incident intact
    final merged = <SosAlert>[];
    for (final alert in fresh) {
      final id = alert.sosId ?? alert.id;
      _seenSosIds.add(id);
      merged.add(alert);
    }

    setState(() => _alerts = merged);
  }

  /// Accept a SOS — PATCH backend, set as active incident, switch to map tab.
  Future<void> _acceptSos(SosAlert alert) async {
    if (_accepting) return;
    setState(() => _accepting = true);

    final sosId = alert.sosId ?? alert.id;
    if (sosId.isNotEmpty) {
      await ApiService.acceptSos(sosId);
    }

    if (mounted) {
      setState(() {
        _activeIncident = alert;
        _accepting = false;
        _tab = 0;   // switch to MAP tab to show route
      });
      // Pan map to SOS location
      if (alert.lat != null && alert.lng != null) {
        _mapController.move(LatLng(alert.lat!, alert.lng!), 14.0);
      }
    }
  }

  /// Open Google Maps navigation to the SOS location using lat/lng from the record.
  /// Falls back to pincode search if coordinates are unavailable.
  Future<void> _navigateToSos(SosAlert incident) async {
    final lat = incident.lat;
    final lng = incident.lng;
    Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    } else {
      final pincode = incident.pincode ?? '';
      uri = Uri.parse(
          'https://www.google.com/maps/search/${Uri.encodeComponent('$pincode Chennai India')}');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _riskTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Zoom button ───────────────────────────────────────────────────────────
  Widget _zoomBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1c2128),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }

  Widget _buildMap() {
    final incident = _activeIncident;
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(13.0827, 80.2707),
            initialZoom: 11.0,
            minZoom: 9.0,
            maxZoom: 16.0,
            backgroundColor: Color(0xFF0d1117),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png',
              userAgentPackageName: 'com.rakshak.police',
            ),
            // Zone polygons
            if (_kmlPolygons.isNotEmpty)
              PolygonLayer(polygons: _kmlPolygons),
            // Active incident marker only — no simulated patrol dots
            if (incident != null && incident.lat != null && incident.lng != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(incident.lat!, incident.lng!),
                    width: 48, height: 48,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _red.withValues(alpha: _pulseAnim.value * 0.35),
                          border: Border.all(color: _red, width: 2.5),
                        ),
                        child: const Icon(Icons.sos, color: _red, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            // Officer position
            MarkerLayer(
              markers: [
                Marker(
                  point: _officerPos,
                  width: 44, height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3b82f6).withValues(alpha: 0.2),
                      border: Border.all(color: const Color(0xFF3b82f6), width: 2),
                    ),
                    child: const Icon(Icons.person_pin_circle,
                        color: Color(0xFF3b82f6), size: 22),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Zoom buttons
        Positioned(
          bottom: 100, right: 12,
          child: Column(
            children: [
              _zoomBtn(Icons.add, () => _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom + 1,
              )),
              const SizedBox(height: 4),
              _zoomBtn(Icons.remove, () => _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom - 1,
              )),
            ],
          ),
        ),

        // Active incident banner
        if (incident != null)
          Positioned(
            top: 12, left: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sos, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'RESPONDING TO: ${incident.zoneName}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.5),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _activeIncident = null),
                    child: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
                ],
              ),
            ),
          ),

        // No active incident — empty state
        if (incident == null && _alerts.isEmpty && !_zonesLoading)
          Positioned(
            bottom: 80, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'No active incidents right now.',
                  style: TextStyle(color: _textMut, fontSize: 12),
                ),
              ),
            ),
          ),

        // Route button — only when incident is active
        if (incident != null)
          Positioned(
            bottom: 16, left: 16, right: 16,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToSos(incident),
              style: ElevatedButton.styleFrom(
                backgroundColor: _teal,
                foregroundColor: const Color(0xFF00382e),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              icon: const Icon(Icons.navigation, size: 18),
              label: const Text('NAVIGATE TO SOS',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ),

        // Loading zones indicator
        if (_zonesLoading)
          Positioned(
            top: incident != null ? 70 : 12, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10, height: 10,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Color(0xFF00d4b4)),
                    ),
                    SizedBox(width: 6),
                    Text('Loading zones…',
                        style: TextStyle(color: Color(0xFF8b949e), fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertsTab() {
    if (_alerts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF22c55e), size: 48),
            SizedBox(height: 12),
            Text('No active incidents right now.',
                style: TextStyle(color: Color(0xFF8b949e), fontSize: 14)),
            SizedBox(height: 6),
            Text('Live SOS alerts will appear here.',
                style: TextStyle(color: Color(0xFF8b949e), fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alerts.length,
      itemBuilder: (_, i) {
        final a = _alerts[i];
        final isActive = _activeIncident?.id == a.id;
        final timeAgo  = _timeAgo(a.timestamp);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isActive ? _teal : _red,
                width: 3,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zone + risk badge
                Row(
                  children: [
                    Icon(Icons.sos, color: isActive ? _teal : _red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a.zoneName,
                          style: const TextStyle(
                              color: _textPri,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(a.riskLevel,
                          style: const TextStyle(
                              color: _red, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Pincode + time
                Row(
                  children: [
                    if (a.pincode != null) ...[
                      const Icon(Icons.location_on_outlined, color: _textMut, size: 13),
                      const SizedBox(width: 3),
                      Text(a.pincode!, style: const TextStyle(color: _textMut, fontSize: 11)),
                      const SizedBox(width: 12),
                    ],
                    const Icon(Icons.access_time, color: _textMut, size: 13),
                    const SizedBox(width: 3),
                    Text(timeAgo, style: const TextStyle(color: _textMut, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 12),
                // Accept / Active button
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: isActive
                      ? OutlinedButton.icon(
                          onPressed: () => setState(() => _tab = 0),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _teal,
                            side: const BorderSide(color: _teal),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          icon: const Icon(Icons.navigation, size: 16),
                          label: const Text('VIEW ON MAP',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        )
                      : ElevatedButton.icon(
                          onPressed: _accepting ? null : () => _acceptSos(a),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          icon: _accepting
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check, size: 16),
                          label: Text(_accepting ? 'Accepting…' : 'ACCEPT & RESPOND',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                ),

                // ── Cancelled SOS banner — shows phone for follow-up ──
                if (a.status == 'cancelled')
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.amber, size: 16),
                            SizedBox(width: 6),
                            Text('SOS Cancelled by user',
                                style: TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                        if (a.userPhone != null) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => launchUrl(
                              Uri.parse('tel:${a.userPhone}'),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.phone,
                                    color: Colors.greenAccent, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'Call to verify: ${a.userPhone}',
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Colors.greenAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          const Text('No phone number on record.',
                              style: TextStyle(color: Colors.amber, fontSize: 11)),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final hasActive = _activeIncident != null;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Container(
              color: _surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.shield, color: _teal, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.officerName,
                            style: const TextStyle(
                                color: _textPri,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text(widget.officerBadge,
                            style: const TextStyle(
                                color: _textMut,
                                fontSize: 11,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22c55e).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF22c55e).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Color(0xFF22c55e), size: 8),
                        SizedBox(width: 4),
                        Text('ON DUTY',
                            style: TextStyle(
                                color: Color(0xFF22c55e),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  _buildMap(),
                  _buildAlertsTab(),
                  _buildResponseTab(),
                ],
              ),
            ),

            // ── Bottom nav ───────────────────────────────────────────────
            Container(
              color: _surface,
              child: Row(
                children: [
                  _navItem(0, Icons.map_outlined, 'MAP'),
                  _navItem(1, Icons.warning_amber_outlined, 'ALERTS',
                      badge: _alerts.isNotEmpty ? _alerts.length.toString() : null),
                  _navItem(2, Icons.bolt_outlined, 'RESPONSE',
                      badge: hasActive ? '1' : null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pincode coordinate lookup (Chennai zones) ────────────────────────────
  static const Map<String, List<double>> _pincodeCoords = {
    '600001': [13.0827, 80.2707], '600004': [13.0732, 80.2609],
    '600005': [13.0569, 80.2787], '600006': [13.0715, 80.2740],
    '600007': [13.1127, 80.2966], '600008': [13.1186, 80.2487],
    '600009': [13.1483, 80.2355], '600010': [13.1675, 80.2617],
    '600014': [13.0339, 80.2553], '600015': [13.0339, 80.2707],
    '600017': [13.0067, 80.2570], '600018': [13.0521, 80.2193],
    '600019': [13.0475, 80.2030], '600020': [13.0521, 80.2118],
    '600024': [12.9815, 80.2209], '600028': [12.9995, 80.2666],
    '600029': [12.9845, 80.2657], '600032': [13.0350, 80.2323],
    '600034': [13.0339, 80.2193], '600035': [13.0402, 80.2091],
    '600036': [13.0883, 80.2105], '600040': [13.0850, 80.2101],
    '600042': [13.0883, 80.1762], '600044': [13.0339, 80.1575],
    '600045': [13.0237, 80.1762], '600050': [12.9673, 80.1501],
    '600053': [12.9515, 80.1438], '600056': [12.9625, 80.2387],
    '600061': [12.9000, 80.2277], '600064': [12.9240, 80.1958],
    '600073': [12.9150, 80.1501], '600078': [13.1144, 80.1606],
    '600082': [13.1675, 80.2355], '600083': [13.1483, 80.2355],
    '600099': [13.1186, 80.2091], '600118': [12.9065, 80.1958],
  };

  /// Returns the [count] pincodes nearest to [pos], sorted by distance.
  List<String> _nearestPincodes(LatLng pos, {int count = 2}) {
    final entries = _pincodeCoords.entries.toList()
      ..sort((a, b) {
        final da = _sqDist(pos.latitude, pos.longitude, a.value[0], a.value[1]);
        final db = _sqDist(pos.latitude, pos.longitude, b.value[0], b.value[1]);
        return da.compareTo(db);
      });
    return entries.take(count).map((e) => e.key).toList();
  }

  double _sqDist(double lat1, double lng1, double lat2, double lng2) {
    final dlat = lat1 - lat2;
    final dlng = lng1 - lng2;
    return dlat * dlat + dlng * dlng;
  }

  Widget _buildResponseTab() {
    final incident  = _activeIncident;
    // When an incident is active, use its pincode as the current zone.
    // Otherwise fall back to GPS-derived nearest pincode.
    final nearest   = _nearestPincodes(_officerPos, count: 2);
    // Only show a pincode when an SOS is actively accepted; otherwise show "—"
    final curPin    = incident?.pincode ?? '—';
    final nearbyPin = nearest.isNotEmpty ? nearest[0] : '—';
    final curRisk   = _zoneRisk[curPin] ?? 'UNKNOWN';
    final activeSos = _alerts.where((a) => a.status != 'resolved').length;

    final riskColor = curRisk == 'HIGH'
        ? _red
        : curRisk == 'MEDIUM'
            ? const Color(0xFFf59e0b)
            : const Color(0xFF22c55e);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Operational status card ───────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OPERATIONAL STATUS',
                    style: TextStyle(
                        color: _textMut, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 14),

                // Current pincode
                _statusRow(
                  label: 'Current pincode',
                  value: curPin,
                  valueColor: incident != null ? _teal : _textMut,
                  icon: Icons.location_on_outlined,
                  sub: incident == null ? 'No active incident' : null,
                  subColor: _textMut,
                ),
                const Divider(color: Colors.white12, height: 20),

                // Nearby pincode
                _statusRow(
                  label: 'Nearby pincode',
                  value: nearbyPin,
                  valueColor: _textPri,
                  icon: Icons.near_me_outlined,
                  sub: _zoneRisk[nearbyPin] != null
                      ? 'Risk: ${_zoneRisk[nearbyPin]}'
                      : null,
                  subColor: _zoneRisk[nearbyPin] == 'HIGH'
                      ? _red
                      : _zoneRisk[nearbyPin] == 'MEDIUM'
                          ? const Color(0xFFf59e0b)
                          : _textMut,
                ),
                const Divider(color: Colors.white12, height: 20),

                // Active SOS count
                _statusRow(
                  label: 'Active SOS',
                  value: activeSos == 0 ? 'None' : '$activeSos',
                  valueColor: activeSos > 0 ? _red : const Color(0xFF22c55e),
                  icon: Icons.sos_outlined,
                  sub: activeSos > 0 ? 'Tap Alerts to respond' : null,
                  subColor: _textMut,
                ),
                const Divider(color: Colors.white12, height: 20),

                // Last accepted SOS
                _statusRow(
                  label: 'Last accepted SOS',
                  value: incident != null
                      ? incident.zoneName
                      : 'None',
                  valueColor: incident != null ? _teal : _textMut,
                  icon: Icons.check_circle_outline,
                  sub: incident != null ? 'Dispatched · ${incident.pincode ?? ""}' : null,
                  subColor: _textMut,
                ),
              ],
            ),
          ),

          // ── Zone risk summary ─────────────────────────────────────────
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('CURRENT ZONE RISK',
                        style: TextStyle(
                            color: _textMut, fontSize: 10,
                            fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(curRisk,
                          style: TextStyle(
                              color: riskColor, fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(curPin,
                    style: const TextStyle(
                        color: _textPri, fontSize: 22,
                        fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                const SizedBox(height: 4),
                Text('${_zoneRisk.values.where((v) => v == 'HIGH').length} HIGH · '
                    '${_zoneRisk.values.where((v) => v == 'MEDIUM').length} MEDIUM · '
                    '${_zoneRisk.values.where((v) => v == 'LOW').length} LOW',
                    style: const TextStyle(color: _textMut, fontSize: 11)),
              ],
            ),
          ),

          // ── Active incident action ────────────────────────────────────
          if (incident != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToSos(incident),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  foregroundColor: const Color(0xFF00382e),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('NAVIGATE TO SOS',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: () => setState(() => _activeIncident = null),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textMut,
                  side: const BorderSide(color: Colors.white12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('MARK RESOLVED',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],

          // ── Empty state ───────────────────────────────────────────────
          if (incident == null && activeSos == 0) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Icon(Icons.shield_outlined,
                      color: _textMut.withValues(alpha: 0.4), size: 36),
                  const SizedBox(height: 8),
                  const Text('No active incidents.',
                      style: TextStyle(color: _textMut, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Accept a SOS from Alerts to respond.',
                      style: TextStyle(color: _textMut, fontSize: 11)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusRow({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
    String? sub,
    Color? subColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: _textMut, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: _textMut, fontSize: 11)),
              if (sub != null)
                Text(sub,
                    style: TextStyle(
                        color: subColor ?? _textMut, fontSize: 10)),
            ],
          ),
        ),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace')),
      ],
    );
  }

  Widget _navItem(int index, IconData icon, String label, {String? badge}) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: active ? _teal : _textMut, size: 22),
                  if (badge != null)
                    Positioned(
                      top: -4, right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: _red, shape: BoxShape.circle),
                        child: Text(badge,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: active ? _teal : _textMut,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
