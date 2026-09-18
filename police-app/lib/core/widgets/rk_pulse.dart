import 'package:flutter/material.dart';

/// Rakshak Pulse — Stitch spec
/// Rhythmic opacity animation: 1.0 → 0.6 on the teal accent.
/// Linear curve only — no bounce, no spring.
class RkPulse extends StatefulWidget {
  final Widget child;
  final Color color;
  final Duration duration;

  const RkPulse({
    super.key,
    required this.child,
    required this.color,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<RkPulse> createState() => _RkPulseState();
}

class _RkPulseState extends State<RkPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);

    _opacity = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, child) => Opacity(opacity: _opacity.value, child: child),
      child: widget.child,
    );
  }
}
