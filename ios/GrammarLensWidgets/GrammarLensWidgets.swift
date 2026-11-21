import SwiftUI
import WidgetKit

/// The widget extension (W01): "Climb" (small, medium) and "Tip" (medium).
/// The gallery's name and description are the brand and the feature, set
/// once in English: the extension translates nothing (fixed decision 3), and
/// the gallery shows them before the app has written any payload.
@main
struct GrammarLensWidgets: WidgetBundle {
  var body: some Widget {
    ClimbWidget()
    TipWidget()
  }
}

struct ClimbWidget: Widget {
  let kind = "ClimbWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GrammarLensProvider()) { entry in
      ClimbWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(Text(verbatim: "Climb"))
    .description(Text(verbatim: "Today's Daily Test and your step on this month's mountain."))
    .supportedFamilies([.systemSmall, .systemMedium])
    .disablingContentMargins()
  }
}

struct TipWidget: Widget {
  let kind = "TipWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GrammarLensProvider()) { entry in
      TipWidgetEntryView(entry: entry)
    }
    .configurationDisplayName(Text(verbatim: "Tip"))
    .description(Text(verbatim: "A daily grammar tip from your weak spots."))
    .supportedFamilies([.systemMedium])
    .disablingContentMargins()
  }
}

extension WidgetConfiguration {
  /// Edge-to-edge content on iOS 17+ (the mountain fills the widget).
  func disablingContentMargins() -> some WidgetConfiguration {
    if #available(iOSApplicationExtension 17.0, *) {
      return self.contentMarginsDisabled()
    } else {
      return self
    }
  }
}
