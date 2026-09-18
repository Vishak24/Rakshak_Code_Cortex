import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:rakshak/core/models/risk_score.dart';
import 'package:rakshak/core/theme/app_theme.dart';
import 'package:rakshak/features/auth/presentation/login_screen.dart';
import 'package:rakshak/features/sentinel/presentation/sentinel_controller.dart';
import 'package:rakshak/features/sentinel/presentation/sentinel_screen.dart';
import 'package:rakshak/features/intelligence/presentation/intelligence_screen.dart';
import 'package:rakshak/features/intelligence/presentation/score_screen.dart';
import 'package:rakshak/features/sos/presentation/sos_screen.dart';

import 'helpers/fake_services.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp({
    String initial = '/',
    List<Override> overrides = const [],
  }) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/sentinel', builder: (_, __) => const SentinelScreen()),
        GoRoute(
          path: '/intelligence',
          builder: (_, __) => const IntelligenceScreen(),
        ),
        GoRoute(path: '/score', builder: (_, __) => const ScoreScreen()),
        GoRoute(path: '/sos', builder: (_, __) => const SosScreen()),
      ],
    );

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    );
  }

  // Pumps enough frames for screens with repeating animations (pulse, timers).
  Future<void> pumpSentinel(WidgetTester tester) async {
    await tester.pump();
    await Future.delayed(const Duration(milliseconds: 200));
    await tester.pump();
  }

  // ── Test 1: Login → Sentinel navigation ────────────────────────────────────

  testWidgets('login with phone number navigates to sentinel screen',
      (tester) async {
    await tester.pumpWidget(buildApp(initial: '/'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '9876543210');
    await tester.pump();

    await tester.tap(find.textContaining('›'));
    await tester.pump();

    // Login has an 800ms simulated delay
    await Future.delayed(const Duration(milliseconds: 1000));
    await pumpSentinel(tester);

    expect(find.text('RAKSHAK'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
  });

  // ── Test 2: HIGH risk score → CRITICAL chip ────────────────────────────────

  testWidgets('risk score 78 shows CRITICAL status chip', (tester) async {
    final highScore = RiskScore(
      score: 78,
      level: RiskLevel.high,
      location: 'T. Nagar',
      timestamp: DateTime.now(),
      factors: ['High incident density'],
    );

    await tester.pumpWidget(buildApp(
      initial: '/sentinel',
      overrides: [
        sentinelServiceProvider.overrideWithValue(FakeSentinelService(highScore)),
      ],
    ));

    await pumpSentinel(tester);

    expect(find.text('78'), findsOneWidget);
    expect(find.text('CRITICAL'), findsOneWidget);
  });

  // ── Test 3: MEDIUM risk score → ELEVATED chip ──────────────────────────────

  testWidgets('risk score 55 shows ELEVATED status chip', (tester) async {
    final medScore = RiskScore(
      score: 55,
      level: RiskLevel.medium,
      location: 'T. Nagar',
      timestamp: DateTime.now(),
      factors: ['Moderate activity'],
    );

    await tester.pumpWidget(buildApp(
      initial: '/sentinel',
      overrides: [
        sentinelServiceProvider.overrideWithValue(FakeSentinelService(medScore)),
      ],
    ));

    await pumpSentinel(tester);

    expect(find.text('55'), findsOneWidget);
    expect(find.text('ELEVATED'), findsOneWidget);
  });

  // ── Test 4: Intelligence scan advances through all steps → score screen ────

  testWidgets('intelligence scan completes and shows score screen',
      (tester) async {
    await tester.pumpWidget(buildApp(initial: '/intelligence'));
    await tester.pump();

    // Step 1 completes at 1.2s
    await Future.delayed(const Duration(milliseconds: 1300));
    await tester.pump();
    expect(find.text('Scanning location...'), findsOneWidget);

    // Step 2 completes at 2.5s
    await Future.delayed(const Duration(milliseconds: 1300));
    await tester.pump();
    expect(find.text('Analyzing history...'), findsOneWidget);

    // Step 3 + nav fires at ~4.5s total
    await Future.delayed(const Duration(milliseconds: 1800));
    await tester.pump();
    await tester.pump();

    // Score screen shows hardcoded stub score 78
    expect(find.text('78'), findsOneWidget);
    expect(find.text('HIGH RISK'), findsOneWidget);
  });

  // ── Test 5: SOS phase 1 → phase 2 → dismiss → sentinel ────────────────────

  testWidgets('SOS transitions from phase1 to phase2 then dismisses',
      (tester) async {
    await tester.pumpWidget(buildApp(initial: '/sos'));
    await tester.pump();
    await Future.delayed(const Duration(milliseconds: 200));
    await tester.pump();

    // Phase 1: red background with "Contacting Emergency Services…"
    expect(
      find.text('Contacting Emergency Services...'),
      findsOneWidget,
    );

    // Phase 2 transitions at 3s
    await Future.delayed(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('STATUS: SECURED'), findsOneWidget);
    expect(find.text('Help is on the way'), findsOneWidget);

    // Dismiss navigates back to sentinel
    await tester.tap(find.text('Dismiss Alert'));
    await pumpSentinel(tester);

    expect(find.text('SOS'), findsOneWidget);
  });

  // ── Test 6: Service error → score shows '--' and chip shows 'UNKNOWN' ──────

  testWidgets('network error shows placeholder score and UNKNOWN chip',
      (tester) async {
    await tester.pumpWidget(buildApp(
      initial: '/sentinel',
      overrides: [
        sentinelServiceProvider
            .overrideWithValue(const ThrowingSentinelService()),
      ],
    ));

    await pumpSentinel(tester);

    expect(find.text('--'), findsOneWidget);
    expect(find.text('UNKNOWN'), findsOneWidget);
  });
}
