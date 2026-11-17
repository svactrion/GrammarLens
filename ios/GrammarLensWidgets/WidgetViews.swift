import SwiftUI
import WidgetKit

// W01: the "Climb" widget (small, medium A "mountain panorama") and the
// "Tip" widget (medium B "personal tip"). No animation, no streak. Every
// string comes from the payload.

/// Shown before the app has written a payload (a fresh install): the brand
/// only, which needs no translation; a tap opens Home.
struct EmptyWidgetView: View {
  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 26, weight: .heavy))
      Text(verbatim: "GrammarLens")
        .font(WidgetFont.heavy(15))
    }
    .foregroundColor(WidgetPalette.onOrange)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetBackground { WidgetPalette.orange }
    .widgetURL(URL(string: "grammarlens://home"))
  }
}

struct AvatarImage: View {
  let name: String
  let size: CGFloat

  var body: some View {
    if let image = WidgetImages.load(name) {
      Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
  }
}

// MARK: Small

struct ClimbSmallView: View {
  let climb: WidgetPayload.Climb
  let hoursLeft: Int
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      AvatarImage(name: climb.images.avatar, size: 74)
        .offset(x: 6, y: 6)
      VStack(alignment: .leading, spacing: 0) {
        if climb.isDone { doneHeader } else { waitingHeader }
        Spacer(minLength: 0)
        badge
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .padding(14)
    .widgetBackground {
      climb.isDone ? WidgetPalette.card(scheme) : WidgetPalette.orange
    }
    .widgetURL(URL(string: climb.url))
  }

  private var waitingHeader: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(climb.label)
        .font(WidgetFont.heavy(11))
        .kerning(0.8)
        .foregroundColor(WidgetPalette.onOrange.opacity(0.8))
        .lineLimit(1)
      Text(climb.title)
        .font(WidgetFont.heavy(19))
        .foregroundColor(WidgetPalette.onOrange)
        .lineLimit(2)
        .minimumScaleFactor(0.75)
      Text(climb.subtitle)
        .font(WidgetFont.bold(11))
        .foregroundColor(WidgetPalette.onOrange.opacity(0.85))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
  }

  private var doneHeader: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 5) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(WidgetPalette.green)
        Text(climb.label)
          .font(WidgetFont.heavy(12))
          .foregroundColor(WidgetPalette.green)
          .lineLimit(1)
      }
      // One line, as on W01 ("Step 2 of 30"); a longer translation scales
      // down. The countdown may take two lines (Arabic, German).
      Text(climb.title)
        .font(WidgetFont.heavy(18))
        .foregroundColor(WidgetPalette.text(scheme))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(climb.countdownLine(hours: hoursLeft, medium: false))
        .font(WidgetFont.bold(11))
        .foregroundColor(WidgetPalette.muted(scheme))
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private var badge: some View {
    if climb.isDone {
      HStack(spacing: 4) {
        Image(systemName: "star.fill")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(WidgetPalette.gold)
        Text(climb.points)
          .font(WidgetFont.heavy(12))
          .foregroundColor(WidgetPalette.goldDeep)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Capsule().fill(WidgetPalette.goldSoft))
    } else {
      Text(climb.stepBadge)
        .font(WidgetFont.heavy(12))
        .foregroundColor(WidgetPalette.onOrange)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(WidgetPalette.cream.opacity(0.85)))
    }
  }
}

// MARK: Medium A — mountain panorama

struct ClimbMediumView: View {
  let climb: WidgetPayload.Climb
  let hoursLeft: Int
  @Environment(\.colorScheme) private var scheme

  /// Waiting follows the system's light/dark; done is the evening tone.
  private var backgroundName: String {
    climb.isDone || scheme == .dark ? climb.images.mountainDark : climb.images.mountainLight
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        AvatarImage(name: climb.images.avatar, size: 46)
          .position(avatarCenter(in: geometry.size))
        LinearGradient(
          colors: [Color.black.opacity(0.55), Color.black.opacity(0)],
          startPoint: .top, endPoint: .center
        )
        .allowsHitTesting(false)
        header
          .padding(.horizontal, 14)
          .padding(.top, 12)
        if !climb.isDone {
          startButton
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(12)
        }
      }
    }
    .widgetBackground { background }
    .widgetURL(URL(string: climb.url))
  }

  @ViewBuilder
  private var background: some View {
    if let image = WidgetImages.load(backgroundName) {
      Image(uiImage: image).resizable().scaledToFill()
    } else {
      LinearGradient(
        colors: [Color(hex: 0x3B3442), Color(hex: 0x1F1B24)], startPoint: .top, endPoint: .bottom)
    }
  }

  private func avatarCenter(in size: CGSize) -> CGPoint {
    let x = climb.avatarPoint.first ?? 0.5
    let y = climb.avatarPoint.count > 1 ? climb.avatarPoint[1] : 0.6
    // The avatar stands on the point: its feet, not its centre.
    return CGPoint(x: size.width * x, y: size.height * y - 18)
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(climb.mediumTitle)
          .font(WidgetFont.heavy(16))
          .foregroundColor(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Text(climb.isDone ? climb.countdownLine(hours: hoursLeft, medium: true) : climb.mediumSubtitle)
          .font(WidgetFont.bold(11))
          .foregroundColor(.white.opacity(0.9))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
      Spacer(minLength: 4)
      chip
    }
  }

  private var chip: some View {
    HStack(spacing: 4) {
      Image(systemName: climb.isDone ? "checkmark" : "clock")
        .font(.system(size: 10, weight: .heavy))
      Text(climb.chip)
        .font(WidgetFont.heavy(11))
        .lineLimit(1)
    }
    .foregroundColor(climb.isDone ? .white : WidgetPalette.onOrange)
    .padding(.horizontal, 9)
    .padding(.vertical, 5)
    .background(Capsule().fill(climb.isDone ? WidgetPalette.green : WidgetPalette.orange))
  }

  private var startButton: some View {
    HStack(spacing: 6) {
      Text(climb.button)
        .font(WidgetFont.heavy(13))
      Image(systemName: "arrow.forward")
        .font(.system(size: 11, weight: .heavy))
        .flipsForRightToLeftLayoutDirection(true)
    }
    .foregroundColor(WidgetPalette.navy)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Capsule().fill(Color.white))
  }
}

// MARK: Medium B — personal tip

struct TipMediumView: View {
  let tip: WidgetPayload.Tip
  let avatar: String
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 5) {
        Text(tip.label)
          .font(WidgetFont.heavy(10))
          .kerning(0.8)
          .foregroundColor(WidgetPalette.orangeDeep)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Text(ruleLine)
          .font(WidgetFont.heavy(15))
          .foregroundColor(WidgetPalette.text(scheme))
          .lineLimit(3)
          .minimumScaleFactor(0.75)
        Spacer(minLength: 0)
        Text(tip.footer)
          .font(WidgetFont.bold(10))
          .foregroundColor(WidgetPalette.muted(scheme))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      box
    }
    .padding(14)
    .widgetBackground { WidgetPalette.card(scheme) }
    .widgetURL(URL(string: tip.url))
  }

  /// W01: the rule's key words as a green highlight inside the sentence
  /// ("the" · "specific, known, or the only one"); a hint line without a
  /// key is shown plain (DW2-2).
  private var ruleLine: AttributedString {
    guard !tip.example.isEmpty else { return AttributedString(tip.rule) }
    var key = AttributedString("\u{00A0}\(tip.rule)\u{00A0}")
    key.backgroundColor = scheme == .dark ? WidgetPalette.greenDeep : WidgetPalette.greenSoft
    key.foregroundColor = scheme == .dark ? .white : WidgetPalette.greenDeep
    return key + AttributedString(" \(tip.example)")
  }

  private var box: some View {
    VStack(spacing: 6) {
      Text(tip.boxLabel)
        .font(WidgetFont.heavy(9))
        .kerning(0.6)
        .foregroundColor(tip.done ? .white.opacity(0.85) : WidgetPalette.onOrange.opacity(0.85))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      AvatarImage(name: avatar, size: 48)
      HStack(spacing: 4) {
        if tip.done {
          Image(systemName: "checkmark")
            .font(.system(size: 9, weight: .heavy))
        }
        Text(tip.button)
          .font(WidgetFont.heavy(12))
          .lineLimit(1)
          // "Heute erledigt" in a 104 pt box.
          .minimumScaleFactor(0.55)
        if !tip.done {
          Image(systemName: "arrow.forward")
            .font(.system(size: 9, weight: .heavy))
            .flipsForRightToLeftLayoutDirection(true)
        }
      }
      .foregroundColor(.white)
      .padding(.horizontal, tip.done ? 8 : 12)
      .padding(.vertical, 6)
      .background(Capsule().fill(tip.done ? WidgetPalette.green : WidgetPalette.navy))
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 6)
    .frame(width: 104)
    .frame(maxHeight: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(tip.done ? WidgetPalette.navy : WidgetPalette.orange))
  }
}

// MARK: Entry views

struct ClimbWidgetEntryView: View {
  let entry: GrammarLensEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    if let payload = entry.payload, let current = entry.entry {
      Group {
        if family == .systemSmall {
          ClimbSmallView(climb: current.climb, hoursLeft: entry.hoursLeft)
        } else {
          ClimbMediumView(climb: current.climb, hoursLeft: entry.hoursLeft)
        }
      }
      .environment(\.layoutDirection, payload.rtl ? .rightToLeft : .leftToRight)
    } else {
      EmptyWidgetView()
    }
  }
}

struct TipWidgetEntryView: View {
  let entry: GrammarLensEntry

  var body: some View {
    if let payload = entry.payload, let current = entry.entry {
      TipMediumView(tip: current.tip, avatar: current.climb.images.avatar)
        .environment(\.layoutDirection, payload.rtl ? .rightToLeft : .leftToRight)
    } else {
      EmptyWidgetView()
    }
  }
}
