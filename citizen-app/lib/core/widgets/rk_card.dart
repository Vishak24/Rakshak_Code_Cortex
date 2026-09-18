import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Rakshak Card — Stitch spec
/// Flat surface, no elevation, no dividers.
/// Active state: surfaceHigh bg + 2px left teal strip.
class RkCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool isActive;
  final double? borderRadius;

  const RkCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.isActive = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppSpacing.radiusLg;
    final bg = isActive ? AppColors.surfaceHigh : (color ?? AppColors.surface);

    final content = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: isActive
            ? Border(
                left: BorderSide(color: AppColors.accentBright, width: 2),
              )
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      );
    }
    return content;
  }
}
