import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../theme/app_colors.dart';

/// Rakshak Label — Label Small Caps style by default
class RkLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;

  const RkLabel({
    super.key,
    required this.text,
    this.style,
    this.color,
    this.textAlign,
  });

  factory RkLabel.small(String text, {Color? color}) => RkLabel(
        text: text.toUpperCase(),
        style: AppText.labelSmallCaps,
        color: color,
      );

  factory RkLabel.medium(String text, {Color? color}) => RkLabel(
        text: text,
        style: AppText.labelMedium,
        color: color,
      );

  factory RkLabel.large(String text, {Color? color}) => RkLabel(
        text: text,
        style: AppText.labelLarge,
        color: color,
      );

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: (style ?? AppText.labelSmallCaps).copyWith(
        color: color ?? AppColors.textSecondary,
      ),
      textAlign: textAlign,
    );
  }
}
