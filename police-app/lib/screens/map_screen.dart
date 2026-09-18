import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/patrol.dart';
import '../models/sos_alert.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

/// Officer console.
///
/// Dispatch is fully automatic: `POST /sos/live` picks the nearest free unit
/// and diverts it in the same call, so there is no Accept/Reject here. The app
/// polls `GET /police/sos/active` every 2 s, adopts the `assigned_patrol_id`
/// the backend chose as "my unit", and puts the assignment full-screen.
///
/// The only lifecycle writes this screen makes are **Reached** and **Resolved**.
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
  static const _border  = Color(0xFF30363d);
  static const _teal    = Color(0xFF00d4b4);
  static const _red     = Color(0xFFef4444);
  static const _blue    = Color(0xFF3b82f6);
  static const _amber   = Color(0xFFf59e0b);
  static const _green   = Color(0xFF22c55e);
  static const _textPri = Color(0xFFf0f6fc);
  static const _textMut = Color(0xFF8b949e);

  static const _pollInterval = Duration(seconds: 2);

  int _tab = 0;
  LatLng _officerPos = const LatLng(13.0827, 80.2707);

  List<Patrol>   _patrols  = [];
  List<SosAlert> _active   = [];

  /// The unit this officer is driving. Adopted at login (nearest unit) and
  /// re-pointed at whichever unit the backend dispatches.
  String? _myPatrolId;

  /// The SOS assigned to `_myPatrolId`, if any.
  SosAlert? _assignment;

  bool _loading      = true;
  bool _actionInFlight = false;
  /// Set after Resolved so the "incident closed" confirmation can be shown
  /// before the console drops back to the patrolling state.
  SosAlert? _justResolved;

  Timer? _pollTimer;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.35, end: 1.0).animate(_pulseCtrl);

    _initLocation();
    _poll();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.getCurrentLocation();
    if (mounted) setState(() => _officerPos = pos);
  }

  Patrol? get _myPatrol {
    if (_myPatrolId == null) return null;
    for (final p in _patrols) {
      if (p.id == _myPatrolId) return p;
    }
    return null;
  }

  double _sqDist(double aLat, double aLng, double bLat, double bLng) {
    final dLat = aLat - bLat;
    final dLng = aLng - bLng;
    return dLat * dLat + dLng * dLng;
  }

  /// Straight-line km, used only for display when the backend omits distance.
  double _haversineKm(double aLat, double aLng, double bLat, double bLng) {
    const r = 6371.0;
    final dLat = (bLat - aLat) * math.pi / 180;
    final dLng = (bLng - aLng) * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(aLat * math.pi / 180) *
            math.cos(bLat * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  Future<void> _poll() async {
    final patrols = await ApiService.fetchPatrols();
    final active = await ApiService.fetchActiveSos(
      officerLat: _officerPos.latitude,
      officerLng: _officerPos.longitude,
    );
    if (!mounted) return;

    // A failed request must not be read as "no incidents" — that would clear a
    // live assignment and flash a false "resolved" banner. Skip the tick.
    if (patrols == null || active == null) return;

    // Which unit are we? The backend's choice wins.
    //
    // Pass 1 keeps us on the incident already assigned to our unit. Pass 2
    // handles the demo's actual order — the officer logs in first, so we hold
    // a provisional unit (the nearest one), and the backend then dispatches
    // whichever unit is closest to the citizen. That unit is who this officer
    // is driving, so re-point to it rather than ignoring the assignment.
    String? myId = _myPatrolId;
    SosAlert? mine;

    for (final sos in active) {
      final pid = sos.assignedPatrolId;
      if (pid != null && pid.isNotEmpty && pid == myId) { mine = sos; break; }
    }
    if (mine == null) {
      for (final sos in active) {
        final pid = sos.assignedPatrolId;
        if (pid != null && pid.isNotEmpty) { myId = pid; mine = sos; break; }
      }
    }

    // Nothing dispatched yet — adopt the unit closest to the officer so the
    // console always has a patrol id and a live position to show.
    if (myId == null && patrols.isNotEmpty) {
      var best = patrols.first;
      var bestD = double.infinity;
      for (final p in patrols) {
        if (!p.hasPosition) continue;
        final d = _sqDist(
            _officerPos.latitude, _officerPos.longitude, p.lat!, p.lng!);
        if (d < bestD) { bestD = d; best = p; }
      }
      myId = best.id;
    }

    // The incident we were on has left the active feed → it is closed.
    final closed = _assignment != null && mine == null;

    setState(() {
      _patrols     = patrols;
      _active      = active;
      _myPatrolId  = myId;
      if (closed) _justResolved = _assignment;
      _assignment  = mine;
      _loading     = false;
    });

    // Centre on a newly-arrived assignment so the officer sees it immediately.
    if (mine != null && mine.lat != null && mine.lng != null && _tab == 0) {
      _mapController.move(LatLng(mine.lat!, mine.lng!), 14.0);
    }
  }

  // ── Lifecycle actions ────────────────────────────────────────────────────

  Future<void> _navigateToSos(SosAlert incident) async {
    final lat = incident.lat, lng = incident.lng;
    final uri = (lat != null && lng != null)
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving')
        : Uri.parse(
            'https://www.google.com/maps/search/${Uri.encodeComponent('${incident.pincode ?? ''} Chennai India')}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _toast('Could not open Maps');
    }
  }

  Future<void> _markReached(SosAlert incident) async {
    final id = incident.sosId ?? incident.id;
    if (id.isEmpty || _actionInFlight) return;
    setState(() => _actionInFlight = true);

    final ok = await ApiService.markReached(id, patrolId: _myPatrolId);

    if (!mounted) return;
    setState(() => _actionInFlight = false);
    if (ok) {
      _toast('Arrival logged — control room updated');
      await _poll();
    } else {
      _toast('Could not reach the control room. Try again.', isError: true);
    }
  }

  Future<void> _markResolved(SosAlert incident) async {
    final id = incident.sosId ?? incident.id;
    if (id.isEmpty || _actionInFlight) return;
    setState(() => _actionInFlight = true);

    final ok = await ApiService.markResolved(id, patrolId: _myPatrolId);

    if (!mounted) return;
    setState(() => _actionInFlight = false);
    if (ok) {
      _toast('Incident resolved — returning to patrol route');
      await _poll();
    } else {
      _toast('Could not reach the control room. Try again.', isError: true);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _red : _surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Map ──────────────────────────────────────────────────────────────────

  Widget _patrolMarker(Patrol p, {required bool isMine}) {
    final col = p.status == 'Responding'
        ? _amber
        : (p.status == 'AtScene' ? _red : (isMine ? _teal : _blue));
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: col,
        border: Border.all(
            color: isMine ? Colors.white : Colors.white70,
            width: isMine ? 2.5 : 1.5),
        boxShadow: [BoxShadow(color: col.withValues(alpha: 0.5), blurRadius: 6)],
      ),
      child: const Icon(Icons.local_police, color: Colors.white, size: 12),
    );
  }

  Widget _buildMap() {
    final incident = _assignment;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: LatLng(13.0827, 80.2707),
            initialZoom: 12.0,
            minZoom: 10.0,
            maxZoom: 16.0,
            backgroundColor: _bg,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png',
              userAgentPackageName: 'com.rakshak.police',
            ),

            // Every live patrol unit — the city stays visibly covered.
            MarkerLayer(
              markers: [
                for (final p in _patrols)
                  if (p.hasPosition)
                    Marker(
                      point: LatLng(p.lat!, p.lng!),
                      width: 22, height: 22,
                      child: _patrolMarker(p, isMine: p.id == _myPatrolId),
                    ),
              ],
            ),

            // Assigned incident
            if (incident?.lat != null && incident?.lng != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(incident!.lat!, incident.lng!),
                    width: 46, height: 46,
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
          ],
        ),

        // Status banner
        Positioned(
          top: 12, left: 12, right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: (incident != null ? _red : _surface).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: incident != null ? _red : _border),
            ),
            child: Row(
              children: [
                Icon(incident != null ? Icons.sos : Icons.local_police,
                    color: incident != null ? Colors.white : _teal, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    incident != null
                        ? 'RESPONDING TO: ${incident.zoneName}'
                        : 'PATROL ACTIVE — NO ACTIVE SOS NEARBY',
                    style: TextStyle(
                        color: incident != null ? Colors.white : _textPri,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Zoom
        Positioned(
          bottom: 16, right: 12,
          child: Column(
            children: [
              _zoomBtn(Icons.add, () => _mapController.move(
                  _mapController.camera.center, _mapController.camera.zoom + 1)),
              const SizedBox(height: 4),
              _zoomBtn(Icons.remove, () => _mapController.move(
                  _mapController.camera.center, _mapController.camera.zoom - 1)),
            ],
          ),
        ),

        // Fleet counter
        Positioned(
          bottom: 16, left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _border),
            ),
            child: Text(
              '${_patrols.length} units on patrol',
              style: const TextStyle(color: _textMut, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

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

  // ── Full-screen assignment card (P3) ─────────────────────────────────────

  Widget _buildAssignmentCard(SosAlert a) {
    final reached = a.isReached;
    final accent  = reached ? _green : _red;

    final distanceKm = a.distanceKm ??
        ((a.lat != null && a.lng != null && _myPatrol?.hasPosition == true)
            ? _haversineKm(_myPatrol!.lat!, _myPatrol!.lng!, a.lat!, a.lng!)
            : null);

    final etaLabel = reached
        ? 'ON SCENE'
        : (a.etaSeconds == null
            ? '—'
            : a.etaSeconds! <= 0
                ? 'ARRIVING'
                : '${a.etaSeconds}s');

    return Container(
      color: _bg,
      child: SafeArea(
        child: Column(
          children: [
            // Alert banner
            Container(
              width: double.infinity,
              color: accent,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, child) =>
                        Opacity(opacity: reached ? 1.0 : _pulseAnim.value, child: child),
                    child: Icon(reached ? Icons.check_circle : Icons.warning_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    reached ? 'ON SCENE — INCIDENT OPEN' : 'NEAREST SOS ASSIGNED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    reached
                        ? 'You have reported arrival. Close the incident when the citizen is safe.'
                        : 'A citizen nearby has triggered an SOS.\nProceed immediately to the incident location.',
                    style: const TextStyle(
                        color: _textPri, fontSize: 16, height: 1.45,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),

                  // ETA + distance headline
                  Row(
                    children: [
                      Expanded(
                        child: _metricBox(
                          label: reached ? 'STATUS' : 'ETA',
                          value: etaLabel,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _metricBox(
                          label: 'DISTANCE',
                          value: distanceKm != null
                              ? '${distanceKm.toStringAsFixed(1)} km'
                              : '—',
                          color: _teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Incident detail
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(Icons.person_outline, 'Citizen',
                            a.citizenName ?? 'Anonymous'),
                        _infoRow(Icons.place_outlined, 'Location', a.zoneName),
                        _infoRow(
                            Icons.my_location,
                            'Coordinates',
                            a.lat != null && a.lng != null
                                ? '${a.lat!.toStringAsFixed(4)}°N, ${a.lng!.toStringAsFixed(4)}°E'
                                : '—'),
                        _infoRow(Icons.local_police_outlined, 'Your unit',
                            _myPatrolId ?? '—'),
                        if (a.assignedOfficer != null)
                          _infoRow(Icons.badge_outlined, 'Officer', a.assignedOfficer!),
                        if (a.assignedVehicle != null)
                          _infoRow(Icons.directions_car_outlined, 'Vehicle',
                              a.assignedVehicle!),
                        _infoRow(Icons.confirmation_number_outlined, 'Incident',
                            a.sosId ?? a.id),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Navigate
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToSos(a),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: const Color(0xFF00382e),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.navigation, size: 18),
                      label: const Text('NAVIGATE',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Reached — the on-scene transition
                  if (!reached)
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed:
                            _actionInFlight ? null : () => _markReached(a),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _red.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        icon: _actionInFlight
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.flag, size: 18),
                        label: Text(_actionInFlight ? 'SENDING…' : 'REACHED',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5)),
                      ),
                    ),

                  // Resolved — only after arrival is on record
                  if (reached)
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed:
                            _actionInFlight ? null : () => _markResolved(a),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: const Color(0xFF04240f),
                          disabledBackgroundColor: _green.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        icon: _actionInFlight
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_circle, size: 18),
                        label: Text(_actionInFlight ? 'SENDING…' : 'RESOLVED',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5)),
                      ),
                    ),

                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _tab = 1),
                      child: const Text('VIEW ON MAP',
                          style: TextStyle(
                              color: _textMut,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: _textMut,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.0)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, color: _textMut, size: 15),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: _textMut, fontSize: 12.5)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: _textPri, fontSize: 12.5, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Standby: patrol active, nothing assigned ─────────────────────────────

  Widget _buildStandby() {
    final mine = _myPatrol;

    return Container(
      color: _bg,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              Center(
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) =>
                      Opacity(opacity: _pulseAnim.value, child: child),
                  child: Container(
                    width: 76, height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green.withValues(alpha: 0.12),
                      border: Border.all(color: _green.withValues(alpha: 0.5), width: 2),
                    ),
                    child: const Icon(Icons.local_police, color: _green, size: 36),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Patrol Active',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _textPri, fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'No active SOS nearby.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMut, fontSize: 14),
              ),
              const SizedBox(height: 26),

              // Live unit state
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('YOUR UNIT',
                        style: TextStyle(
                            color: _textMut,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    _infoRow(Icons.local_police_outlined, 'Patrol ID',
                        mine?.id ?? _myPatrolId ?? '—'),
                    _infoRow(Icons.badge_outlined, 'Officer',
                        mine?.officer.isNotEmpty == true
                            ? mine!.officer
                            : widget.officerName),
                    _infoRow(Icons.directions_car_outlined, 'Vehicle',
                        mine?.vehicle.isNotEmpty == true ? mine!.vehicle : '—'),
                    _infoRow(Icons.route_outlined, 'Status',
                        mine?.status ?? 'Patrolling'),
                    _infoRow(Icons.place_outlined, 'Zone',
                        mine?.zoneName.isNotEmpty == true
                            ? mine!.zoneName
                            : (mine?.zone ?? '—')),
                    _infoRow(
                        Icons.my_location,
                        'Position',
                        mine?.hasPosition == true
                            ? '${mine!.lat!.toStringAsFixed(4)}°N, ${mine.lng!.toStringAsFixed(4)}°E'
                            : 'acquiring…'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Fleet-wide context
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _fleetStat('${_patrols.length}', 'ON PATROL', _green),
                    _fleetStat(
                        '${_patrols.where((p) => p.status == 'Responding').length}',
                        'RESPONDING', _amber),
                    _fleetStat('${_active.length}', 'ACTIVE SOS',
                        _active.isEmpty ? _textMut : _red),
                  ],
                ),
              ),

              if (_justResolved != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _green.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: _green, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Last incident ${_justResolved!.sosId ?? _justResolved!.id} resolved. '
                          'Unit released back to its patrol route.',
                          style: const TextStyle(color: _textPri, fontSize: 12),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _justResolved = null),
                        child: const Icon(Icons.close, color: _textMut, size: 16),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Text(
                'Dispatch is automatic — the control room assigns the nearest '
                'free unit the moment a citizen raises an SOS.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMut, fontSize: 11.5, height: 1.5),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fleetStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: _textMut, fontSize: 9, fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      ],
    );
  }

  // ── Shell ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }

    final assignment = _assignment;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top bar
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
                        Text(
                          '${widget.officerBadge}${_myPatrolId != null ? '  ·  $_myPatrolId' : ''}',
                          style: const TextStyle(
                              color: _textMut,
                              fontSize: 11,
                              fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _green.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: _green, size: 8),
                        SizedBox(width: 4),
                        Text('ON DUTY',
                            style: TextStyle(
                                color: _green,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  // Tab 0 — the assignment, or the standby console
                  assignment != null
                      ? _buildAssignmentCard(assignment)
                      : _buildStandby(),
                  // Tab 1 — live map
                  _buildMap(),
                ],
              ),
            ),

            // Bottom nav
            Container(
              color: _surface,
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    _navItem(0, Icons.bolt_outlined, 'ASSIGNMENT',
                        badge: assignment != null ? '1' : null),
                    _navItem(1, Icons.map_outlined, 'MAP'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
                        decoration:
                            const BoxDecoration(color: _red, shape: BoxShape.circle),
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
