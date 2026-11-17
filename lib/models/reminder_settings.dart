/// Whether our own reminder question (N01) has been asked (TASK-widgets
/// fixed decision 5): it is asked once, before the iOS permission dialog.
enum ReminderAsk {
  notAsked('not_asked'),

  /// "Not now": never asked again on its own.
  declined('declined'),

  /// "Turn on reminders" (or turned on in Settings).
  accepted('accepted');

  const ReminderAsk(this.storageValue);

  final String storageValue;

  static ReminderAsk fromStorage(String? value) =>
      values.firstWhere((ask) => ask.storageValue == value,
          orElse: () => ReminderAsk.notAsked);
}

/// The four reminder kinds (N03), in the order a day's one reminder is
/// picked (fixed decision 4).
enum ReminderKind { newMountain, closeToMedal, dailyTest, freeTicket }

/// The reminder settings (N01, N03, V24's switch), on the device only.
class ReminderSettings {
  const ReminderSettings({
    this.dailyTest = false,
    this.freeTicket = false,
    this.closeToMedal = false,
    this.newMountain = false,
    this.minutes = defaultMinutes,
    this.ask = ReminderAsk.notAsked,
  });

  /// 20:00, N01's preselected "Evening".
  static const defaultMinutes = 20 * 60;

  /// N01's options: Morning 08:30, Lunch break 12:30, Evening 20:00.
  static const morning = 8 * 60 + 30;
  static const lunch = 12 * 60 + 30;
  static const evening = 20 * 60;

  final bool dailyTest;
  final bool freeTicket;
  final bool closeToMedal;
  final bool newMountain;

  /// The time of day, minutes after local midnight.
  final int minutes;
  final ReminderAsk ask;

  int get hour => minutes ~/ 60;
  int get minute => minutes % 60;

  bool get anyOn => dailyTest || freeTicket || closeToMedal || newMountain;

  bool isOn(ReminderKind kind) => switch (kind) {
        ReminderKind.newMountain => newMountain,
        ReminderKind.closeToMedal => closeToMedal,
        ReminderKind.dailyTest => dailyTest,
        ReminderKind.freeTicket => freeTicket,
      };

  /// Reminders turned on (N01's "Turn on reminders", or the first switch in
  /// Settings): every kind starts on (fixed decision 6).
  ReminderSettings turnedOn({int? minutes}) => ReminderSettings(
        dailyTest: true,
        freeTicket: true,
        closeToMedal: true,
        newMountain: true,
        minutes: minutes ?? this.minutes,
        ask: ReminderAsk.accepted,
      );

  ReminderSettings withKind(ReminderKind kind, bool on) => ReminderSettings(
        dailyTest: kind == ReminderKind.dailyTest ? on : dailyTest,
        freeTicket: kind == ReminderKind.freeTicket ? on : freeTicket,
        closeToMedal: kind == ReminderKind.closeToMedal ? on : closeToMedal,
        newMountain: kind == ReminderKind.newMountain ? on : newMountain,
        minutes: minutes,
        ask: ask,
      );

  ReminderSettings copyWith({int? minutes, ReminderAsk? ask}) =>
      ReminderSettings(
        dailyTest: dailyTest,
        freeTicket: freeTicket,
        closeToMedal: closeToMedal,
        newMountain: newMountain,
        minutes: minutes ?? this.minutes,
        ask: ask ?? this.ask,
      );

  Map<String, Object?> toMap() => {
        'id': 0,
        'daily_test': dailyTest ? 1 : 0,
        'free_ticket': freeTicket ? 1 : 0,
        'close_to_medal': closeToMedal ? 1 : 0,
        'new_mountain': newMountain ? 1 : 0,
        'minutes': minutes,
        'ask': ask.storageValue,
      };

  factory ReminderSettings.fromMap(Map<String, Object?> map) =>
      ReminderSettings(
        dailyTest: map['daily_test'] == 1,
        freeTicket: map['free_ticket'] == 1,
        closeToMedal: map['close_to_medal'] == 1,
        newMountain: map['new_mountain'] == 1,
        minutes: ((map['minutes'] as int?) ?? defaultMinutes).clamp(0, 1439),
        ask: ReminderAsk.fromStorage(map['ask'] as String?),
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.dailyTest == dailyTest &&
      other.freeTicket == freeTicket &&
      other.closeToMedal == closeToMedal &&
      other.newMountain == newMountain &&
      other.minutes == minutes &&
      other.ask == ask;

  @override
  int get hashCode => Object.hash(
      dailyTest, freeTicket, closeToMedal, newMountain, minutes, ask);
}
