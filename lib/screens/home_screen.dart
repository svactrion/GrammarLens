import 'package:flutter/material.dart';

import '../data/topics.dart';
import '../models/app_theme_mode.dart';
import '../models/topic.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/loading_view.dart';
import 'practice_launch.dart';

class HomeScreen extends StatefulWidget {
  final ClaudeService claudeService;
  final StorageService storageService;
  final void Function(AppThemeMode mode) onSelectThemeMode;

  const HomeScreen({
    super.key,
    required this.claudeService,
    required this.storageService,
    required this.onSelectThemeMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _generating = false;

  Future<void> _startPractice(Topic topic) {
    return launchPracticeSet(
      context: context,
      topic: topic,
      claudeService: widget.claudeService,
      storageService: widget.storageService,
      setGenerating: (value) {
        if (mounted) setState(() => _generating = value);
      },
      errorPrefix: 'Could not generate practice',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'GrammarLens',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: appBarFg,
          ),
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            icon: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: appBarFg,
            ),
            onPressed: () => widget.onSelectThemeMode(
              isDark ? AppThemeMode.light : AppThemeMode.dark,
            ),
          ),
        ],
      ),
      body: _generating
          ? const LoadingView(message: 'Preparing your questions…')
          : ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
              itemCount: kTopics.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final topic = kTopics[index];
                return Card(
                  child: InkWell(
                    onTap: () => _startPractice(topic),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            foregroundColor: theme.colorScheme.onPrimaryContainer,
                            child: Icon(topic.icon),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(topic.title, style: theme.textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  topic.description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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
