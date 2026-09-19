import 'package:grammar_lens/services/analytics_service.dart';

/// One logged event, as [AnalyticsService] handed it to its sink.
class RecordedEvent {
  final String name;
  final Map<String, Object>? parameters;

  const RecordedEvent(this.name, this.parameters);

  @override
  String toString() => 'RecordedEvent($name, $parameters)';
}

/// An [AnalyticsSink] that keeps everything in memory so tests can assert the
/// exact event names, parameter keys and user properties produced.
class RecordingAnalyticsSink implements AnalyticsSink {
  final List<RecordedEvent> events = [];
  final Map<String, String?> userProperties = {};
  final List<String> userPropertyWrites = [];

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    events
        .add(RecordedEvent(name, parameters == null ? null : {...parameters}));
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    userProperties[name] = value;
    userPropertyWrites.add(name);
  }

  List<RecordedEvent> named(String name) =>
      events.where((e) => e.name == name).toList();
}
