// The parts of steps_render_test.dart that differ before and after N31/N32.
// After: the ending switch and the signpost's asset exist.
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';

void setEnding(bool? atFlag) => ClimbRoute.debugEndsAtFlagOverride = atFlag;

List<String> extraAssets() => [for (final p in ClimbSavePoints.decor) p.asset];
