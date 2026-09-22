/// A Daily Test completion that has been saved but whose climb step Home has
/// not yet shown. [day] is the ledger day the step belongs to (the set's own
/// day, not the wall clock) and [step] is the number of steps it earned (0 or
/// 1 under rule v1; only positive values are ever handed on).
///
/// Home normally learns about a completion through its own Daily Test route
/// (`HomeScreen._openDailyTest`). The first-launch flow finishes before Home
/// exists, so it hands the same fact over through this record instead.
typedef PendingClimb = ({String day, int step});
