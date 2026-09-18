import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/sentinel/presentation/sentinel_screen.dart';
import '../../features/sentinel/presentation/night_watch_overlay.dart';
import '../../features/alerts/presentation/alerts_stub_screen.dart';
import '../../features/map/presentation/map_stub_screen.dart';
import '../../features/user_space/presentation/user_space_screen.dart';
import '../../features/intelligence/presentation/intelligence_screen.dart';
import '../../features/intelligence/presentation/score_screen.dart';
import '../../features/sos/presentation/sos_screen.dart';
import '../widgets/rk_scaffold.dart';
import '../widgets/judge_mode_overlay.dart';
import '../../core/providers/settings_provider.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    // Login — no shell, no Judge Mode
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),

    // Shell — bottom nav + Judge Mode overlay
    ShellRoute(
      builder: (context, state, child) =>
          _ShellWithJudgeMode(child: child, routerState: state),
      routes: [
        GoRoute(
          path: '/sentinel',
          builder: (context, state) => const SentinelScreen(),
        ),
        GoRoute(
          path: '/alerts',
          builder: (context, state) => const AlertsStubScreen(),
        ),
        GoRoute(
          path: '/map',
          builder: (context, state) => const MapStubScreen(),
        ),
        GoRoute(
          path: '/user-space',
          builder: (context, state) => const UserSpaceScreen(),
        ),
      ],
    ),

    // Fullscreen routes — Judge Mode overlay, no bottom nav
    GoRoute(
      path: '/intelligence',
      builder: (context, state) => JudgeModeOverlay(
        child: const IntelligenceScreen(),
      ),
    ),
    GoRoute(
      path: '/score',
      builder: (context, state) => JudgeModeOverlay(
        child: const ScoreScreen(),
      ),
    ),
    GoRoute(
      path: '/night-watch',
      builder: (context, state) => const Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          top: true,
          bottom: false,
          child: NightWatchOverlay(),
        ),
      ),
    ),
    GoRoute(
      path: '/sos',
      builder: (context, state) => const SosScreen(),
    ),
  ],
);

// ── Shell wrapper ─────────────────────────────────────────────────────────────

class _ShellWithJudgeMode extends ConsumerWidget {
  final Widget child;
  final GoRouterState routerState;

  const _ShellWithJudgeMode(
      {required this.child, required this.routerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).languageCode;
    final currentTab = _tabIndex(routerState.uri.toString());

    return JudgeModeOverlay(
      child: RkScaffold(
        body: child,
        currentIndex: currentTab,
        languageCode: lang,
        onTabChanged: (i) => GoRouter.of(context).go(_tabRoute(i)),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

int _tabIndex(String path) {
  if (path.contains('/alerts')) return 1;
  if (path.contains('/map')) return 2;
  if (path.contains('/user-space')) return 3;
  return 0;
}

String _tabRoute(int i) {
  switch (i) {
    case 1:
      return '/alerts';
    case 2:
      return '/map';
    case 3:
      return '/user-space';
    default:
      return '/sentinel';
  }
}
