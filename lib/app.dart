import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/review_screen.dart';
import 'services/claude_service.dart';
import 'services/storage_service.dart';

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
      ReviewScreen(claudeService: _claudeService, storageService: _storageService),
    ];

    return MaterialApp(
      title: 'GrammarLens',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: Scaffold(
        body: IndexedStack(index: _tabIndex, children: screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (i) => setState(() => _tabIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.school), label: 'Practice'),
            NavigationDestination(icon: Icon(Icons.refresh), label: 'Review'),
          ],
        ),
      ),
    );
  }
}
