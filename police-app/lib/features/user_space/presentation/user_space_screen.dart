import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/rk_label.dart';
import '../../../core/widgets/rk_pulse.dart';
import '../../../core/providers/settings_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import 'user_controller.dart';

class UserSpaceScreen extends ConsumerStatefulWidget {
  const UserSpaceScreen({super.key});

  @override
  ConsumerState<UserSpaceScreen> createState() => _UserSpaceScreenState();
}

class _UserSpaceScreenState extends ConsumerState<UserSpaceScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(userControllerProvider.notifier).loadUserProfile());
  }

  @override
  Widget build(BuildContext context) {
    // TODO: wire to settingsProvider.languageCode
    final lang = ref.watch(settingsProvider).languageCode;
    // TODO: wire to userControllerProvider
    final state = ref.watch(userControllerProvider);
    // Phone number from auth session
    final authPhone = ref.watch(authControllerProvider).phoneNumber;

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
              color: AppColors.accentBright, strokeWidth: 2),
        ),
      );
    }

    // TODO: wire to UserProfile model
    final user = state.profile;
    final userName = user?.name ?? 'Anjali Devi'; // TODO: wire to UserProfile.name
    // Phone: prefer auth session phone, fall back to profile phone
    final rawPhone = authPhone ?? user?.phone;
    final userPhone = _formatPhone(rawPhone);
    final contacts = state.contacts; // TODO: wire to UserState.contacts

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── FIX 1: Header row — avatar constrained, no overflow ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column — all text, takes remaining space
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RkLabel.small(
                          'USER SPACE / பயனர் பகுதி',
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // User name — 32px bold per spec
                        Text(
                          userName,
                          style: GoogleFonts.inter(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userPhone,
                          style: AppText.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            RkPulse(
                              color: AppColors.accentBright,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentBright,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: RkLabel.small(
                                'SYSTEM ARMED & WATCHING',
                                color: AppColors.accentBright,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Avatar — 44×44, fixed size, right-aligned
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(Icons.person,
                        color: AppColors.accentBright, size: 24),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Scans performed card (teal bg) ────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.lg,
                    horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.accentBright,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_scanner_outlined,
                        color: AppColors.accentDark, size: 28),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '12', // TODO: wire to UserProfile.scanCount
                      style: GoogleFonts.inter(
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentDark,
                        height: 1.0,
                      ),
                    ),
                    RkLabel.small(
                      lang == 'ta'
                          ? 'SCANS PERFORMED / ஸ்கேன்கள் செய்யப்பட்டன'
                          : 'SCANS PERFORMED',
                      color: AppColors.accentDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Emergency Contacts header ─────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lang == 'ta'
                          ? 'Emergency Contacts / அவசர தொடர்புகள்'
                          : 'Emergency Contacts / அவசர தொடர்புகள்',
                      style: AppText.headlineSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: RkLabel.small(
                      lang == 'ta' ? 'EDIT / திருத்து' : 'EDIT / திருத்து',
                      color: AppColors.accentBright,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // ── PRIMARY contacts ──────────────────────────────────────
              RkLabel.small('PRIMARY', color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.xs),

              if (contacts.isEmpty) ...[
                _ContactCard(
                  name: 'Mom / அம்மா',
                  phone: '+91 8XXXX XXXXX',
                  gender: 'female',
                  lang: lang,
                ),
                const SizedBox(height: AppSpacing.xs),
                _ContactCard(
                  name: 'Dad / அப்பா',
                  phone: '+91 8XXXX XXXXX',
                  gender: 'male',
                  lang: lang,
                ),
              ] else ...[
                ...contacts
                    .where((c) =>
                        c.relationship.toLowerCase().contains('mother') ||
                        c.relationship.toLowerCase().contains('father') ||
                        c.relationship.toLowerCase().contains('primary'))
                    .map((c) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _ContactCard(
                            name: c.name,
                            phone: c.phone,
                            gender: c.relationship
                                    .toLowerCase()
                                    .contains('mother')
                                ? 'female'
                                : 'male',
                            lang: lang,
                          ),
                        )),
              ],

              const SizedBox(height: AppSpacing.md),

              // ── SECONDARY contacts ────────────────────────────────────
              RkLabel.small('SECONDARY', color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.xs),

              if (contacts.isEmpty) ...[
                _ContactCard(
                  name: 'Dad / அப்பா',
                  phone: '+91 8XXXX XXXXX',
                  gender: 'male',
                  lang: lang,
                ),
              ] else ...[
                ...contacts
                    .where((c) =>
                        !c.relationship.toLowerCase().contains('mother') &&
                        !c.relationship.toLowerCase().contains('father') &&
                        !c.relationship.toLowerCase().contains('primary'))
                    .map((c) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _ContactCard(
                            name: c.name,
                            phone: c.phone,
                            gender: 'male',
                            lang: lang,
                          ),
                        )),
              ],

              const SizedBox(height: AppSpacing.md),

              // ── OFFICIAL contact ──────────────────────────────────────
              RkLabel.small('OFFICIAL / அதிகாரி',
                  color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.xs),

              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.alertRed.withValues(alpha: 0.20),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_police_outlined,
                        color: AppColors.riskHigh, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'ta'
                                ? 'Police / காவல்துறை'
                                : 'Police / காவல்துறை',
                            style: AppText.bodyMedium
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Dial 100',
                            style: AppText.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/sos'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.alertRed,
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm),
                        ),
                        child: Text(
                          'SOS CALL',
                          style: AppText.labelSmallCaps.copyWith(
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formats a raw phone number for display.
/// - Strips leading +91 or 91 prefix if present
/// - Adds "+91 " prefix
/// - Inserts a space after the 5th digit: "+91 XXXXX XXXXX"
/// - Returns "Phone not set" if null or empty
String _formatPhone(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Phone not set';
  var digits = raw.trim().replaceAll(RegExp(r'\D'), '');
  // Strip country code
  if (digits.startsWith('91') && digits.length > 10) {
    digits = digits.substring(2);
  }
  if (digits.length == 10) {
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }
  // Already formatted or unknown format — just prepend +91 if missing
  if (raw.startsWith('+91')) return raw;
  return '+91 $raw';
}

// ── Contact card ──────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final String name;
  final String phone;
  final String gender;
  final String lang;

  const _ContactCard({
    required this.name,
    required this.phone,
    required this.gender,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            gender == 'female' ? Icons.female : Icons.male,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppText.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(phone, style: AppText.bodySmall),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                    color: AppColors.accentBright, width: 1),
              ),
              child: Text(
                'ALERT',
                style: AppText.labelSmallCaps.copyWith(
                  color: AppColors.accentBright,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
