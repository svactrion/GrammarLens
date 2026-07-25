import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import 'screens/home_screen.dart';
import 'screens/review_screen.dart';
import 'services/claude_service.dart';
import 'services/storage_service.dart';
import 'theme.dart';

class GrammarLensApp extends StatefulWidget {
  const GrammarLensApp({super.key});

  @override
  State<GrammarLensApp> createState() => _GrammarLensAppState();
}

class _GrammarLensAppState extends State<GrammarLensApp> {
  final ClaudeService _claudeService = ClaudeService();
  final StorageService _storageService = StorageService();
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(claudeService: _claudeService, storageService: _storageService),
      ReviewScreen(
        claudeService: _claudeService,
        storageService: _storageService,
        // IndexedStack keeps this screen's State alive across tab switches
        // instead of recreating it, so initState alone won't pick up errors
        // saved while a different tab (e.g. after a Home practice session)
        // was active. Passing whether this tab is currently selected lets
        // ReviewScreen detect "just became visible" and reload then.
        active: _tabIndex == 1,
      ),
    ];

    return MaterialApp(
      title: 'GrammarLens',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      // `Builder` gets a context nested under the `MaterialApp` above, so
      // `Theme.of` here resolves the light/dark scheme we just set via
      // `theme`/`darkTheme` instead of whatever theme sits above this
      // widget in the tree.
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          // Same contrast-checked color the app bar uses for content sitting
          // directly on the orange (light) / near-black (dark) scaffold —
          // see theme.dart's `appBarFg` for the reasoning.
          final unselectedColor =
              theme.appBarTheme.foregroundColor ?? colorScheme.onSurface;
          return Scaffold(
            body: IndexedStack(index: _tabIndex, children: screens),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: GNav(
                  selectedIndex: _tabIndex,
                  onTabChange: (i) => setState(() => _tabIndex = i),
                  // Transparent so the orange/near-black scaffold shows
                  // straight through — no solid bar surface.
                  backgroundColor: Colors.transparent,
                  color: unselectedColor,
                  activeColor: colorScheme.onSecondaryContainer,
                  tabBackgroundColor: colorScheme.secondaryContainer,
                  // GNav defaults to spaceBetween, which pins the two tabs
                  // to the far edges of the bar; center them as a group with
                  // margin between them instead.
                  mainAxisAlignment: MainAxisAlignment.center,
                  tabMargin: const EdgeInsets.symmetric(horizontal: 10),
                  gap: 8,
                  iconSize: 24,
                  tabBorderRadius: 24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    GButton(icon: Icons.school_outlined, text: 'Practice'),
                    GButton(icon: Icons.history_outlined, text: 'Review'),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
