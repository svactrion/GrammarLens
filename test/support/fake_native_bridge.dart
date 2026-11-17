import 'dart:async';
import 'dart:typed_data';

import 'package:grammar_lens/services/native_bridge.dart';

/// An in-memory [NativeBridge]: the App Group is a map, links are pushed by
/// the test, widget reloads are counted.
class FakeNativeBridge implements NativeBridge {
  FakeNativeBridge({this.initial});

  /// The cold-start link [initialLink] answers once.
  String? initial;
  final files = <String, Uint8List>{};
  int reloads = 0;
  bool available = true;
  final _links = StreamController<String>.broadcast();

  void pushLink(String url) => _links.add(url);

  @override
  Future<bool> writeAppGroupFile(String name, Uint8List bytes) async {
    if (!NativeBridge.isValidFileName(name)) return false;
    files[name] = bytes;
    return true;
  }

  @override
  Future<Uint8List?> readAppGroupFile(String name) async => files[name];

  @override
  Future<bool> deleteAppGroupFile(String name) async {
    files.remove(name);
    return true;
  }

  @override
  Future<List<String>> listAppGroupFiles() async => files.keys.toList()..sort();

  @override
  Future<bool> appGroupAvailable() async => available;

  @override
  Future<bool> reloadWidgets() async {
    reloads++;
    return true;
  }

  @override
  Future<String?> initialLink() async {
    final link = initial;
    initial = null;
    return link;
  }

  @override
  Stream<String> get links => _links.stream;
}
