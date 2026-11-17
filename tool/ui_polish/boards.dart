// The UI polish board gallery's boards: id → the real widget or screen with
// fixed sample data. See gallery_app.dart.
import 'package:flutter/material.dart';
import 'package:grammar_lens/app_colors.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/companion_view.dart';
import 'package:grammar_lens/widgets/pressable_button.dart';

/// Every board the gallery can show, in SPEC order.
final Map<String, WidgetBuilder> galleryBoards = {
  'V00-CompanionSystem': (_) => const _CompanionSystem(),
  'V00-MotionSystem': (_) => const _MotionSystem(),
  'X01-ExpressionKit': (_) => const _ExpressionKit(),
  'X03-HeroSet': (_) => const _HeroSet(),
};

/// A system board: a title and its content, scrolling.
class SystemBoard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SystemBoard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall!
                    .withWeight(FontWeight.w900)
                    .copyWith(color: c.text)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

Widget _label(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelMedium!
              .withWeight(FontWeight.w900)
              .copyWith(color: AppColors.of(context).navy, letterSpacing: 1)),
    );

Widget _stage(BuildContext context, Avatar hero, Widget child,
        {double w = 104, double h = 104}) =>
    Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.stageFor(hero.order, Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );

class _CompanionSystem extends StatelessWidget {
  const _CompanionSystem();

  @override
  Widget build(BuildContext context) {
    return SystemBoard(title: 'Companion system', children: [
      _label(context, 'FOX · EVERY MOOD'),
      Wrap(spacing: 10, runSpacing: 22, children: [
        for (final mood in CompanionMood.values)
          Column(children: [
            _stage(context, Avatar.fox,
                CompanionView(hero: Avatar.fox, mood: mood, size: 76)),
            const SizedBox(height: 4),
            Text(mood.name),
          ]),
      ]),
      _label(context, 'THE NINE HEROES · IDLE'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final hero in Avatar.values)
          _stage(context, hero, CompanionView(hero: hero, size: 64),
              w: 76, h: 76),
      ]),
    ]);
  }
}

class _MotionSystem extends StatelessWidget {
  const _MotionSystem();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget swatch(Color color, String name) => Column(children: [
          Container(
              width: 52,
              height: 36,
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.line))),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 11)),
        ]);
    return SystemBoard(title: 'Motion and touch system', children: [
      _label(context, 'BUTTONS: PRESSABLE 3D'),
      PressableButton(label: 'Primary', onPressed: () {}, tone: ButtonTone.orange),
      const SizedBox(height: 10),
      PressableButton(label: 'Secondary', onPressed: () {}),
      const SizedBox(height: 10),
      PressableButton(label: 'Correct', onPressed: () {}, tone: ButtonTone.green),
      const SizedBox(height: 10),
      const PressableButton(label: 'Disabled', onPressed: null),
      const SizedBox(height: 10),
      PressableButton(
          label: 'Shine', onPressed: () {}, tone: ButtonTone.orange, shine: true),
      const SizedBox(height: 10),
      PressableButton(
          label: 'Outline', onPressed: () {}, tone: ButtonTone.outline),
      PressableButton(label: 'Text', onPressed: () {}, tone: ButtonTone.text),
      _label(context, 'COLOUR'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        swatch(c.orange, 'Orange'),
        swatch(c.navy, 'Navy'),
        swatch(c.green, 'Green'),
        swatch(c.red, 'Red'),
        swatch(c.gold, 'Gold'),
        swatch(c.page, 'Cream'),
        swatch(c.sky, 'Sky'),
      ]),
    ]);
  }
}

class _ExpressionKit extends StatelessWidget {
  const _ExpressionKit();

  @override
  Widget build(BuildContext context) {
    const heroes = [Avatar.fox, Avatar.panda, Avatar.frog, Avatar.giraffe];
    const moods = [
      CompanionMood.cheer,
      CompanionMood.think,
      CompanionMood.sad,
      CompanionMood.sleep,
      CompanionMood.oops,
    ];
    return SystemBoard(title: 'Pose + expression kit', children: [
      for (final mood in moods) ...[
        _label(context, mood.name.toUpperCase()),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final hero in heroes)
              _stage(
                  context,
                  hero,
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: CompanionView(hero: hero, mood: mood, size: 58),
                  ),
                  w: 82,
                  h: 92),
          ],
        ),
      ],
    ]);
  }
}

class _HeroSet extends StatelessWidget {
  const _HeroSet();

  @override
  Widget build(BuildContext context) {
    const moods = [
      CompanionMood.wave,
      CompanionMood.cheer,
      CompanionMood.think,
      CompanionMood.inspect,
      CompanionMood.sad,
      CompanionMood.sleep,
    ];
    return SystemBoard(title: 'Hero set — 9 heroes × 6 poses', children: [
      for (final hero in Avatar.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            SizedBox(
                width: 54,
                child: Text(hero.name(context.l10n),
                    style: const TextStyle(fontSize: 12))),
            for (final mood in moods)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: _stage(
                    context,
                    hero,
                    CompanionView(
                        hero: hero, mood: mood, size: 44, showProp: false),
                    w: 50,
                    h: 50),
              ),
          ]),
        ),
    ]);
  }
}
