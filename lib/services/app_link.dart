import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;

import 'native_bridge.dart';

/// The places a widget or a reminder can open (TASK-widgets fixed decisions
/// 3 and 4, DW0-2): `grammarlens://daily-test`, `grammarlens://home`,
/// `grammarlens://review`, and (fix round 4, W01 v12: the tip widget's
/// weak spot) `grammarlens://weak-spot?topic=<id>&type=<slug>`.
enum AppLink {
  dailyTest('daily-test'),
  home('home'),
  review('review'),
  weakSpot('weak-spot');

  const AppLink(this.host);

  /// The URL's host part.
  final String host;

  static const scheme = 'grammarlens';

  String get url => '$scheme://$host';

  /// W01 v12: the tip widget's weak spot (R03).
  static String weakSpotUrl(String topicId, String errorType) => Uri(
      scheme: scheme,
      host: AppLink.weakSpot.host,
      queryParameters: {'topic': topicId, 'type': errorType}).toString();

  /// The weak spot a `weak-spot` URL names, or null.
  static WeakSpotLink? weakSpotOf(String? url) {
    if (parse(url) != AppLink.weakSpot) return null;
    final query = Uri.parse(url!.trim()).queryParameters;
    final topic = query['topic'], type = query['type'];
    if (topic == null || topic.isEmpty || type == null || type.isEmpty) {
      return null;
    }
    return WeakSpotLink(topic, type);
  }

  /// The link a URL names, or null for anything else (another scheme, an
  /// unknown place). Case-insensitive; a trailing slash, query or fragment is
  /// ignored.
  static AppLink? parse(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme.toLowerCase() != scheme) return null;
    // `grammarlens://daily-test` → host; `grammarlens:daily-test` → path.
    final place = (uri.host.isNotEmpty ? uri.host : uri.path)
        .toLowerCase()
        .replaceAll('/', '');
    for (final link in values) {
      if (link.host == place) return link;
    }
    return null;
  }
}

/// A weak spot named by a link (W01 v12): its topic and error type.
@immutable
class WeakSpotLink {
  const WeakSpotLink(this.topicId, this.errorType);
  final String topicId;
  final String errorType;

  @override
  bool operator ==(Object other) =>
      other is WeakSpotLink &&
      other.topicId == topicId &&
      other.errorType == errorType;

  @override
  int get hashCode => Object.hash(topicId, errorType);

  @override
  String toString() => 'WeakSpotLink($topicId, $errorType)';
}

/// Delivers [AppLink]s from the bridge to the app (DW0-3): the cold-start
/// link and every warm one. Until a handler is attached (the profile is still
/// loading) the latest link waits; detaching (onboarding, reset) drops
/// what arrives meanwhile.
class AppLinkRouter {
  AppLinkRouter(this._bridge);

  final NativeBridge _bridge;
  StreamSubscription<String>? _subscription;
  void Function(AppLink link)? _handler;
  AppLink? _pending;
  bool _accepting = true;

  /// Reads the cold-start link and listens for the rest. Safe to call once.
  Future<void> start() async {
    _subscription ??= _bridge.links.listen(_receive);
    _receive(await _bridge.initialLink());
  }

  /// The app's shell is ready: [handler] gets the waiting link now (if any)
  /// and every later one.
  void attach(void Function(AppLink link) handler) {
    _handler = handler;
    _accepting = true;
    final pending = _pending;
    _pending = null;
    if (pending != null) handler(pending);
  }

  /// No shell (onboarding): links are dropped until [attach].
  void detach() {
    _handler = null;
    _accepting = false;
    _pending = null;
  }

  /// The link waiting for [attach], for tests.
  AppLink? get pending => _pending;

  /// The weak spot of the latest [AppLink.weakSpot] link (W01 v12), read
  /// by the handler when that link arrives.
  WeakSpotLink? weakSpot;

  void _receive(String? url) {
    final link = AppLink.parse(url);
    if (link == null) return;
    if (link == AppLink.weakSpot) {
      final spot = AppLink.weakSpotOf(url);
      // A weak-spot link without its weak spot opens Review.
      if (spot == null) return _deliver(AppLink.review);
      weakSpot = spot;
    }
    _deliver(link);
  }

  void _deliver(AppLink link) {
    final handler = _handler;
    if (handler != null) {
      handler(link);
    } else if (_accepting) {
      _pending = link;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _handler = null;
  }
}
