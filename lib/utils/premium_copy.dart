/// Shown wherever a free user has used today's
/// `StorageService.freeDailyPracticeLimit`: the weak-spot detail screen's
/// locked row and the practice results screen's Premium offer card. One
/// constant so the two places cannot drift apart. Never says "unlimited": Premium is
/// bounded by `StorageService.dailySessionLimit`.
const String freePracticeUsedMessage =
    "You've used today's free practice. Unlock Topic Practice "
    'and more daily sessions with Premium.';
