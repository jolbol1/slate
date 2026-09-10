import Foundation
import ImageIO
import UniformTypeIdentifiers
for path in CommandLine.arguments.dropFirst() {
 let url = URL(fileURLWithPath: path)
 let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
 let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 4000]
 let pixels = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)!
 let out = url.deletingPathExtension().appendingPathExtension("normalized.png")
 let destination = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
 CGImageDestinationAddImage(destination, pixels, nil)
 precondition(CGImageDestinationFinalize(destination))
 print(out.path, pixels.width, pixels.height)
}
