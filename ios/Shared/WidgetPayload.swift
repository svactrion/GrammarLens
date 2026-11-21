import Foundation

/// `<App Group>/widget/payload.json`, written by the app
/// (`lib/services/widget_payload.dart`), read by the widget extension.
/// Every string is final and in the app's language: the extension formats
/// and translates nothing (TASK-widgets fixed decision 3).
///
/// Compiled into the widget extension and RunnerTests.
struct WidgetPayload: Codable, Equatable {
  static let fileName = "payload.json"
  static let supportedSchema = 1

  var schema: Int
  /// Seconds since 1970 when the app wrote the file.
  var writtenAt: Double
  /// Arabic: the widgets lay out right to left.
  var rtl: Bool
  /// Ordered by `validFrom`: now, then the next local midnight.
  var entries: [Entry]

  struct Entry: Codable, Equatable {
    /// Seconds since 1970 from which this entry is shown.
    var validFrom: Double
    var climb: Climb
    var tip: Tip

    var date: Date { Date(timeIntervalSince1970: validFrom) }
  }

  struct Climb: Codable, Equatable {
    /// `waiting` (today's Daily Test not done) or `done`.
    var state: String
    var url: String
    var step: Int
    var steps: Int
    /// Small: the top label ("DAILY TEST" / "Done today").
    var label: String
    /// Small: "Step 2 is waiting" / "Step 2 of 30".
    var title: String
    /// Small: "5 questions · 2 min"; done: replaced by the countdown.
    var subtitle: String
    /// Small, waiting: "1/30".
    var stepBadge: String
    /// Small, done: this month's points ("18").
    var points: String
    /// Medium: "Step 2 is one test away" / "See you tomorrow, Ada".
    var mediumTitle: String
    /// Medium, waiting: "Ember Peak · November · 1/30".
    var mediumSubtitle: String
    /// Medium: the status chip ("Test waiting" / "Done today").
    var chip: String
    /// Medium, waiting: "Start".
    var button: String
    /// Done: whole hours left to the next test (1…24) → the small widget's
    /// line ("Next test in 10 h").
    var countdown: [String: String]
    /// Done: the same for the medium widget ("Next test in 10 h · 1/30").
    var countdownMedium: [String: String]
    var images: Images
    /// The avatar's trail point inside the mountain images, 0…1.
    var avatarPoint: [Double]

    var isDone: Bool { state == "done" }
  }

  struct Images: Codable, Equatable {
    var avatar: String
    var mountainLight: String
    var mountainDark: String
  }

  /// W01 (v12: the user's own latest mistake under a short rule). The
  /// fields added in v12 are optional, so an older payload still decodes.
  struct Tip: Codable, Equatable {
    /// The widget's left side: that weak spot (R03), or the box's link.
    var url: String
    /// The topic ("GERUND VS. INFINITIVE"), or "TIP OF THE DAY · ARTICLES".
    var label: String
    /// The key words in the green pill ("in learning", "the"); may be empty.
    var rule: String
    /// After the pill ("specific, known, or the only one"); may be empty.
    var example: String
    /// "Your weak spot · a new one daily" / "A new tip every day".
    var footer: String
    /// The Daily Test box: "DAILY TEST".
    var boxLabel: String
    /// "Start" or, when done, "Done today".
    var button: String
    var done: Bool
    /// v12: the rule before the pill (the scorer's, practice).
    var lead: String? = nil
    /// v12: the user's sentence and its correction.
    var mistake: Mistake? = nil
    /// v12, no weak spot yet: two more hint lines.
    var examples: [String]? = nil
    /// v12: the box's own link (Daily Test, or Home once done).
    var boxUrl: String? = nil
    /// v12, done: "Done" and the hours to the next test ("next in 10 h").
    var doneLabel: String? = nil
    var next: [String: String]? = nil
    /// v12: the box's companion (asleep once done).
    var boxImage: String? = nil

    func nextLine(hours: Int) -> String { next?[String(hours)] ?? "" }
  }

  /// One run of a sentence: `m` marks the wrong words (struck through) or
  /// the corrected ones (bold).
  struct Run: Codable, Equatable {
    var t: String
    var m: Bool
  }

  struct Mistake: Codable, Equatable {
    var wrong: [Run]
    var right: [Run]
  }

  static func decode(_ data: Data) -> WidgetPayload? {
    guard let payload = try? JSONDecoder().decode(WidgetPayload.self, from: data),
      payload.schema == supportedSchema, !payload.entries.isEmpty
    else { return nil }
    return payload
  }

  /// The entry shown at [date]: the last one that has started, else the
  /// first.
  func entry(at date: Date) -> Entry {
    entries.last(where: { $0.date <= date }) ?? entries[0]
  }
}

extension WidgetPayload.Climb {
  /// The countdown line at [date] for the next test at [nextTest]: whole
  /// hours, rounded up, 1…24.
  static func hoursLeft(from date: Date, to nextTest: Date) -> Int {
    let seconds = nextTest.timeIntervalSince(date)
    return min(24, max(1, Int((seconds / 3600).rounded(.up))))
  }

  func countdownLine(hours: Int, medium: Bool) -> String {
    let table = medium ? countdownMedium : countdown
    return table[String(hours)] ?? (medium ? mediumSubtitle : subtitle)
  }
}
