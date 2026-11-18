// Fix round 3, §4: the seeded app (`tool/widgets/seeded_app.dart`) with the
// Flutter Driver extension, so `smoke_driver.dart` can walk a fresh
// install by hand-free taps. Not part of the app: nothing in lib/ imports
// tool/ (`test/tool_import_guard_test.dart`).
//
//   flutter drive -d <simulator> --target tool/ui_polish/smoke_app.dart \
//     --driver tool/ui_polish/smoke_driver.dart \
//     --dart-define=SEED_SKIP=true \
//     --dart-define=PROXY_BASE_URL=http://localhost:8787 \
//     --dart-define=APP_TOKEN=local-smoke
//
// With a local stand-in for the practice proxy on port 8787 (canned JSON,
// no AI call), the walk can use the free ticket on a real practice.
import 'package:flutter_driver/driver_extension.dart';

import '../widgets/seeded_app.dart' as seeded;

Future<void> main() async {
  enableFlutterDriverExtension();
  await seeded.main();
}
