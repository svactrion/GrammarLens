import 'package:flutter/material.dart';

import '../data/topics.dart';
import '../models/topic.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import 'practice_screen.dart';

class HomeScreen extends StatefulWidget {
  final ClaudeService claudeService;
  final StorageService storageService;

  const HomeScreen({
    super.key,
    required this.claudeService,
    required this.storageService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _generating = false;

  Future<void> _startPractice(Topic topic) async {
    setState(() => _generating = true);
    try {
      final practiceSet = await widget.claudeService.generatePracticeSet(topic);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PracticeScreen(
            topic: topic,
            practiceSet: practiceSet,
            claudeService: widget.claudeService,
            storageService: widget.storageService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate practice: $e')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GrammarLens')),
      body: _generating
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: kTopics.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final topic = kTopics[index];
                return Card(
                  child: ListTile(
                    title: Text(topic.title),
                    subtitle: Text(topic.description),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _startPractice(topic),
                  ),
                );
              },
            ),
    );
  }
}
