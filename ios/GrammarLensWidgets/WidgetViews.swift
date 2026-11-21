import SwiftUI
import WidgetKit

// W01: the "Climb" widget (small, medium A "mountain panorama") and the
// "Tip" widget (medium B: v12, the user's own latest mistake under a short
// rule). No animation, no streak. Every string comes from the payload.
// v12: each widget has a designed dark variant; the medium mountain one is
// unchanged (its art has a dusk version).

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
    .darkEdge(scheme)
    .widgetBackground {
      if climb.isDone {
        WidgetPalette.card(scheme)
      } else {
        WidgetPalette.waitingFill(scheme)
      }
    }
    .widgetURL(URL(string: climb.url))
  }

  /// W01 v12: orange (one shade deeper in dark, with cream text).
  private var waitingHeader: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(climb.label)
        .font(WidgetFont.heavy(11))
        .kerning(0.8)
        .foregroundColor(WidgetPalette.onWaiting(scheme).opacity(0.85))
        .lineLimit(1)
      Text(climb.title)
        .font(WidgetFont.heavy(19))
        .foregroundColor(WidgetPalette.onWaiting(scheme))
        .lineLimit(2)
        .minimumScaleFactor(0.75)
      Text(climb.subtitle)
        .font(WidgetFont.bold(11))
        .foregroundColor(WidgetPalette.onWaiting(scheme).opacity(0.9))
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
          .foregroundColor(WidgetPalette.doneText(scheme))
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
          .foregroundColor(WidgetPalette.pointsText(scheme))
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Capsule().fill(WidgetPalette.pointsFill(scheme)))
    } else {
      Text(climb.stepBadge)
        .font(WidgetFont.heavy(12))
        .foregroundColor(WidgetPalette.onWaiting(scheme))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(WidgetPalette.waitingBadge(scheme)))
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

// MARK: Medium B — your mistake and the rule (W01 v12)

struct TipMediumView: View {
  let tip: WidgetPayload.Tip
  let avatar: String
  /// Done: whole hours to the next test (the box's "next in 10 h").
  var hoursLeft: Int = 10
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    HStack(spacing: 10) {
      Link(destination: URL(string: tip.url) ?? URL(string: "grammarlens://home")!) {
        left
      }
      Link(destination: URL(string: tip.boxUrl ?? tip.url) ?? URL(string: "grammarlens://home")!) {
        box
      }
    }
    .padding(.top, 13)
    .padding(.bottom, 12)
    .padding(.leading, 14)
    .padding(.trailing, 12)
    .darkEdge(scheme)
    .widgetBackground { WidgetPalette.card(scheme) }
    .widgetURL(URL(string: tip.url))
  }

  private var left: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(tip.label)
        .font(WidgetFont.heavy(10.5))
        .kerning(1.1)
        .foregroundColor(WidgetPalette.eyebrow(scheme))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .truncationMode(.tail)
      Text(ruleLine)
        .font(WidgetFont.heavy(15))
        .foregroundColor(WidgetPalette.text(scheme))
        .multilineTextAlignment(.leading)
        .lineLimit(2)
        .truncationMode(.tail)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
      if let mistake = tip.mistake {
        row(sentence(mistake.wrong, struck: true), wrong: true)
        row(sentence(mistake.right, struck: false), wrong: false)
      } else {
        ForEach(Array((tip.examples ?? []).prefix(2).enumerated()), id: \.offset) { _, line in
          example(line)
        }
      }
      Spacer(minLength: 0)
      Text(tip.footer)
        .font(WidgetFont.semibold(10.5))
        .foregroundColor(WidgetPalette.muted(scheme))
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  /// The rule with its key words in a green pill: "<lead> [key] <rest>";
  /// without a key the rule is plain.
  private var ruleLine: AttributedString {
    var line = AttributedString("")
    let lead = tip.lead ?? ""
    if !lead.isEmpty { line += AttributedString(lead) }
    if !tip.rule.isEmpty {
      if !lead.isEmpty { line += AttributedString(" ") }
      var key = AttributedString("\u{00A0}\(tip.rule)\u{00A0}")
      key.backgroundColor = WidgetPalette.greenTint(scheme)
      key.foregroundColor = WidgetPalette.onGreenTint(scheme)
      line += key
    }
    if !tip.example.isEmpty {
      line += AttributedString(line.characters.isEmpty ? tip.example : " \(tip.example)")
    }
    return line
  }

  /// One line of the user's sentence: the wrong words struck through, or
  /// the corrected ones bold.
  private func sentence(_ runs: [WidgetPayload.Run], struck: Bool) -> AttributedString {
    var out = AttributedString("")
    for run in runs {
      var part = AttributedString(run.t)
      if run.m {
        if struck {
          part.strikethroughStyle = .single
          part.foregroundColor = WidgetPalette.onRedTint(scheme)
        } else {
          part.font = WidgetFont.heavy(12)
          part.foregroundColor = WidgetPalette.onGreenTint(scheme)
        }
      }
      out += part
    }
    return out
  }

  private func row(_ text: AttributedString, wrong: Bool) -> some View {
    HStack(spacing: 7) {
      ZStack {
        Circle().fill(wrong ? WidgetPalette.onRedTint(scheme) : WidgetPalette.onGreenTint(scheme))
        Image(systemName: wrong ? "xmark" : "checkmark")
          .font(.system(size: 8, weight: .heavy))
          .foregroundColor(wrong ? WidgetPalette.redTint(scheme) : WidgetPalette.greenTint(scheme))
      }
      .frame(width: 16, height: 16)
      Text(text)
        .font(WidgetFont.bold(12))
        .foregroundColor(WidgetPalette.text(scheme))
        .lineLimit(1)
        .truncationMode(.tail)
        // The sentences are English (SPEC §3.7): left to right everywhere.
        .environment(\.layoutDirection, .leftToRight)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(wrong ? WidgetPalette.redTint(scheme) : WidgetPalette.greenTint(scheme)))
  }

  private func example(_ line: String) -> some View {
    HStack(spacing: 7) {
      Circle().fill(WidgetPalette.muted(scheme)).frame(width: 5, height: 5)
      Text(line)
        .font(WidgetFont.bold(12))
        .foregroundColor(WidgetPalette.text(scheme))
        .lineLimit(1)
        .truncationMode(.tail)
        .environment(\.layoutDirection, .leftToRight)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous).fill(WidgetPalette.plainTint(scheme)))
  }

  private var box: some View {
    VStack(spacing: 0) {
      Text(tip.boxLabel)
        .font(WidgetFont.heavy(10))
        .kerning(1)
        .foregroundColor(WidgetPalette.onBox(done: tip.done, scheme))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Spacer(minLength: 2)
      AvatarImage(name: tip.boxImage ?? avatar, size: 52)
      Spacer(minLength: 2)
      if tip.done {
        VStack(spacing: 1) {
          HStack(spacing: 3) {
            Image(systemName: "checkmark")
              .font(.system(size: 9, weight: .heavy))
            Text(tip.doneLabel ?? tip.button)
              .font(WidgetFont.heavy(11))
              .lineLimit(1)
              .minimumScaleFactor(0.6)
          }
          .foregroundColor(Color(hex: 0x7FD6A6))
          Text(tip.nextLine(hours: hoursLeft))
            .font(WidgetFont.bold(10))
            .foregroundColor(Color(hex: 0xC9D6FF))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
      } else {
        HStack(spacing: 4) {
          Text(tip.button)
            .font(WidgetFont.heavy(12))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
          Image(systemName: "arrow.forward")
            .font(.system(size: 9, weight: .heavy))
            .flipsForRightToLeftLayoutDirection(true)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(WidgetPalette.navy))
      }
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 8)
    .frame(width: 98)
    .frame(maxHeight: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(WidgetPalette.boxFill(done: tip.done, scheme)))
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
      TipMediumView(
        tip: current.tip, avatar: current.climb.images.avatar, hoursLeft: entry.hoursLeft
      )
      .environment(\.layoutDirection, payload.rtl ? .rightToLeft : .leftToRight)
    } else {
      EmptyWidgetView()
    }
  }
}
