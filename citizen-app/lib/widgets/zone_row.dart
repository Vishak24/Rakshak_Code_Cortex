import 'package:flutter/material.dart';

class ZoneRow extends StatelessWidget {
  final String name;
  final int users;
  final String risk;
  final VoidCallback? onFlag;

  const ZoneRow({
    super.key,
    required this.name,
    required this.users,
    required this.risk,
    this.onFlag,
  });

  Color _riskColor() {
    switch (risk.toUpperCase()) {
      case 'CRITICAL': return const Color(0xFFef4444);
      case 'ELEVATED': return const Color(0xFFf59e0b);
      default:         return const Color(0xFF22c55e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _riskColor();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161b22),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFFf0f6fc),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$users unresolved journeys',
                  style: const TextStyle(color: Color(0xFF8b949e), fontSize: 12),
                ),
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
              risk,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onFlag,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF30363d)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'FLAG',
                style: TextStyle(
                  color: Color(0xFF8b949e),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
