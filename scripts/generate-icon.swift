import AppKit

// Run from the project root: swift scripts/generate-icon.swift
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
NSColor(calibratedRed: 0.035, green: 0.043, blue: 0.047, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()
let ink = NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.91, alpha: 1)
ink.setStroke()
let frame = NSBezierPath(roundedRect: NSRect(x: 156, y: 200, width: 712, height: 570), xRadius: 40, yRadius: 40)
frame.lineWidth = 24
frame.stroke()
ink.setFill()
NSRect(x: 164, y: 608, width: 696, height: 22).fill()
for x in stride(from: 206, to: 820, by: 160) {
    let stripe = NSBezierPath()
    stripe.move(to: NSPoint(x: x, y: 640))
    stripe.line(to: NSPoint(x: x + 62, y: 640))
    stripe.line(to: NSPoint(x: x + 132, y: 748))
    stripe.line(to: NSPoint(x: x + 70, y: 748))
    stripe.close()
    stripe.fill()
}
let text = "01" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedDigitSystemFont(ofSize: 310, weight: .semibold),
    .foregroundColor: ink
]
let textSize = text.size(withAttributes: attributes)
text.draw(at: NSPoint(x: (1024 - textSize.width) / 2, y: 236), withAttributes: attributes)
NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: "Slate/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
