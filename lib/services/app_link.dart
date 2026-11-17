import 'dart:async';

import 'native_bridge.dart';

/// The places a widget or a reminder can open (TASK-widgets fixed decisions
/// 3 and 4, DW0-2): `grammarlens://daily-test`, `grammarlens://home`,
/// `grammarlens://review`.
enum AppLink {
  dailyTest('daily-test'),
  home('home'),
  review('review');

  const AppLink(this.host);

  /// The URL's host part.
  final String host;

  static const scheme = 'grammarlens';

  String get url => '$scheme://$host';

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

  void _receive(String? url) {
    final link = AppLink.parse(url);
    if (link == null) return;
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
