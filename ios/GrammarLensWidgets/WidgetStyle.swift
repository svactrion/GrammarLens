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

  static func card(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0x252528) : Color(hex: 0xFFFDF8)
  }

  static func text(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0xF2EEE8) : Color(hex: 0x1B1B1F)
  }

  static func muted(_ scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0xA9A6B2) : Color(hex: 0x55555E)
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

/// The type: the system's rounded design at heavy weights (DW2-1: the app's
/// Nunito Sans is an app asset and is not copied into the extension).
enum WidgetFont {
  static func heavy(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
  static func bold(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
  static func semibold(_ size: CGFloat) -> Font {
    .system(size: size, weight: .semibold, design: .rounded)
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
