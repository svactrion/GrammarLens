import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/loading_view.dart';

/// The native launch screen and the app's first Flutter frame must be the
/// same color in each system appearance, or the user sees a flash between
/// them (a white one in dark mode, before this was fixed).

/// Keeps the app on its first frame: the profile read never finishes.
class _PendingProfileStorage extends StorageService {
  final _never = Completer<UserProfile?>();

  @override
  Future<UserProfile?> getUserProfile() => _never.future;
}

Color _hex(String component) => Color.fromARGB(
      255,
      int.parse(jsonDecode(component)['red'] as String),
      int.parse(jsonDecode(component)['green'] as String),
      int.parse(jsonDecode(component)['blue'] as String),
    );

Map<String, Color> _launchBackground() {
  final json = jsonDecode(File(
    'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
  ).readAsStringSync()) as Map<String, dynamic>;
  final colors = <String, Color>{};
  for (final entry in json['colors'] as List) {
    final appearances = entry['appearances'] as List?;
    final key = appearances == null ? 'any' : appearances.first['value'];
    colors[key as String] =
        _hex(jsonEncode((entry['color'] as Map)['components']));
  }
  return colors;
}

void main() {
  test('the launch screen color matches surfaceContainerLow in both themes',
      () {
    final colors = _launchBackground();
    expect(colors['any'],
        buildAppTheme(Brightness.light).colorScheme.surfaceContainerLow);
    expect(colors['dark'],
        buildAppTheme(Brightness.dark).colorScheme.surfaceContainerLow);
    expect(colors['any'], const Color(0xFFFAF3EC));
    expect(colors['dark'], const Color(0xFF1C1B1F));
  });

  test('the launch storyboard uses the LaunchBackground color', () {
    final storyboard = File('ios/Runner/Base.lproj/LaunchScreen.storyboard')
        .readAsStringSync();
    expect(storyboard,
        contains('<color key="backgroundColor" name="LaunchBackground"/>'));
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'the first frame paints the launch screen color '
        '(${brightness.name})', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        GrammarLensApp(storageService: _PendingProfileStorage()),
      );

      expect(find.byType(LoadingView), findsOneWidget);
      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.byType(LoadingView),
              matching: find.byType(Material),
            )
            .first,
      );
      final expected = brightness == Brightness.dark
          ? _launchBackground()['dark']
          : _launchBackground()['any'];
      expect(material.color, expected);
      // It covers the whole screen, not just the loading content.
      expect(tester.getSize(find.byWidget(material)),
          tester.view.physicalSize / tester.view.devicePixelRatio);

      // Leave the loading animation behind cleanly.
      await tester.pumpWidget(const SizedBox());
    });
  }
}
