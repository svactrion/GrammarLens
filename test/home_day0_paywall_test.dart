import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/pending_climb.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import 'support/recording_analytics_sink.dart';

/// The paywall Home opens by itself, once, after the first-day climb
/// (`HomeScreen.offerDay0Paywall`): when it appears, when it must not, and that
/// it can never appear twice.
class _FakeSubscriptionService extends SubscriptionService {
  bool hasAccess = false;

  @override
  Future<bool> get hasFullAccess async => hasAccess;

  @override
  void addAccessListener(AccessListener listener) {}

  @override
  void removeAccessListener(AccessListener listener) {}
}

class _FakeStorageService extends StorageService {
  int steps = 1;

  /// Flags already claimed, like the stored table.
  final Set<String> claimed = {};
  int claimCalls = 0;

  /// Makes the flag unreadable.
  bool failClaim = false;

  /// Called at the moment of a claim, to observe what is on screen then.
  void Function()? onClaim;

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: steps, correct: 0, wrong: 0, skipped: 0);

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => null;

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async =>
      const [];

  @override
  Future<UserProfile?> getUserProfile() async => null;

  @override
  Future<bool> claimOneTimeFlag(String key) async {
    claimCalls++;
    onClaim?.call();
    if (failClaim) throw StateError('database unreadable');
    return claimed.add(key);
  }
}

void main() {
  late _FakeStorageService storage;
  late _FakeSubscriptionService subscription;
  late RecordingAnalyticsSink sink;

  setUp(() {
    storage = _FakeStorageService();
    subscription = _FakeSubscriptionService();
    sink = RecordingAnalyticsSink();
  });

  const pendingStep = (day: '2026-01-01', step: 1);
  final premium = find.byType(PremiumScreen);
  final mountain = find.byType(MonthlyMountain);

  Future<void> pumpHome(
    WidgetTester tester, {
    bool offer = true,
    PendingClimb? pending = pendingStep,
    bool active = true,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: HomeScreen(
        active: active,
        userName: 'Ada',
        storageService: storage,
        claudeService: ClaudeService(),
        analyticsService: AnalyticsService(sink: sink),
        subscriptionService: subscription,
        initialPendingClimb: pending,
        offerDay0Paywall: offer,
        clock: () => DateTime(2026, 1, 1, 9),
      ),
    ));
  }

  /// Pumps 25 ms frames until [done], returning the time that took. Fails if
  /// it never happens within [limit].
  Future<Duration> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    Duration limit = const Duration(seconds: 10),
  }) async {
    var elapsed = Duration.zero;
    while (!done()) {
      if (elapsed >= limit) fail('did not happen within $limit');
      await tester.pump(const Duration(milliseconds: 25));
      elapsed += const Duration(milliseconds: 25);
    }
    return elapsed;
  }

  bool stepShown(WidgetTester tester) =>
      mountain.evaluate().isNotEmpty &&
      tester.widget<MonthlyMountain>(mountain).completedDays == 1;

  bool premiumShown() => premium.evaluate().isNotEmpty;

  /// Pumps for [duration], failing the moment the paywall appears.
  Future<void> expectNoPremiumFor(
      WidgetTester tester, Duration duration) async {
    var elapsed = Duration.zero;
    while (elapsed < duration) {
      await tester.pump(const Duration(milliseconds: 25));
      elapsed += const Duration(milliseconds: 25);
      expect(premiumShown(), isFalse, reason: 'shown at $elapsed');
    }
  }

  group('when there is a step to climb', () {
    testWidgets(
        'it opens 600 ms after the climb animation ends: 850 ms of animation, '
        'then the pawn stands for 600 ms', (tester) async {
      await pumpHome(tester);

      await pumpUntil(tester, () => stepShown(tester));
      expect(premiumShown(), isFalse);
      final sinceStep = await pumpUntil(tester, premiumShown);

      expect(sinceStep.inMilliseconds, inInclusiveRange(1450, 1600));
      expect(tester.widget<MonthlyMountain>(mountain).completedDays, 1);
    });

    testWidgets('reduced motion: no animation, so 600 ms after the step',
        (tester) async {
      await pumpHome(tester, reduceMotion: true);

      await pumpUntil(tester, () => stepShown(tester));
      final sinceStep = await pumpUntil(tester, premiumShown);

      expect(sinceStep.inMilliseconds, inInclusiveRange(575, 700));
    });

    testWidgets(
        'a reload while the pawn is still climbing (a resume) does not open '
        'it early', (tester) async {
      await pumpHome(tester);
      await pumpUntil(tester, () => stepShown(tester));
      await tester.pump(const Duration(milliseconds: 300));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await expectNoPremiumFor(tester, const Duration(milliseconds: 1000));

      await pumpUntil(tester, premiumShown);
    });

    testWidgets(
        'covered by another route when it is due: it waits, and opens when '
        'Home is visible again', (tester) async {
      await pumpHome(tester);
      await pumpUntil(tester, () => stepShown(tester));
      await tester.pump(const Duration(milliseconds: 900)); // the climb is done
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('covering route')),
      ));

      await expectNoPremiumFor(tester, const Duration(seconds: 3));
      expect(find.text('covering route'), findsOneWidget);
      expect(storage.claimCalls, 0);

      navigator.pop();
      await pumpUntil(tester, premiumShown, limit: const Duration(seconds: 3));
      expect(storage.claimCalls, 1);
    });

    testWidgets(
        'on a tab that is not active it waits: nothing climbs and nothing '
        'opens until Home is the tab shown', (tester) async {
      await pumpHome(tester, active: false);
      await expectNoPremiumFor(tester, const Duration(seconds: 3));
      expect(storage.claimCalls, 0);

      await pumpHome(tester, active: true);
      await pumpUntil(tester, () => stepShown(tester));
      await pumpUntil(tester, premiumShown, limit: const Duration(seconds: 4));
      expect(storage.claimCalls, 1);
    });
  });

  group('when there is no step', () {
    testWidgets('it opens once Home has loaded, without the 600 ms pause',
        (tester) async {
      await pumpHome(tester, pending: null);

      final elapsed = await pumpUntil(tester, premiumShown);

      expect(elapsed.inMilliseconds, lessThan(400));
    });

    testWidgets(
        'a step that belongs to another month animates nothing, and the '
        'paywall still opens', (tester) async {
      // The step's day is December; Home reads January.
      await pumpHome(tester, pending: (day: '2025-12-31', step: 1));

      await pumpUntil(tester, premiumShown, limit: const Duration(seconds: 3));
    });
  });

  group('when it must not open', () {
    testWidgets('the user did not finish the Day-0 test (not offered)',
        (tester) async {
      await pumpHome(tester, offer: false);

      await expectNoPremiumFor(tester, const Duration(seconds: 5));
      expect(storage.claimCalls, 0);
    });

    testWidgets('the user already has full access: never, and no flag is used',
        (tester) async {
      subscription.hasAccess = true;
      await pumpHome(tester);

      await expectNoPremiumFor(tester, const Duration(seconds: 5));
      expect(storage.claimCalls, 0);
      expect(storage.claimed, isEmpty);
    });

    testWidgets('the flag was already claimed (a shown-before install)',
        (tester) async {
      storage.claimed.add(StorageService.day0PaywallFlag);
      await pumpHome(tester);

      await expectNoPremiumFor(tester, const Duration(seconds: 5));
      expect(storage.claimCalls, 1);
    });

    testWidgets(
        'the flag cannot be read: it is not shown, nothing is thrown, and it '
        'is not retried', (tester) async {
      storage.failClaim = true;
      await pumpHome(tester);

      await expectNoPremiumFor(tester, const Duration(seconds: 4));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await expectNoPremiumFor(tester, const Duration(seconds: 2));

      expect(storage.claimCalls, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('once', () {
    testWidgets(
        'the flag is claimed before the paywall is pushed, so an app closed '
        'on it still counts as shown', (tester) async {
      var pushedAtClaim = true;
      await pumpHome(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      // A pushed route is in the navigator's history at once, before any frame
      // builds it, so this sees a push that happens ahead of the claim.
      storage.onClaim = () => pushedAtClaim = navigator.canPop();

      await pumpUntil(tester, premiumShown);

      expect(pushedAtClaim, isFalse);
      expect(storage.claimed, {StorageService.day0PaywallFlag});
    });

    testWidgets(
        'dismissed with Maybe later: Home is back, and nothing brings it '
        'back (a resume, more time)', (tester) async {
      await pumpHome(tester);
      await pumpUntil(tester, premiumShown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maybe later'));
      await tester.pumpAndSettle();
      expect(premiumShown(), isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await expectNoPremiumFor(tester, const Duration(seconds: 5));
      expect(storage.claimCalls, 1);
    });

    testWidgets(
        'a second Home built later (a new launch offering it again) finds the '
        'flag claimed and does not show it', (tester) async {
      await pumpHome(tester);
      await pumpUntil(tester, premiumShown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maybe later'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await pumpHome(tester);
      await expectNoPremiumFor(tester, const Duration(seconds: 5));

      expect(storage.claimCalls, 2);
    });
  });

  group('analytics', () {
    testWidgets(
        'paywall_viewed carries the new source, and no mode_selected is '
        'sent for an automatic opening', (tester) async {
      await pumpHome(tester);
      await pumpUntil(tester, premiumShown);
      await tester.pumpAndSettle();

      expect(sink.named('paywall_viewed').single.parameters,
          {'source': 'day0_after_climb'});
      expect(sink.named('mode_selected'), isEmpty);
    });

    testWidgets('dismissing it reports the same source', (tester) async {
      await pumpHome(tester);
      await pumpUntil(tester, premiumShown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maybe later'));
      await tester.pumpAndSettle();

      expect(sink.named('paywall_dismissed').single.parameters,
          {'source': 'day0_after_climb', 'method': 'maybe_later'});
    });

    testWidgets(
        'a user tap on Home\'s Premium entry still reports source home and '
        'mode_selected', (tester) async {
      await pumpHome(tester, offer: false, pending: null);
      await tester.pumpAndSettle();
      final row = find.textContaining('Premium').first;
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();

      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(premiumShown(), isTrue);
      expect(sink.named('mode_selected').single.parameters, {'mode': 'premium'});
      expect(sink.named('paywall_viewed').single.parameters, {'source': 'home'});
    });
  });
}
