import CoreGraphics
import Foundation
import ImageIO

/// The small round photos of the people on "Recently met", kept by the app
/// only when the person turned on "Show people's photos in widgets"
/// (lib/features/home_widget/data/widget_photos.dart, docs/HOME_WIDGETS.md).
///
/// Each is a PNG in the App Group's container, `home_widget/<key>.png`, with
/// its path in the App Group's UserDefaults under its key; the widget's JSON
/// names the key of each person's photo. A photo that can't be read --
/// deleted as the person turned photos off, say -- is drawn as initials.
enum WidgetPhotoFiles {
  /// The folder home_widget keeps its files in, inside the container.
  static let folder = "home_widget"

  /// The longest side a photo is decoded at: the app makes them 96 px.
  static let maxPixels = 192

  /// The photos for [people], by key: only those that can be read.
  static func load(_ people: [NetworkingData.Met]) -> [String: CGImage] {
    var images: [String: CGImage] = [:]
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: NextUpData.appGroupId),
      let defaults = UserDefaults(suiteName: NextUpData.appGroupId)
    else { return images }
    for person in people {
      guard let key = person.photo, isKey(key), images[key] == nil,
        let path = defaults.string(forKey: key),
        let url = allowedFile(path, in: container),
        let image = decode(url)
      else { continue }
      images[key] = image
    }
    return images
  }

  /// A photo's key, as the app names them: `networking_photo_<id>`.
  static func isKey(_ key: String) -> Bool {
    guard key.hasPrefix("networking_photo_") else { return false }
    let id = key.dropFirst("networking_photo_".count)
    return !id.isEmpty && id.allSatisfy { $0.isASCII && $0.isNumber }
  }

  /// [path] when it is a PNG in home_widget's folder of [container]; nil for
  /// anywhere else.
  static func allowedFile(_ path: String, in container: URL) -> URL? {
    let file = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
    let folder = container.appendingPathComponent(folder, isDirectory: true)
      .standardizedFileURL.resolvingSymlinksInPath()
    guard file.pathExtension.lowercased() == "png",
      file.deletingLastPathComponent().path == folder.path
    else { return nil }
    return file
  }

  /// The image in [url], no larger than [maxPixels] on its longest side.
  static func decode(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixels,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }
}
