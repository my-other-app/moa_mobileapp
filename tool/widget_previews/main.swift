// Draws the iOS widgets' views to PNG on a Mac, for a look without a phone
// (docs/HOME_WIDGETS.md, "Previews"). Run tool/widget_previews/render.sh.
//
// The widget files use only SwiftUI, CoreText, CoreImage, ImageIO and
// Foundation, so they compile for macOS as they are; the app's fonts are
// registered from assets/fonts/. Each view is drawn at a widget's size on
// an iPhone 15 Pro Max -- small 170 pt, medium 364 x 170, large 364 x 382,
// with iOS 17's 16 pt margins; the lock screen's round 76, card 172 x 76,
// line 257 x 26 -- light and dark, at 3x. The large ones are also drawn at
// an iPhone SE's size (321 x 324), the tightest there is. The lock screen
// is drawn on a plain wallpaper, in one colour as the system tints it.

import AppKit
import CoreText
import SwiftUI

let arguments = CommandLine.arguments
let fontsDir = URL(fileURLWithPath: arguments[1])
let outDir = URL(fileURLWithPath: arguments[2])

for file in WidgetFonts.files {
  CTFontManagerRegisterFontsForURL(fontsDir.appendingPathComponent(file) as CFURL, .process, nil)
}
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

/// A home-screen widget's frame, on a home screen's grey.
struct Frame<Content: View>: View {
  let width: CGFloat
  let height: CGFloat
  let scheme: ColorScheme
  let content: (WidgetPalette) -> Content

  var body: some View {
    let palette = WidgetPalette.of(scheme)
    content(palette)
      .padding(16)
      .frame(width: width, height: height)
      .background(palette.background)
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .padding(12)
      .background(scheme == .dark ? Color(hex: 0x111111) : Color(hex: 0xD9DEE5))
      .environment(\.colorScheme, scheme)
  }
}

/// A lock-screen widget, on a wallpaper.
struct LockFrame<Content: View>: View {
  let width: CGFloat
  let height: CGFloat
  let scheme: ColorScheme
  let content: () -> Content

  var body: some View {
    content()
      .foregroundColor(scheme == .dark ? .white : Color(hex: 0x1C2430))
      .frame(width: width, height: height)
      .padding(14)
      .background(
        LinearGradient(
          colors: scheme == .dark
            ? [Color(hex: 0x1B2A3A), Color(hex: 0x3B2F4A)]
            : [Color(hex: 0xDCE8F2), Color(hex: 0xF3E6D8)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      )
      .environment(\.colorScheme, scheme)
  }
}

@MainActor
func save<V: View>(_ view: V, _ name: String) {
  let renderer = ImageRenderer(content: view)
  renderer.scale = 3
  guard let image = renderer.cgImage else {
    print("could not draw \(name)")
    return
  }
  let url = outDir.appendingPathComponent("\(name).png")
  guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
  else { return }
  CGImageDestinationAddImage(dest, image, nil)
  CGImageDestinationFinalize(dest)
  print("wrote \(url.path)")
}

/// Each size's width and height, in points.
let sizes: [(String, WidgetSize, CGFloat, CGFloat)] = [
  ("small", .small, 170, 170),
  ("medium", .medium, 364, 170),
  ("large", .large, 364, 382),
]
let seLarge: (CGFloat, CGFloat) = (321, 324)

@MainActor
func render() {
  let now = PreviewData.now
  let three = PreviewData.nextUpThree(now)
  for scheme in [ColorScheme.light, .dark] {
    let theme = scheme == .dark ? "dark" : "light"

    // Next up and Networking at each size (Phase A's names for small and
    // medium).
    for (name, size, width, height) in sizes {
      save(
        Frame(width: width, height: height, scheme: scheme) { palette in
          NextUpContent(data: size == .large ? three : NextUpData.sample, now: now, size: size, palette: palette)
        }, "next-up-\(name)-\(theme)")
      for (state, data) in PreviewData.networking {
        save(
          Frame(width: width, height: height, scheme: scheme) { palette in
            NetworkingContent(data: data, size: size, palette: palette, scheme: scheme)
          }, "networking-\(name)-\(state)-\(theme)")
      }
    }

    // The large ones' other faces.
    let large: [(String, CGFloat, CGFloat)] = [
      ("large", 364, 382), ("large-se", seLarge.0, seLarge.1),
    ]
    for (name, width, height) in large {
      save(
        Frame(width: width, height: height, scheme: scheme) { palette in
          NextUpContent(data: three, now: now, size: .large, palette: palette)
        }, "next-up-\(name)-three-\(theme)")
      save(
        Frame(width: width, height: height, scheme: scheme) { palette in
          NextUpContent(
            data: NextUpData(v: 1, state: NextUpData.upcomingState, link: nil,
              items: [three.items[0]]),
            now: now, size: .large, palette: palette)
        }, "next-up-\(name)-one-\(theme)")
      save(
        Frame(width: width, height: height, scheme: scheme) { palette in
          NetworkingContent(
            data: PreviewData.networkingLarge, size: .large, palette: palette, scheme: scheme)
        }, "networking-\(name)-recently-met-initials-\(theme)")
      save(
        Frame(width: width, height: height, scheme: scheme) { palette in
          NetworkingContent(
            data: PreviewData.networkingLarge, size: .large, palette: palette, scheme: scheme,
            photos: PreviewData.photos)
        }, "networking-\(name)-recently-met-photos-\(theme)")
      save(
        Frame(width: width, height: height, scheme: scheme) { palette in
          NetworkingContent(
            data: PreviewData.networkingEmpty, size: .large, palette: palette, scheme: scheme)
        }, "networking-\(name)-nobody-yet-\(theme)")
      save(
        Frame(width: width, height: height, scheme: scheme) { palette in
          NetworkingContent(
            data: PreviewData.networkingNoQr, size: .large, palette: palette, scheme: scheme)
        }, "networking-\(name)-no-qr-people-\(theme)")
    }

    // The lock screen.
    let today = PreviewData.nextUpToday(now)
    let faces: [(String, NextUpData)] = [
      ("tomorrow", three), ("today", today), ("signed-out", .signedOut),
    ]
    for (face, data) in faces {
      save(
        LockFrame(width: 172, height: 76, scheme: scheme) {
          NextUpAccessory(data: data, now: now, shape: .rectangular)
        }, "lock-next-up-rectangular-\(face)-\(theme)")
      save(
        LockFrame(width: 257, height: 26, scheme: scheme) {
          NextUpAccessory(data: data, now: now, shape: .inline)
        }, "lock-next-up-inline-\(face)-\(theme)")
      save(
        LockFrame(width: 76, height: 76, scheme: scheme) {
          NextUpAccessory(data: data, now: now, shape: .circular)
        }, "lock-next-up-circular-\(face)-\(theme)")
    }
    save(
      LockFrame(width: 76, height: 76, scheme: scheme) { MyQrLockView() },
      "lock-my-qr-circular-\(theme)")

    // "For you": several events, one, none.
    let forYouNow = PreviewData.forYouNow
    let forYou: [(String, ForYouData)] = [
      ("several", PreviewData.forYouSeveral), ("few", PreviewData.forYouFew),
      ("none", PreviewData.forYouNone),
    ]
    for (face, data) in forYou {
      for (name, large, width, height) in [
        ("medium", false, CGFloat(364), CGFloat(170)), ("large", true, CGFloat(364), CGFloat(382)),
      ] {
        save(
          Frame(width: width, height: height, scheme: scheme) { palette in
            ForYouContent(data: data, now: forYouNow, large: large, palette: palette)
          }, "for-you-\(name)-\(face)-\(theme)")
      }
    }
    save(
      Frame(width: seLarge.0, height: seLarge.1, scheme: scheme) { palette in
        ForYouContent(data: PreviewData.forYouSeveral, now: forYouNow, large: true, palette: palette)
      }, "for-you-large-se-several-\(theme)")

    // The event-day card: the lock screen, before and during.
    for (face, card) in PreviewData.eventDay {
      save(LiveActivityFrame(scheme: scheme) { palette in
        EventDayLockView(face: card, now: PreviewData.eventDayNow, palette: palette)
      }, "live-activity-lock-\(face)-\(theme)")
    }
  }

  // The Dynamic Island (always black): compact, minimal, expanded.
  for (face, card) in PreviewData.eventDay {
    let now = PreviewData.eventDayNow
    save(IslandFrame(width: 236, height: 37, radius: 18.5) {
      HStack {
        EventDayIsland.Leading()
        Spacer()
        EventDayIsland.Trailing(face: card, now: now)
      }
      .padding(.horizontal, 14)
    }, "live-activity-island-compact-\(face)")
    save(IslandFrame(width: 371, height: 150, radius: 44) {
      VStack(alignment: .leading, spacing: 10) {
        EventDayIsland.ExpandedTop(face: card, now: now)
        EventDayIsland.ExpandedBottom(face: card)
      }
      .padding(.horizontal, 22)
      .padding(.vertical, 18)
    }, "live-activity-island-expanded-\(face)")
  }
  save(IslandFrame(width: 37, height: 37, radius: 18.5) { EventDayIsland.Minimal() },
    "live-activity-island-minimal")
}

/// A Live Activity on the lock screen: a card of the lock screen's width
/// with its own ground (activityBackgroundTint), on a wallpaper.
struct LiveActivityFrame<Content: View>: View {
  let scheme: ColorScheme
  let content: (WidgetPalette) -> Content

  var body: some View {
    let palette = WidgetPalette.of(scheme)
    content(palette)
      .frame(width: 360, alignment: .leading)
      .background(palette.background)
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .padding(16)
      .background(
        LinearGradient(
          colors: scheme == .dark
            ? [Color(hex: 0x1B2A3A), Color(hex: 0x3B2F4A)]
            : [Color(hex: 0xDCE8F2), Color(hex: 0xF3E6D8)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
      )
      .environment(\.colorScheme, scheme)
  }
}

/// The Dynamic Island: black, rounded, on a status bar's grey.
struct IslandFrame<Content: View>: View {
  let width: CGFloat
  let height: CGFloat
  let radius: CGFloat
  let content: () -> Content

  var body: some View {
    content()
      .frame(width: width, height: height)
      .background(Color.black)
      .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
      .padding(14)
      .background(Color(hex: 0xD9DEE5))
      .environment(\.colorScheme, .dark)
  }
}

MainActor.assumeIsolated { render() }
