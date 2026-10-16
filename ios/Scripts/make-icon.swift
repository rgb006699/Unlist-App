// Draws the Unlist app icon: a white shield with a green check mark on a deep
// green gradient. 1024×1024, opaque (iOS rounds the corners itself).
//
// Usage: swift ios/Scripts/make-icon.swift <output.png>

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let out = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "ios/Unlist/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                          space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Couldn't create drawing context")
}

// Top-left origin, like a design tool.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

// Background: vertical gradient, lighter at the top.
let gradient = CGGradient(colorsSpace: space, colors: [rgb(0x1F8A61), rgb(0x0F4F37)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: CGFloat(size)), options: [])

// Shield: pointed bottom, gently peaked top.
let cx: CGFloat = 512
let w: CGFloat = 580
let h: CGFloat = 660
let top: CGFloat = 190
let shield = CGMutablePath()
shield.move(to: CGPoint(x: cx, y: top))
shield.addCurve(to: CGPoint(x: cx + w / 2, y: top + 0.13 * h),
                control1: CGPoint(x: cx + 0.17 * w, y: top + 0.07 * h),
                control2: CGPoint(x: cx + 0.36 * w, y: top + 0.12 * h))
shield.addLine(to: CGPoint(x: cx + w / 2, y: top + 0.48 * h))
shield.addCurve(to: CGPoint(x: cx, y: top + h),
                control1: CGPoint(x: cx + w / 2, y: top + 0.78 * h),
                control2: CGPoint(x: cx + 0.22 * w, y: top + 0.93 * h))
shield.addCurve(to: CGPoint(x: cx - w / 2, y: top + 0.48 * h),
                control1: CGPoint(x: cx - 0.22 * w, y: top + 0.93 * h),
                control2: CGPoint(x: cx - w / 2, y: top + 0.78 * h))
shield.addLine(to: CGPoint(x: cx - w / 2, y: top + 0.13 * h))
shield.addCurve(to: CGPoint(x: cx, y: top),
                control1: CGPoint(x: cx - 0.36 * w, y: top + 0.12 * h),
                control2: CGPoint(x: cx - 0.17 * w, y: top + 0.07 * h))
shield.closeSubpath()

// Soft shadow under the shield.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 40, color: CGColor(gray: 0, alpha: 0.28))
ctx.setFillColor(rgb(0xFFFFFF))
ctx.addPath(shield)
ctx.fillPath()
ctx.restoreGState()

// Check mark.
let check = CGMutablePath()
check.move(to: CGPoint(x: cx - 0.19 * w, y: top + 0.50 * h))
check.addLine(to: CGPoint(x: cx - 0.04 * w, y: top + 0.645 * h))
check.addLine(to: CGPoint(x: cx + 0.21 * w, y: top + 0.36 * h))
ctx.setStrokeColor(rgb(0x16684A))
ctx.setLineWidth(70)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.addPath(check)
ctx.strokePath()

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Couldn't create image")
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Couldn't write \(out)") }
print("Wrote \(out)")
