import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/rk_button.dart';
import '../../../core/widgets/rk_label.dart';
import '../../../core/widgets/rk_pulse.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_phoneCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    // TODO: wire to authControllerProvider.sendOtp(_phoneCtrl.text)
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) context.go('/sentinel');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Dot-grid background
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 375),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: AppSpacing.xxl),

                      // ── Logo ──────────────────────────────────────────
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          border: Border.all(
                              color: AppColors.accentBright.withValues(alpha: 0.3),
                              width: 1),
                        ),
                        child: const Icon(Icons.shield,
                            color: AppColors.accentBright, size: 28),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── App name ──────────────────────────────────────
                      Text(
                        'RAKSHAK',
                        style: GoogleFonts.inter(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentBright,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // ── Sentinel active indicator ─────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RkPulse(
                            color: AppColors.accentBright,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.accentBright,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          RkLabel.small(
                            'SENTINEL INTELLIGENCE ACTIVE',
                            color: AppColors.accentBright,
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.xxl),

                      // ── Phone input card ──────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RkLabel.small('PHONE IDENTIFIER',
                                color: AppColors.textSecondary),
                            const SizedBox(height: AppSpacing.xs),
                            TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                letterSpacing: 3,
                              ),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                prefixText: '+91  ',
                                prefixStyle: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textSecondary,
                                ),
                                hintText: '000 000 0000',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 18,
                                  color: AppColors.textTertiary,
                                  letterSpacing: 3,
                                ),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            // Ghost border bottom
                            Container(
                              height: 1,
                              color: _phoneCtrl.text.isNotEmpty
                                  ? AppColors.accentBright
                                  : AppColors.ghostBorder,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // ── Security notice ───────────────────────────────
                      Text(
                        'Access requires encrypted two-factor verification. '
                        'A secure handshake signal will be transmitted to your registered device.',
                        style: AppText.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.left,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // ── Login button ──────────────────────────────────
                      RkButton(
                        label: 'SECURE LOGIN  ›',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _handleLogin,
                      ),

                      const SizedBox(height: AppSpacing.xxxl),

                      // ── Footer links ──────────────────────────────────
                      RkLabel.small('PRIVACY POLICY',
                          color: AppColors.textSecondary),
                      const SizedBox(height: AppSpacing.sm),
                      RkLabel.small('SYSTEM TECHNICAL SUPPORT',
                          color: AppColors.textTertiary),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Version ───────────────────────────────────────
                      RkLabel.small('RAKSHAK SENTINEL V1.0',
                          color: AppColors.textTertiary),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
