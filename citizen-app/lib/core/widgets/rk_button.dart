import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum RkButtonVariant { primary, secondary, danger }

/// Rakshak Button — Stitch spec
/// Primary : bg #46F1CF, text #00382E, radius 4px
/// Secondary: bg surfaceHighest, text white, radius 4px
/// Danger   : bg #93000A, text white, radius 4px
/// Press    : scale 0.98 — linear curve, no bounce
class RkButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary; // legacy compat
  final RkButtonVariant variant;
  final IconData? icon;
  final double? height;

  const RkButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.variant = RkButtonVariant.primary,
    this.icon,
    this.height,
  });

  @override
  State<RkButton> createState() => _RkButtonState();
}

class _RkButtonState extends State<RkButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  RkButtonVariant get _effectiveVariant =>
      widget.isSecondary ? RkButtonVariant.secondary : widget.variant;

  Color get _bgColor {
    switch (_effectiveVariant) {
      case RkButtonVariant.primary:
        return AppColors.accentBright;
      case RkButtonVariant.secondary:
        return AppColors.surfaceHighest;
      case RkButtonVariant.danger:
        return AppColors.alertRed;
    }
  }

  Color get _fgColor {
    switch (_effectiveVariant) {
      case RkButtonVariant.primary:
        return const Color(0xFF00382E);
      case RkButtonVariant.secondary:
      case RkButtonVariant.danger:
        return AppColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: enabled ? (_) => _pressCtrl.forward() : null,
      onTapUp: enabled
          ? (_) {
              _pressCtrl.reverse();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.linear,
          height: widget.height ?? AppSpacing.buttonHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: enabled ? _bgColor : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_fgColor),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: enabled ? _fgColor : AppColors.textTertiary),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: enabled ? _fgColor : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
