import CoreText
import SwiftUI
import UIKit

/// W01's palette (SPEC §3.1), light and dark. Widgets cannot read the app's
/// theme, so the tokens are repeated here once.
enum WidgetPalette {
  static let orange = Color(hex: 0xFF7A1A)
  static let orangeDeep = Color(hex: 0xC95A08)
  static let onOrange = Color(hex: 0x241200)
  static let navy = Color(hex: 0x0D3B8F)
  static let green = Color(hex: 0x1F9D63)
  static let greenSoft = Color(hex: 0xDDF3E7)
  static let greenDeep = Color(hex: 0x13734A)
  static let gold = Color(hex: 0xFFC23C)
  static let goldSoft = Color(hex: 0xFFF1C7)
  static let goldDeep = Color(hex: 0x8A5C00)
  static let cream = Color(hex: 0xFFF1E2)

  // W01 v12: every widget has a designed dark variant (no system grey).
  static func card(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0x1E1C27) : Color(hex: 0xFFFDF8)
  }

  /// The dark card's edge.
  static let darkLine = Color(hex: 0x2E2C36)

  static func text(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0xF2EEE8) : Color(hex: 0x1B1B1F)
  }

  static func muted(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0xA9A6B2) : Color(hex: 0x55555E)
  }

  /// The small waiting widget: orange, one shade deeper in dark, with cream
  /// text there.
  static func waitingFill(_ scheme: ColorScheme) -> LinearGradient {
    scheme == .dark
      ? LinearGradient(
        colors: [Color(hex: 0xD9620E), Color(hex: 0xB84E08)], startPoint: .topLeading,
        endPoint: .bottomTrailing)
      : LinearGradient(colors: [orange, orange], startPoint: .top, endPoint: .bottom)
  }

  static func onWaiting(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0xFFF3E6) : onOrange
  }

  static func waitingBadge(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color.black.opacity(0.22) : Color.white.opacity(0.55)
  }

  /// "Done today" and the check's green, on the card.
  static func doneText(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0x7FD6A6) : greenDeep
  }

  /// The points chip.
  static func pointsFill(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0x3A2F12) : goldSoft
  }

  static func pointsText(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0xFFD45C) : goldDeep
  }

  /// The tip's topic eyebrow.
  static func eyebrow(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0xFFB27A) : Color(hex: 0xA14805)
  }

  /// The rule's pill and the corrected row (green), the wrong row (red).
  static func greenTint(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0x173A2A) : greenSoft
  }

  static func onGreenTint(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0x7FD6A6) : greenDeep
  }

  static func redTint(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0x42201F) : Color(hex: 0xFDE6E3)
  }

  static func onRedTint(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0xFF9C92) : Color(hex: 0xB3261E)
  }

  /// No weak spot yet: the example lines' tint.
  static func plainTint(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? darkLine : Color(hex: 0xF3EFE6)
  }

  /// The tip's Daily Test box: orange waiting (deeper in dark), navy done
  /// (#1B2E6B in dark).
  static func boxFill(done: Bool, _ scheme: ColorScheme) -> Color {
    if done { return scheme == .dark ? Color(hex: 0x1B2E6B) : navy }
    return scheme == .dark ? Color(hex: 0xD9620E) : orange
  }

  static func onBox(done: Bool, _ scheme: ColorScheme) -> Color {
    if done { return Color(hex: 0xC9D6FF) }
    return scheme == .dark ? Color(hex: 0xFFF3E6) : onOrange
  }
}

extension View {
  /// W01 v12: the dark variants' 1 pt edge (#2E2C36); none in light.
  @ViewBuilder
  func darkEdge(_ scheme: ColorScheme) -> some View {
    if scheme == .dark {
      self.overlay(ContainerRelativeShape().strokeBorder(WidgetPalette.darkLine, lineWidth: 1))
    } else {
      self
    }
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

/// The type (INTEGRATE 3c): the app's Nunito Sans, its variable font file
/// bundled in the extension with its OFL licence (`NunitoSans-Variable.ttf`,
/// `OFL-NunitoSans.txt`, from `assets/fonts/`), registered on first use and
/// drawn at the boards' weights on its `wght` axis (900 titles and labels,
/// 700 lines), as the app draws it. Characters Nunito has no glyph for
/// (Japanese, Korean, Arabic) fall back to the system's rounded font, then
/// the system font; without the file, the system's rounded font throughout.
enum WidgetFont {
  static let fileName = "NunitoSans-Variable"
  static let family = "Nunito Sans"
  /// The `wght` variation axis ('wght' as a four-character code).
  static let weightAxis = 0x7767_6874

  static func heavy(_ size: CGFloat) -> Font { font(size, weight: 900, fallback: .heavy) }
  static func bold(_ size: CGFloat) -> Font { font(size, weight: 700, fallback: .bold) }
  static func semibold(_ size: CGFloat) -> Font {
    font(size, weight: 600, fallback: .semibold)
  }

  /// True once the bundled file is registered (the extension's bundle, or
  /// a test bundle for the snapshot tests).
  static let isAvailable: Bool = {
    if UIFont.familyNames.contains(family) { return true }
    for bundle in [Bundle.main] + Bundle.allBundles {
      guard let url = bundle.url(forResource: fileName, withExtension: "ttf") else { continue }
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
      if UIFont.familyNames.contains(family) { return true }
    }
    return false
  }()

  static func uiFont(_ size: CGFloat, weight: CGFloat, fallback: UIFont.Weight) -> UIFont {
    let system = UIFont.systemFont(ofSize: size, weight: fallback)
    let rounded = system.fontDescriptor.withDesign(.rounded) ?? system.fontDescriptor
    guard isAvailable else { return UIFont(descriptor: rounded, size: size) }
    let descriptor = UIFontDescriptor(fontAttributes: [
      .family: family,
      UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [
        weightAxis: weight
      ],
      .cascadeList: [rounded],
    ])
    return UIFont(descriptor: descriptor, size: size)
  }

  private static func font(_ size: CGFloat, weight: CGFloat, fallback: UIFont.Weight) -> Font {
    Font(uiFont(size, weight: weight, fallback: fallback) as CTFont)
  }
}

/// Images the app wrote into the App Group (avatar, mountain crops).
enum WidgetImages {
  static func load(_ name: String) -> UIImage? {
    guard !name.isEmpty, let data = AppGroupStore.read(name) else { return nil }
    return UIImage(data: data)
  }
}

/// Snapshot tests render the views outside WidgetKit, where a container
/// background is not drawn; they switch this on to get a plain background.
enum WidgetRendering {
  static var plainBackground = false
}

extension View {
  /// The widget's background: `containerBackground` on iOS 17+, a plain
  /// background before (and in snapshot tests).
  @ViewBuilder
  func widgetBackground<Background: View>(@ViewBuilder _ background: () -> Background) -> some View {
    if WidgetRendering.plainBackground {
      self.background(background())
    } else if #available(iOS 17.0, *) {
      containerBackground(for: .widget) { background() }
    } else {
      self.background(background())
    }
  }
}
