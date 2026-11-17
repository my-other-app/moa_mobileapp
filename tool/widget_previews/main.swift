// Draws the iOS widgets' views to PNG on a Mac, for a look without a phone
// (docs/HOME_WIDGETS.md, "Previews"). Run tool/widget_previews/render.sh.
//
// The widget files use only SwiftUI, CoreText, CoreImage and Foundation, so
// they compile for macOS as they are; the app's fonts are registered from
// assets/fonts/. Each view is drawn at a home-screen widget's size (an
// iPhone 15 Pro Max: small 170 pt, medium 364 x 170 pt) with iOS 17's
// 16 pt margins, light and dark, at 3x.

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

struct Frame<Content: View>: View {
  let medium: Bool
  let scheme: ColorScheme
  let content: (WidgetPalette) -> Content

  var body: some View {
    let palette = WidgetPalette.of(scheme)
    content(palette)
      .padding(16)
      .frame(width: medium ? 364 : 170, height: 170)
      .background(palette.background)
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .padding(12)
      .background(scheme == .dark ? Color(hex: 0x111111) : Color(hex: 0xD9DEE5))
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

@MainActor
func render() {
  let now = Date()
  let sample = NextUpData.sample
  for scheme in [ColorScheme.light, .dark] {
    let theme = scheme == .dark ? "dark" : "light"
    for medium in [false, true] {
      let size = medium ? "medium" : "small"
      save(
        Frame(medium: medium, scheme: scheme) { palette in
          NextUpContent(data: sample, now: now, medium: medium, palette: palette)
        }, "next-up-\(size)-\(theme)")
      for (state, data) in PreviewData.networking {
        save(
          Frame(medium: medium, scheme: scheme) { palette in
            NetworkingContent(data: data, medium: medium, palette: palette)
          }, "networking-\(size)-\(state)-\(theme)")
      }
    }
  }
}

MainActor.assumeIsolated { render() }
