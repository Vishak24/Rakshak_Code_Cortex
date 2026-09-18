import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  static const _bg      = Color(0xFF0d1117);
  static const _surface = Color(0xFF161b22);
  static const _red     = Color(0xFFef4444);
  static const _amber   = Color(0xFFf59e0b);
  static const _green   = Color(0xFF22c55e);
  static const _textPri = Color(0xFFf0f6fc);
  static const _textMut = Color(0xFF8b949e);

  bool _loading = true;
  int _totalCount = 0;
  List<Map<String, dynamic>> _byPincode = [];

  // Fleet stats — updated from /patrols
  int _activePatrols = 0;
  int _responseUnits = 0;
  int _standby       = 0;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetch();
    // Poll both citizens + patrols every 60 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetch());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final citizensData = await ApiService.fetchCitizensActive();
    final patrols      = await ApiService.fetchPatrols();

    if (!mounted) return;
    setState(() {
      _totalCount = (citizensData['total_count'] as num?)?.toInt() ?? 0;
      final raw = citizensData['by_pincode'] as List<dynamic>? ?? [];
      _byPincode = raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _loading = false;

      // Fleet stats from live /patrols
      if (patrols.isNotEmpty) {
        _activePatrols = patrols
            .where((p) =>
                p.status.toLowerCase() == 'patrolling' ||
                p.status.toLowerCase() == 'active')
            .length;
        _responseUnits = patrols
            .where((p) => p.status.toLowerCase() == 'responding')
            .length;
        _standby = patrols
            .where((p) => p.status.toLowerCase() == 'standby')
            .length;
        // If all zeros (unknown status strings), use total as active
        if (_activePatrols == 0 && _responseUnits == 0 && _standby == 0) {
          _activePatrols = patrols.length;
        }
      }
    });
  }

  Color _riskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'HIGH':   return _red;
      case 'MEDIUM': return _amber;
      default:       return _green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;

    if (hour < 22) {
      return const ColoredBox(
        color: _bg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bedtime_outlined, color: Color(0xFF8b949e), size: 48),
              SizedBox(height: 16),
              Text(
                'Monitor Active After 10 PM',
                style: TextStyle(
                    color: Color(0xFFf0f6fc),
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Unresolved journey tracking begins at 22:00',
                style: TextStyle(color: _textMut, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const ColoredBox(
        color: _bg,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF00d4b4)),
        ),
      );
    }

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} PM';
    final displayTotal = _totalCount > 0
        ? _totalCount
        : _byPincode.fold<int>(
            0, (sum, z) => sum + ((z['count'] as num?)?.toInt() ?? 0));

    return Container(
      color: _bg,
      child: Column(
        children: [
          // Header
          Container(
            color: _surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unresolved Journeys',
                        style: TextStyle(
                            color: Color(0xFFf0f6fc),
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(timeStr,
                          style: const TextStyle(
                              color: Color(0xFF8b949e), fontSize: 12)),
                    ],
                  ),
                ),
                // Refresh button
                GestureDetector(
                  onTap: _fetch,
                  child: const Icon(Icons.refresh,
                      color: Color(0xFF00d4b4), size: 18),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _red.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '$displayTotal total',
                    style: const TextStyle(
                        color: _red,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // Pincode list
          Expanded(
            child: _byPincode.isEmpty
                ? const Center(
                    child: Text(
                      'No active citizens tracked',
                      style: TextStyle(color: _textMut, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _byPincode.length,
                    itemBuilder: (_, i) {
                      final z = _byPincode[i];
                      final risk =
                          (z['risk'] as String? ?? 'LOW').toUpperCase();
                      final color = _riskColor(risk);
                      final area = z['area'] as String? ??
                          z['pincode']?.toString() ??
                          '—';
                      final pincode = z['pincode']?.toString() ?? '';
                      final count = (z['count'] as num?)?.toInt() ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                              left: BorderSide(color: color, width: 3)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(area,
                                      style: const TextStyle(
                                          color: _textPri,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  if (pincode.isNotEmpty)
                                    Text(pincode,
                                        style: const TextStyle(
                                            color: _textMut, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text('$count',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.5)),
                              ),
                              child: Text(risk,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Fleet status footer — live from /patrols
          Container(
            color: _surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _fleetStat('Active Patrols',
                    _activePatrols > 0 ? '$_activePatrols' : '—',
                    _green),
                _fleetStat('Responding',
                    _responseUnits > 0 ? '$_responseUnits' : '—',
                    _amber),
                _fleetStat('Standby',
                    _standby > 0 ? '$_standby' : '—',
                    _textMut),
              ],
            ),
          ),

          // Alert button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alert sent to all units'),
                      backgroundColor: Color(0xFF161b22),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.campaign, size: 20),
                label: const Text(
                  'INITIATE AREA-WIDE ALERT',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fleetStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label,
            style:
                const TextStyle(color: Color(0xFF8b949e), fontSize: 10)),
      ],
    );
  }
}
