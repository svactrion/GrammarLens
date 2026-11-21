import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../data/topics.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/daily_test_question.dart';
import '../models/daily_test_set.dart';
import '../motion.dart';
import '../services/analytics_service.dart';
import '../services/daily_test_grading.dart';
import '../services/daily_test_service.dart';
import '../theme.dart';
import '../utils/content_width.dart';
import '../utils/debug_tools.dart';
import '../utils/haptics.dart';
import '../utils/loading_view.dart';
import '../widgets/companion_dialog.dart';
import '../widgets/companion_view.dart';
import '../widgets/error_state.dart';
import '../widgets/pressable_button.dart';
import '../widgets/question_view.dart';
import '../widgets/speech_bubble.dart';
import '../widgets/step_bar.dart';
import '../widgets/topic_hint_card.dart';
import 'daily_test_result_screen.dart';

/// One question at a time over today's Daily Test set (PRD v2 §12.2), with
/// per-question feedback (UI polish §1.5, V07–V09, Q04, Q05): "Check"
/// grades the answer on the device against the set's own key
/// ([QuestionCheck]: the existing matching rules, no request, no wait);
/// a sheet says right or "Almost!" with the correct answer and the set's
/// explanation; the points shown are display-only and equal what the
/// completion awards. The answers are saved, and the points and weak spots
/// written, at the end as before (the result screen).
///
/// Skip stays (a skipped question is not wrong). A checked answer is final.
class DailyTestScreen extends StatefulWidget {
  final DailyTestService dailyTestService;
  final AnalyticsService analyticsService;

  /// Called with the finished set + answers instead of the default
  /// pushReplacement-to-results navigation, when non-null (the Day-0
  /// first-launch flow, see `first_launch_flow.dart`).
  final void Function(DailyTestSet, Map<String, String>)? onFinished;

  /// Called instead of popping when the user leaves (the Day-0 flow).
  final VoidCallback? onExit;

  /// The user's buddy and name, for the companion and "Nice, <name>!".
  final Avatar? hero;
  final String? userName;

  const DailyTestScreen({
    super.key,
    required this.dailyTestService,
    required this.analyticsService,
    this.onFinished,
    this.onExit,
    this.hero,
    this.userName,
  });

  static const checkKey = ValueKey('daily_test_check');
  static const skipKey = ValueKey('daily_test_skip');
  static const continueKey = ValueKey('daily_test_continue');
  static const closeKey = ValueKey('daily_test_close');
  static const pointsKey = ValueKey('daily_test_points');
  static const leaveKey = ValueKey('daily_test_leave');
  static const keepGoingKey = ValueKey('daily_test_keep_going');

  /// The part under the question before "Check" (the buddy, Skip, Check).
  static const footerKey = ValueKey('daily_test_footer');

  /// V09: the book icon flying from "This goes to your weak spots" to the
  /// Review tab's place in the nav bar.
  static const bookFlightKey = ValueKey('daily_test_book_flight');

  @override
  State<DailyTestScreen> createState() => _DailyTestScreenState();
}

class _DailyTestScreenState extends State<DailyTestScreen> {
  final Map<String, String> _answers = {};
  final Map<String, QuestionCheck> _checks = {};
  AnswerDrafts? _drafts;
  DailyTestSet? _dailyTestSet;
  bool _loading = true;
  Object? _error;
  int _currentIndex = 0;
  bool _finishing = false;

  /// The points chip's count: rises when the "+N" star lands.
  int _shownPoints = 0;

  /// A "+N" star flying into the chip (V08), by question.
  int? _flying;

  /// V09: a book flying to the Review tab, by question; where it starts
  /// (the weak spots line's icon) and the page it flies over.
  int? _bookFlying;
  final _bookIconKey = GlobalKey();
  final _pageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Avatar get _hero => widget.hero ?? Avatar.fox;

  Future<bool> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dailyTestSet = await widget.dailyTestService.getTodaysSet();
      if (!mounted) return true;
      setState(() {
        _dailyTestSet = dailyTestSet;
        _drafts?.dispose();
        _drafts = AnswerDrafts.items(dailyTestSet.questions.map((q) => q.item));
        _loading = false;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _loading = false;
        _error = e;
      });
      return false;
    }
  }

  void _leave() {
    if (widget.onExit != null) {
      widget.onExit!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _drafts?.dispose();
    super.dispose();
  }

  List<DailyTestQuestion> get _questions => _dailyTestSet!.questions;
  DailyTestQuestion get _current => _questions[_currentIndex];
  bool get _isLastQuestion => _currentIndex == _questions.length - 1;
  QuestionCheck? get _currentCheck => _checks[_current.item.id];

  bool get _currentHasAnswer => _drafts!.isComplete(_current.item.id);

  void _showQuestion(int index) {
    _drafts!.leave(_questions[_currentIndex].item.id,
        nextId: _questions[index].item.id);
    setState(() => _currentIndex = index);
    _drafts!.restore(_questions[index].item.id);
  }

  void _advance() {
    if (_finishing) return;
    if (_isLastQuestion) {
      _finish();
    } else {
      _showQuestion(_currentIndex + 1);
    }
  }

  void _finish() {
    _finishing = true;
    _drafts?.unfocus();
    if (widget.onFinished != null) {
      widget.onFinished!(_dailyTestSet!, Map.of(_answers));
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DailyTestResultScreen(
          dailyTestSet: _dailyTestSet!,
          answers: Map.of(_answers),
          dailyTestService: widget.dailyTestService,
          analyticsService: widget.analyticsService,
          hero: widget.hero,
          userName: widget.userName,
        ),
      ),
    );
  }

  void _skip() {
    if (_finishing || _currentCheck != null) return;
    final item = _current.item;
    _drafts!.clear(item.id);
    setState(() => _answers.remove(item.id));
    _advance();
  }

  /// "Check": grades the answer on the device and shows the sheet.
  void _check() {
    if (_finishing || _currentCheck != null || !_currentHasAnswer) return;
    final question = _current;
    final answer = _drafts!.answerFor(question.item);
    final boxes = _drafts!.boxCount(question.item.id) > 1
        ? _drafts!.blankAnswers(question.item.id)
        : null;
    final check = QuestionCheck.of(question, answer, blankAnswers: boxes);
    _drafts!.unfocus();
    setState(() {
      _answers[question.item.id] = answer;
      _checks[question.item.id] = check;
      _flying = _currentIndex;
      if (!check.isCorrect && !AppMotion.reduced(context)) {
        _bookFlying = _currentIndex;
      }
    });
    if (check.isCorrect) {
      HapticMap.success();
    } else if (check.blanks?.contains(true) ?? false) {
      // Q04: partly right — two light taps.
      HapticMap.lightTwice();
    } else {
      HapticMap.warning();
    }
    // Reduce Motion: no flight, the chip counts at once.
    if (AppMotion.reduced(context)) {
      setState(() {
        _shownPoints += check.points;
        _flying = null;
      });
    }
  }

  /// The star landed in the chip: the count rises.
  void _starLanded(int points) {
    if (!mounted) return;
    setState(() {
      _shownPoints += points;
      _flying = null;
    });
  }

  Future<void> _confirmExit() async {
    final answered = _checks.length;
    final total = _dailyTestSet?.questions.length ?? DailyTestSet.questionCount;
    final result = await showCompanionDialog(
      context: context,
      hero: _hero,
      title: context.l10n.dailyTestLeaveTitle,
      body: context.l10n.leaveProgressBody(answered, total),
      primaryLabel: context.l10n.leaveKeepGoing,
      secondaryLabel: context.l10n.commonLeave,
      primaryKey: DailyTestScreen.keepGoingKey,
      secondaryKey: DailyTestScreen.leaveKey,
    );
    if (result == CompanionDialogResult.secondary && mounted) {
      _leave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final hPad =
        ContentWidth.sidePaddingOf(context, base: width < 360 ? 14 : 16);
    final set = _dailyTestSet;
    final showQuestion = !_loading && _error == null && set != null;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: c.page,
        body: SafeArea(
          bottom: false,
          child: Stack(
            key: _pageKey,
            children: [
              Column(
                children: [
                  _Header(
                    horizontalPadding: hPad,
                    segments: showQuestion
                        ? [
                            for (final q in set.questions)
                              switch (_checks[q.item.id]) {
                                null => null,
                                final check =>
                                  check.isCorrect ? c.green : c.wrong,
                              },
                          ]
                        : List.filled(DailyTestSet.questionCount, null),
                    current: showQuestion ? _currentIndex : null,
                    points: _shownPoints,
                    onClose: _confirmExit,
                  ),
                  Expanded(
                    child: _loading
                        ? LoadingView(message: context.l10n.dailyTestPreparing)
                        : _error != null
                            ? _buildError()
                            : _buildQuestion(hPad),
                  ),
                  if (showQuestion)
                    AnimatedSwitcher(
                      duration: AppMotion.entrance(context, AppMotion.sheet),
                      switchInCurve: AppMotion.spring,
                      transitionBuilder: (child, animation) => SlideTransition(
                        position:
                            Tween(begin: const Offset(0, 1), end: Offset.zero)
                                .animate(animation),
                        child: child,
                      ),
                      child: _currentCheck == null
                          ? _CheckFooter(
                              key: ValueKey('footer_$_currentIndex'),
                              hero: _hero,
                              horizontalPadding: hPad,
                              hasAnswer: _currentHasAnswer,
                              // The buddy's row needs room: not with the
                              // keyboard up, not on a short phone (the open
                              // hint card must stay whole above the bar).
                              showCompanion: !keyboard &&
                                  MediaQuery.sizeOf(context).height >= 740,
                              last: _isLastQuestion,
                              onCheck: _check,
                              onSkip: _skip,
                            )
                          : _FeedbackPanel(
                              key: ValueKey('panel_$_currentIndex'),
                              check: _currentCheck!,
                              hero: _hero,
                              name: widget.userName,
                              last: _isLastQuestion,
                              horizontalPadding: hPad,
                              bookKey: _bookIconKey,
                              onContinue: _advance,
                            ),
                    ),
                ],
              ),
              if (_bookFlying != null)
                _BookFlight(
                  key: ValueKey('book_$_bookFlying'),
                  from: _bookIconKey,
                  page: _pageKey,
                  onEnd: () {
                    if (mounted) setState(() => _bookFlying = null);
                  },
                ),
              if (_flying != null && !AppMotion.reduced(context))
                _FlyingStar(
                  key: ValueKey('star_$_flying'),
                  onLanded: () => _starLanded(
                      _checks[_questions[_flying!].item.id]?.points ?? 0),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ErrorState(
              hero: _hero,
              title: context.l10n.dailyTestLoadFailedTitle,
              message: context.l10n.dailyTestLoadFailedBody,
              onRetry: _load,
            ),
            if (kDebugMode && DebugTools.enabledForTesting)
              Text('$_error', // l10n-guard: debug only
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  bool _showTopicHint(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= TopicHintSlider.minScreenWidth;

  Widget _buildQuestion(double hPad) {
    final question = _current;
    final item = question.item;
    final check = _checks[item.id];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: QuestionView(
        item: item,
        index: _currentIndex,
        total: _questions.length,
        topic: topicByName(question.topicId),
        showTopicHint: _showTopicHint(context),
        drafts: _drafts!,
        horizontalPadding: hPad,
        grade: check == null
            ? null
            : AnswerGrade(correct: check.isCorrect, blanks: check.blanks),
        onChanged: (value) => setState(() => _answers[item.id] = value),
      ),
    );
  }
}

/// The test's top line (V07): close, the five segments (green right,
/// orange wrong, the current one orange-tinted), the points chip.
class _Header extends StatelessWidget {
  final double horizontalPadding;
  final List<Color?> segments;
  final int? current;
  final int points;
  final VoidCallback onClose;

  const _Header({
    required this.horizontalPadding,
    required this.segments,
    required this.current,
    required this.points,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding:
          EdgeInsets.fromLTRB(horizontalPadding - 8, 6, horizontalPadding, 6),
      child: Row(
        children: [
          IconButton(
            key: DailyTestScreen.closeKey,
            tooltip: context.l10n.dailyTestLeaveTooltip,
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: c.text),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              label: current == null
                  ? null
                  : context.l10n
                      .questionProgressSemantics(current! + 1, segments.length),
              child: StepBar(
                segments: segments,
                track: c.track,
                height: 10,
                gap: 6,
                highlight: current,
                highlightColor: c.orange,
              ),
            ),
          ),
          const SizedBox(width: 12),
          PointsChip(key: DailyTestScreen.pointsKey, points: points),
        ],
      ),
    );
  }
}

/// The points chip with the clay star (V07, V14's "+N").
class PointsChip extends StatelessWidget {
  final int points;
  final String? prefix;
  const PointsChip({super.key, required this.points, this.prefix});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      label: context.l10n.pointsChipSemantics(points),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 10, 4),
        decoration: BoxDecoration(
          color: c.goldSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/ui/points_star.webp',
              width: 22, height: 22, excludeFromSemantics: true),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: AppMotion.orInstant(context, AppMotion.fast),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: Text(
              '${prefix ?? ''}$points', // l10n-guard: a number
              key: ValueKey(points),
              textScaler: TextScaler.noScaling,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge!
                  .withWeight(FontWeight.w900)
                  .copyWith(color: c.goldText, fontSize: 15),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Below the question before "Check": the buddy (with "Looks good! Tap
/// Check." once there is an answer), Skip and Check ("Finish" on the last
/// question).
class _CheckFooter extends StatelessWidget {
  final Avatar hero;
  final double horizontalPadding;
  final bool hasAnswer;
  final bool showCompanion;
  final bool last;
  final VoidCallback onCheck;
  final VoidCallback onSkip;

  const _CheckFooter({
    super.key,
    required this.hero,
    required this.horizontalPadding,
    required this.hasAnswer,
    required this.showCompanion,
    required this.last,
    required this.onCheck,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      key: DailyTestScreen.footerKey,
      top: false,
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 2, horizontalPadding, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showCompanion)
              SizedBox(
                height: 84,
                child: Row(children: [
                  CompanionView(
                    hero: hero,
                    mood: hasAnswer ? CompanionMood.cheer : CompanionMood.idle,
                    size: 72,
                  ),
                  const SizedBox(width: 10),
                  if (hasAnswer)
                    Flexible(
                      child: SpeechBubble(
                        text: l10n.checkLooksGood,
                        pointer: BubblePointer.start,
                        compact: true,
                      ),
                    ),
                ]),
              ),
            Row(
              children: [
                PressableButton(
                  key: DailyTestScreen.skipKey,
                  label: l10n.questionSkip,
                  tone: ButtonTone.text,
                  expand: false,
                  height: 52,
                  haptic: ButtonHaptic.light,
                  onPressed: onSkip,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PressableButton(
                    key: DailyTestScreen.checkKey,
                    label: last ? l10n.questionFinish : l10n.checkButton,
                    tone: ButtonTone.orange,
                    // SPEC §3.4 v12: Check's (and the last question's
                    // Finish, which checks too) right / wrong feedback is
                    // its haptic; the button adds none.
                    haptic: ButtonHaptic.none,
                    onPressed: hasAnswer ? onCheck : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The sheet after "Check" (V08 / V09): right — "Nice, <name>!", +2, the
/// set's explanation (or the correct answer), green Continue; wrong —
/// "Almost!", +1, the correct answer and why, "This goes to your weak
/// spots", red "Got it". The buddy cheers or says "Oops! So close."
class _FeedbackPanel extends StatelessWidget {
  final QuestionCheck check;
  final Avatar hero;
  final String? name;
  final bool last;
  final double horizontalPadding;

  /// The weak spots line's book icon: where V09's book flight starts.
  final Key? bookKey;
  final VoidCallback onContinue;

  const _FeedbackPanel({
    super.key,
    required this.check,
    required this.hero,
    required this.name,
    required this.last,
    required this.horizontalPadding,
    this.bookKey,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final right = check.isCorrect;
    final fg = right ? c.greenText : c.redText;
    final title = right
        ? (name == null || name!.isEmpty
            ? l10n.checkNice
            : l10n.checkNiceName(name!))
        : l10n.checkAlmost;
    final explanation = check.explanation;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: right ? c.greenSoft : c.redSoft,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              horizontalPadding + 4, 18, horizontalPadding + 4, 0),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _Pop(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration:
                            BoxDecoration(color: fg, shape: BoxShape.circle),
                        child: Icon(
                            right ? Icons.check_rounded : Icons.close_rounded,
                            color: c.onNavy,
                            size: 26),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          title,
                          style: theme.textTheme.headlineSmall!
                              .withWeight(FontWeight.w900)
                              .copyWith(color: fg, letterSpacing: -.5),
                        ),
                      ),
                    ),
                    PointsChip(points: check.points, prefix: '+'),
                  ]),
                  const SizedBox(height: 10),
                  if (!right) ...[
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(l10n.checkCorrectAnswer,
                            style: theme.textTheme.bodyLarge!
                                .withWeight(FontWeight.w800)
                                .copyWith(color: c.text)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.greenSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(check.correctAnswer,
                              style: theme.textTheme.bodyLarge!
                                  .withWeight(FontWeight.w900)
                                  .copyWith(color: c.greenText)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (explanation != null)
                    Text(
                      explanation,
                      style: theme.textTheme.bodyLarge!
                          .withWeight(right ? FontWeight.w800 : FontWeight.w400)
                          .copyWith(color: right ? c.greenText : c.text),
                    )
                  else if (right)
                    Text(check.correctAnswer,
                        style: theme.textTheme.bodyLarge!
                            .withWeight(FontWeight.w800)
                            .copyWith(color: c.greenText)),
                  if (!right) ...[
                    const SizedBox(height: 10),
                    _Pop(
                      delay: const Duration(milliseconds: 250),
                      child: Row(children: [
                        Icon(Icons.menu_book_outlined,
                            key: bookKey, size: 18, color: c.navyText),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(l10n.checkGoesToWeakSpots,
                              style: theme.textTheme.labelLarge!
                                  .withWeight(FontWeight.w800)
                                  .copyWith(color: c.navyText)),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 14),
                  PressableButton(
                    key: DailyTestScreen.continueKey,
                    label: last
                        ? l10n.checkSeeResults
                        : (right ? l10n.commonContinue : l10n.checkGotIt),
                    tone: right ? ButtonTone.green : ButtonTone.red,
                    haptic: ButtonHaptic.light,
                    onPressed: onContinue,
                  ),
                ],
              ),
            ),
          ),
        ),
        PositionedDirectional(
          end: horizontalPadding,
          top: -96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!right)
                SpeechBubble(
                  text: l10n.checkOops,
                  pointer: BubblePointer.none,
                  compact: true,
                ),
              const SizedBox(width: 6),
              CompanionView(
                hero: hero,
                mood: right ? CompanionMood.cheer : CompanionMood.oops,
                size: 88,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pops in (easeOutBack) after [delay].
class _Pop extends StatelessWidget {
  final Widget child;
  final Duration delay;
  const _Pop({required this.child, this.delay = Duration.zero});

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    final total = delay + const Duration(milliseconds: 500);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1,
          curve: AppMotion.pop),
      builder: (context, t, child) => Transform.scale(scale: t, child: child),
      child: child,
    );
  }
}

/// V09: once the weak spots line has popped in, its book icon flies to the
/// Review tab's place in the nav bar (500 ms): down to the middle of the
/// bottom edge, where the bar's middle tab sits under this full-screen
/// test. It grows a little, then shrinks and fades as it arrives. Not built
/// under Reduce Motion. Nothing is drawn if the line is gone (the user
/// went on).
class _BookFlight extends StatelessWidget {
  final GlobalKey from;
  final GlobalKey page;
  final VoidCallback onEnd;
  const _BookFlight(
      {super.key, required this.from, required this.page, required this.onEnd});

  /// After the line's pop (250 ms delay, then about 350 ms to settle).
  static const delay = Duration(milliseconds: 600);
  static const flight = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final total = delay + flight;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      onEnd: onEnd,
      builder: (context, v, child) {
        final t = Curves.easeInOutCubic.transform(
            ((v * total.inMilliseconds - delay.inMilliseconds) /
                    flight.inMilliseconds)
                .clamp(0.0, 1.0));
        final icon = from.currentContext?.findRenderObject();
        final stack = page.currentContext?.findRenderObject();
        if (t == 0 ||
            icon is! RenderBox ||
            stack is! RenderBox ||
            !icon.attached ||
            !stack.attached) {
          return const SizedBox.shrink();
        }
        final start = stack
            .globalToLocal(icon.localToGlobal(icon.size.center(Offset.zero)));
        final media = MediaQuery.of(context);
        // The Review tab: the middle of the bar's three, about 44 pt above
        // the bottom inset.
        final end = Offset(stack.size.width / 2,
            stack.size.height - media.padding.bottom - 44);
        final p = Offset.lerp(start, end, t)!;
        final arc = -math.sin(t * math.pi) * 36;
        final scale = 1 + .5 * math.sin(t * math.pi) - .4 * t;
        return Positioned(
          left: p.dx - 14,
          top: p.dy - 14 + arc,
          child: Opacity(
            opacity: t < .8 ? 1 : (1 - t) * 5,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: IgnorePointer(
        child: KeyedSubtree(
          key: DailyTestScreen.bookFlightKey,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
            child: Icon(Icons.menu_book_rounded, size: 18, color: c.navyText),
          ),
        ),
      ),
    );
  }
}

/// "+N" with the clay star, flying from the sheet up into the points chip
/// (600 ms).
class _FlyingStar extends StatelessWidget {
  final VoidCallback onLanded;
  const _FlyingStar({super.key, required this.onLanded});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      onEnd: onLanded,
      builder: (context, t, child) {
        final from = Offset(size.width * .78, size.height * .62);
        final to = Offset(size.width - 44, 18);
        final p = Offset.lerp(from, to, t)!;
        final arc = -math.sin(t * math.pi) * 40;
        return Positioned(
          left: rtl ? size.width - p.dx - 36 : p.dx - 18,
          top: p.dy + arc,
          child: Opacity(
            opacity: t < .9 ? 1 : (1 - t) * 10,
            child: Transform.scale(scale: 1 - .3 * t, child: child),
          ),
        );
      },
      child: IgnorePointer(
        child: Image.asset('assets/ui/points_star.webp',
            width: 36, height: 36, excludeFromSemantics: true),
      ),
    );
  }
}
