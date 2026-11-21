import CoreGraphics
import CoreImage
import Foundation

/// The person's QR code, made in the widget from the link the app wrote
/// (NetworkingData.profileLink) with CoreImage's own generator: nothing
/// but the link is stored, and the code always matches it.
///
/// Always dark modules on white with a quiet zone of four modules -- also
/// in dark mode -- so any camera reads it.
enum QRCode {
  /// The quiet zone, in modules (the QR standard's minimum).
  static let quietZone = 4

  /// The modules of [text]'s code, row by row (true is dark), without a
  /// margin; error correction M. Nil if it can't be made.
  static func modules(for text: String) -> [[Bool]]? {
    guard !text.isEmpty, let data = text.data(using: .utf8),
      let filter = CIFilter(name: "CIQRCodeGenerator")
    else { return nil }
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    guard let output = filter.outputImage else { return nil }
    let context = CIContext(options: [.useSoftwareRenderer: true])
    guard let image = context.createCGImage(output, from: output.extent) else { return nil }
    return trimmed(pixels(of: image))
  }

  /// [image] as dark or light pixels, top row first; one pixel is one
  /// module in CoreImage's output.
  private static func pixels(of image: CGImage) -> [[Bool]] {
    let width = image.width
    let height = image.height
    var gray = [UInt8](repeating: 255, count: width * height)
    gray.withUnsafeMutableBytes { buffer in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.none.rawValue)
      else { return }
      context.interpolationQuality = .none
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return (0..<height).map { row in
      (0..<width).map { column in gray[row * width + column] < 128 }
    }
  }

  /// [grid] without the light border CoreImage adds around the code.
  static func trimmed(_ grid: [[Bool]]) -> [[Bool]]? {
    let rows = grid.indices.filter { grid[$0].contains(true) }
    let columns = (grid.first?.indices ?? 0..<0).filter { c in grid.contains { $0[c] } }
    guard let top = rows.first, let bottom = rows.last,
      let left = columns.first, let right = columns.last,
      bottom - top == right - left
    else { return nil }
    return grid[top...bottom].map { Array($0[left...right]) }
  }

  /// [modules] drawn [scale] pixels to a module, black on white, with the
  /// quiet zone around: crisp at any size it is shown at with
  /// interpolation off.
  static func image(_ modules: [[Bool]], scale: Int = 8) -> CGImage? {
    let count = modules.count
    guard count > 0, scale > 0 else { return nil }
    let side = (count + quietZone * 2) * scale
    guard
      let context = CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    else { return nil }
    context.setFillColor(gray: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: side, height: side))
    context.setFillColor(gray: 0, alpha: 1)
    for (row, line) in modules.enumerated() {
      for (column, dark) in line.enumerated() where dark {
        // CoreGraphics counts rows from the bottom.
        let x = (column + quietZone) * scale
        let y = side - (row + quietZone + 1) * scale
        context.fill(CGRect(x: x, y: y, width: scale, height: scale))
      }
    }
    return context.makeImage()
  }

  /// [text]'s code, ready to show; nil if it can't be made.
  static func image(for text: String, scale: Int = 8) -> CGImage? {
    modules(for: text).flatMap { image($0, scale: scale) }
  }
}
