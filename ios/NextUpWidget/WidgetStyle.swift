import CoreText
import Foundation
import SwiftUI

// What every widget in the extension shares: the app's colours, its
// typefaces, the yellow pill and the card's ground (docs/HOME_WIDGETS.md).
// Only SwiftUI, CoreText and Foundation, so the same views also draw on a
// Mac for the previews.

// MARK: - Colours

/// The app's colours: ink #2C333D, the tabs' pale yellow #F9FFA1, the
/// icon's teal #17A58F, soft grey #F3F3F3. Dark: the ink as the ground,
/// the yellow as the accent. A QR code is drawn dark on white in both.
struct WidgetPalette {
  let background: Color
  let ink: Color
  let secondary: Color
  let accent: Color
  let dateFill: Color
  let dateInk: Color
  let pillFill: Color
  let pillInk: Color
  let pillOutline: Color
  let reviewFill: Color
  let reviewInk: Color
  /// The ground of a placeholder (no QR yet).
  let soft: Color
  /// The line around the QR's white tile.
  let tileOutline: Color

  static func of(_ scheme: ColorScheme) -> WidgetPalette {
    scheme == .dark
      ? WidgetPalette(
        background: Color(hex: 0x2C333D), ink: .white, secondary: Color(hex: 0xB9C0C9),
        accent: Color(hex: 0xF9FFA1), dateFill: Color(hex: 0x17A58F), dateInk: .white,
        pillFill: Color(hex: 0xF9FFA1), pillInk: Color(hex: 0x2C333D),
        pillOutline: Color(hex: 0xF9FFA1), reviewFill: Color(hex: 0x3B4350),
        reviewInk: Color(hex: 0xF9FFA1), soft: Color(hex: 0x3B4350),
        tileOutline: Color.white.opacity(0))
      : WidgetPalette(
        background: .white, ink: Color(hex: 0x2C333D), secondary: Color(hex: 0x5F6773),
        accent: Color(hex: 0x127F6E), dateFill: Color(hex: 0x17A58F), dateInk: .white,
        pillFill: Color(hex: 0xF9FFA1), pillInk: Color(hex: 0x2C333D),
        pillOutline: Color(hex: 0x2C333D), reviewFill: Color(hex: 0xF3F3F3),
        reviewInk: Color(hex: 0x2C333D), soft: Color(hex: 0xF3F3F3),
        tileOutline: Color(hex: 0x2C333D).opacity(0.12))
  }
}

extension WidgetPalette {
  /// The circle behind someone's initials on "Recently met", by the colour
  /// the app gave them (0-3): the app's teal, pale yellow, ink and soft
  /// grey. In the dark theme the ink and the grey are lighter, to stand off
  /// the ground; the letters are the same in both themes.
  static func circle(_ index: Int, _ scheme: ColorScheme) -> (fill: Color, ink: Color) {
    let dark = scheme == .dark
    switch ((index % 4) + 4) % 4 {
    case 0: return (Color(hex: 0x17A58F), .white)
    case 1: return (Color(hex: 0xF9FFA1), Color(hex: 0x2C333D))
    case 2: return (Color(hex: dark ? 0x4A5361 : 0x2C333D), .white)
    default: return (Color(hex: dark ? 0xB9C0C9 : 0xF3F3F3), Color(hex: 0x2C333D))
    }
  }
}

/// A widget's size, as the views lay it out (WidgetFamily on the phone;
/// named here so the Mac previews can draw each).
enum WidgetSize {
  case small, medium, large
}

/// The lock screen's widget shapes (iOS 16), named apart from WidgetFamily
/// for the same reason.
enum AccessoryShape {
  case circular, rectangular, inline
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

// MARK: - Typefaces

/// The app's typefaces: **DM Sans** for text, **Bebas Neue** for the date
/// block's numbers. Both files are copied into the extension from the
/// app's `assets/fonts/` and registered by `UIAppFonts` in Info.plist.
///
/// DM Sans is one variable font (axes `opsz` 9–40, `wght` 100–1000). A
/// weight is set as a value on its `wght` axis, as the app's text engine
/// does, so semibold is a true 600 at the same optical size (the default,
/// 9) as the app's text; looking a weight up by a name such as
/// "DMSans-SemiBold" lands on a named instance with another optical size.
///
/// When a face can't be had, the system font stands in at the same size and
/// weight: the widget still reads the same, in another face.
enum WidgetFonts {
  static let textFamily = "DM Sans"
  static let displayFamily = "Bebas Neue"

  /// The files, as `UIAppFonts` lists them (copied flat into the bundle).
  static let files = ["DMSans-VariableFont_opsz,wght.ttf", "BebasNeue-Regular.ttf"]

  enum Weight {
    case regular, medium, semibold, bold

    var wght: CGFloat {
      switch self {
      case .regular: return 400
      case .medium: return 500
      case .semibold: return 600
      case .bold: return 700
      }
    }

    var system: Font.Weight {
      switch self {
      case .regular: return .regular
      case .medium: return .medium
      case .semibold: return .semibold
      case .bold: return .bold
      }
    }
  }

  /// DM Sans at [size] and [weight].
  static func text(_ size: CGFloat, _ weight: Weight = .regular) -> Font {
    guard let font = face(textFamily, size: size, wght: weight.wght) else {
      return .system(size: size, weight: weight.system)
    }
    return Font(font)
  }

  /// Bebas Neue at [size]: the date block.
  static func display(_ size: CGFloat) -> Font {
    guard let font = face(displayFamily, size: size, wght: nil) else {
      return .system(size: size, weight: .bold, design: .rounded)
    }
    return Font(font)
  }

  /// The `wght` axis' tag, as CoreText names axes.
  static let weightAxis = NSNumber(value: 0x7767_6874)

  /// [family] at [size] -- with [wght] on its weight axis -- or nil when the
  /// family isn't registered (CoreText answers a missing family with
  /// another one, so the family is checked).
  static func face(_ family: String, size: CGFloat, wght: CGFloat?) -> CTFont? {
    _ = registered
    return make(family, size: size, wght: wght)
  }

  private static func make(_ family: String, size: CGFloat, wght: CGFloat?) -> CTFont? {
    var attributes: [CFString: Any] = [kCTFontFamilyNameAttribute: family]
    if let wght = wght, wght != 400 {
      attributes[kCTFontVariationAttribute] = [weightAxis: NSNumber(value: Double(wght))]
    }
    let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
    let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)
    guard (CTFontCopyFamilyName(font) as String) == family else { return nil }
    return font
  }

  /// `UIAppFonts` registers the files as the extension starts. Should a
  /// family still be missing (an Info.plist without the key), the files in
  /// the bundle are registered here, once, for this process.
  static let registered: Bool = {
    for (family, file) in zip([textFamily, displayFamily], files)
    where make(family, size: 12, wght: nil) == nil {
      if let url = Bundle.main.url(forResource: file, withExtension: nil) {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
      }
    }
    return true
  }()
}

// MARK: - Pieces

/// "Show ticket", "Sign in", "Scan": the app's pale yellow with a dark
/// outline, as its primary buttons.
struct Pill: View {
  let text: String
  let fill: Color
  let ink: Color
  let outline: Color?
  /// An SF Symbol before the words ("Scan").
  var symbol: String? = nil

  var body: some View {
    HStack(spacing: 5) {
      if let symbol = symbol {
        Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
      }
      Text(text)
        .font(WidgetFonts.text(12, .semibold))
        .lineLimit(1)
    }
    .foregroundColor(ink)
    .padding(.horizontal, 12)
    .padding(.vertical, 5)
    .background(Capsule().fill(fill))
    .overlay(Capsule().stroke(outline ?? .clear, lineWidth: 1))
  }
}

/// The soft ground a large widget fills its empty space with: a symbol, a
/// line saying what goes there, and what to do.
struct SoftPanel: View {
  let symbol: String
  let text: String
  var action: String? = nil
  let palette: WidgetPalette

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: symbol)
        .font(.system(size: 20, weight: .regular))
        .foregroundColor(palette.secondary)
      Text(text)
        .font(WidgetFonts.text(12))
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .foregroundColor(palette.secondary)
      if let action = action {
        Text(action)
          .font(WidgetFonts.text(12, .semibold))
          .lineLimit(1)
          .foregroundColor(palette.accent)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.soft))
  }
}

extension View {
  /// A lock-screen widget's ground: none of its own (the lock screen draws
  /// it); iOS 17 asks every widget to name one.
  @ViewBuilder
  func accessoryBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, macOS 14.0, *) {
      containerBackground(for: .widget) { Color.clear }
    } else {
      self
    }
  }

  /// Drawn in the lock screen's accent where it tints widgets (iOS 16).
  @ViewBuilder
  func accentable() -> some View {
    #if os(iOS)
      if #available(iOSApplicationExtension 16.0, *) {
        widgetAccentable()
      } else {
        self
      }
    #else
      self
    #endif
  }

  /// The widget's ground: iOS 17's container background (which keeps the
  /// system's margins), or a padded background before it.
  @ViewBuilder
  func widgetBackground(_ color: Color) -> some View {
    if #available(iOSApplicationExtension 17.0, macOS 14.0, *) {
      containerBackground(for: .widget) { color }
    } else {
      padding(14).background(color)
    }
  }
}
