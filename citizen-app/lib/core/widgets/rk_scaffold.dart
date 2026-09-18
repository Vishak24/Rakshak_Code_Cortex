import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Rakshak Scaffold — persistent bottom nav bar on all shell screens.
/// Judge Mode pull-tab is injected by JudgeModeOverlay at the router level.
///
/// Notch padding on web is handled globally in main.dart via MediaQuery,
/// so SafeArea on every screen automatically clears the CSS notch.
class RkScaffold extends StatelessWidget {
  final Widget body;
  final int currentIndex;
  final Function(int) onTabChanged;
  final String languageCode;

  const RkScaffold({
    super.key,
    required this.body,
    required this.currentIndex,
    required this.onTabChanged,
    this.languageCode = 'en',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // SafeArea applied here (top only) clears the Dynamic Island / notch for
      // every shell screen. bottom: false because the bottom nav bar carries its
      // own SafeArea(top: false) and Scaffold already insets the body above it.
      body: SafeArea(
        top: true,
        bottom: false,
        child: body,
      ),
      bottomNavigationBar: _RkBottomNav(
        currentIndex: currentIndex,
        onTap: onTabChanged,
        languageCode: languageCode,
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _RkBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String languageCode;

  const _RkBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.languageCode,
  });

  static const _items = [
    _NavItem(
      icon: Icons.shield_outlined,
      activeIcon: Icons.shield,
      labelEn: 'SENTINEL',
      labelTa: 'காவலன்',
    ),
    _NavItem(
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      labelEn: 'ALERTS',
      labelTa: 'எச்சரிக்கை',
    ),
    _NavItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      labelEn: 'MAP',
      labelTa: 'வரைபடம்',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      labelEn: 'PROFILE',
      labelTa: 'பயனர்',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.ghostBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // Teal top-border indicator on active tab
                      if (active)
                        Positioned(
                          top: 0,
                          left: 8,
                          right: 8,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.accentBright,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      // Icon + label
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              active ? item.activeIcon : item.icon,
                              size: AppSpacing.iconSize,
                              color: active
                                  ? AppColors.accentBright
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              languageCode == 'ta'
                                  ? item.labelTa
                                  : item.labelEn,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: active
                                    ? AppColors.accentBright
                                    : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String labelEn;
  final String labelTa;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.labelEn,
    required this.labelTa,
  });
}
