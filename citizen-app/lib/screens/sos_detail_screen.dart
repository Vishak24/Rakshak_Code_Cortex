import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import '../models/sos_alert.dart';
import '../services/api_service.dart';

class SosDetailScreen extends StatelessWidget {
  final SosAlert alert;

  const SosDetailScreen({super.key, required this.alert});

  static const _bg      = Color(0xFF0d1117);
  static const _surface = Color(0xFF161b22);
  static const _border  = Color(0xFF30363d);
  static const _red     = Color(0xFFef4444);
  static const _yellow  = Color(0xFFf59e0b);
  static const _textPri = Color(0xFFf0f6fc);
  static const _textMut = Color(0xFF8b949e);

  String _timeAgo() {
    final diff = DateTime.now().difference(alert.timestamp);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    return '${diff.inHours} hours ago';
  }

  Future<void> _navigateTo(BuildContext context) async {
    final lat = alert.lat ?? 13.0827;
    final lng = alert.lng ?? 80.2707;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps')),
        );
      }
    }
  }

  Future<void> _closeAlert(BuildContext context) async {
    if (alert.sosId != null) {
      await ApiService.resolveSos(alert.sosId!);
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Banner — yellow for cancelled, red for active
            if (alert.status == 'cancelled') ...[
              Container(
                width: double.infinity,
                color: _yellow,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.black, size: 16),
                        SizedBox(width: 8),
                        Text(
                          '⚠️ SOS Cancelled by user',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    if (alert.userPhone != null && alert.userPhone!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse('tel:${alert.userPhone}'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone, color: Colors.black87, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              '📞 Call to verify: ${alert.userPhone}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                color: _red,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'CRITICAL ALERT ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  // Alert info card
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                alert.zoneName,
                                style: const TextStyle(
                                  color: _textPri,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _red.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _red.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                alert.riskLevel,
                                style: const TextStyle(color: _red, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _infoRow(Icons.confirmation_number_outlined, 'Alert ID', alert.id.length > 12 ? alert.id.substring(0, 12) : alert.id),
                        _infoRow(Icons.location_on_outlined, 'Location', '${alert.lat?.toStringAsFixed(4) ?? '13.0827'}°N, ${alert.lng?.toStringAsFixed(4) ?? '80.2707'}°E'),
                        _infoRow(Icons.access_time, 'Received', _timeAgo()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const SizedBox(height: 24),

                  // Navigate button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateTo(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.navigation, size: 18),
                      label: const Text(
                        'NAVIGATE THERE',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Close alert button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => _closeAlert(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _textMut,
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text(
                        'CLOSE ALERT',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1),
                      ),
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: _textMut, size: 16),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: _textMut, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: _textPri, fontSize: 13, fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
