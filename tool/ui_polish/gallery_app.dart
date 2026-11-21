// UI polish board gallery (docs/design/ui-polish/handoff/PROGRESS.md, D0-4):
// mounts the real widgets and screens of each in-scope board with fixed
// sample data, one board at a time, so `gallery_driver.dart` can capture
// each with `xcrun simctl io <udid> screenshot`.
//
// Not part of the app: nothing in lib/ imports tool/
// (`test/tool_import_guard_test.dart`), so none of this reaches a release
// build. Firebase and RevenueCat are not started; nothing is sent anywhere.
//
// Driver requests:
//   board:<ID>      show board <ID> (light theme)
//   board:<ID>:dark the same in the dark theme
//   boards          the list of board ids, comma-separated
//
// Run through tool/ui_polish/capture.sh.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';
import 'package:grammar_lens/utils/app_orientation.dart';

import 'boards.dart';

final _board = ValueNotifier<(String, bool)>(('index', false));

Future<void> main() async {
  enableFlutterDriverExtension(handler: (request) async {
    if (request == null) return '';
    if (request == 'boards') return galleryBoards.keys.join(',');
    if (request.startsWith('scroll:')) {
      if (!galleryScroll.hasClients) return 'none';
      final to = double.parse(request.substring(7));
      galleryScroll.jumpTo(
          to.clamp(0, galleryScroll.position.maxScrollExtent).toDouble());
      return 'ok';
    }
    if (request.startsWith('board:')) {
      final parts = request.substring(6).split(':');
      _board.value = (parts.first, parts.length > 1 && parts[1] == 'dark');
      return galleryBoards.containsKey(parts.first) ? 'ok' : 'unknown';
    }
    return '';
  });
  WidgetsFlutterBinding.ensureInitialized();
  await lockAppOrientation();
  runApp(const _GalleryApp());
}

class _GalleryApp extends StatelessWidget {
  const _GalleryApp();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<(String, bool)>(
      valueListenable: _board,
      builder: (context, value, _) {
        final (id, dark) = value;
        final entry = galleryBoards[id];
        return MaterialApp(
          // A new key per board: every board starts from a fresh state.
          key: ValueKey('$id-$dark'),
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: AppMessenger.key,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: entry == null
              ? _Index(onPick: (id) => _board.value = (id, false))
              : Builder(builder: entry),
        );
      },
    );
  }
}

/// The list of boards, for looking around by hand.
class _Index extends StatelessWidget {
  final ValueChanged<String> onPick;
  const _Index({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UI polish boards')),
      body: ListView(
        children: [
          for (final id in galleryBoards.keys)
            ListTile(title: Text(id), onTap: () => onPick(id)),
        ],
      ),
    );
  }
}
