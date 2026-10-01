// Generates the app icon: a half-filled glass of water on a soft blue squircle.
//
// Run from the project root:
//     swift scripts/generate_icon.swift
//
// It draws the design directly at every size macOS needs (crisper than downscaling),
// writes the PNGs into Assets.xcassets/AppIcon.appiconset, rewrites Contents.json,
// and saves scripts/icon_1024.png so you can preview the design.
//
// Everything is drawn on a 1024x1024 canvas (origin bottom-left, y goes up)
// and scaled down for the smaller sizes.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Design constants (tweak these)

// Apple's macOS icon grid: the shape is 824x824, centred, leaving room for the shadow.
let squircleInset: CGFloat = 100
let squircleCornerRadius: CGFloat = 185

// Background gradient, top to bottom (RGB 0...1).
let backgroundTop = rgb(0.93, 0.97, 1.00)
let backgroundBottom = rgb(0.72, 0.85, 0.96)

// The glass is a tapered tumbler: wider at the top than the bottom.
let glassTopY: CGFloat = 770
let glassBottomY: CGFloat = 250
let glassTopWidth: CGFloat = 380
let glassBottomWidth: CGFloat = 290
let glassBottomCornerRadius: CGFloat = 40
let glassOutlineWidth: CGFloat = 16
let glassFill = rgb(1, 1, 1, alpha: 0.40)
let glassOutline = rgb(1, 1, 1, alpha: 0.95)

// Water fills the glass up to this fraction of its height.
let waterLevel: CGFloat = 0.5
let waterTop = rgb(0.45, 0.70, 0.95)
let waterBottom = rgb(0.22, 0.50, 0.88)
let waterSurface = rgb(0.75, 0.88, 1.00)
let waterSurfaceHeight: CGFloat = 10

// MARK: - Drawing

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

func verticalGradient(top: CGColor, bottom: CGColor) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
               colors: [bottom, top] as CFArray, locations: [0, 1])!
}

/// Outline of the glass: straight tapered sides, rounded bottom corners, open top edge drawn closed.
func glassPath() -> CGPath {
    let centerX: CGFloat = 512
    let topLeft = CGPoint(x: centerX - glassTopWidth / 2, y: glassTopY)
    let topRight = CGPoint(x: centerX + glassTopWidth / 2, y: glassTopY)
    let bottomLeft = CGPoint(x: centerX - glassBottomWidth / 2, y: glassBottomY)
    let bottomRight = CGPoint(x: centerX + glassBottomWidth / 2, y: glassBottomY)

    let path = CGMutablePath()
    path.move(to: topLeft)
    // addArc(tangent1End:tangent2End:) rounds the corner at bottomLeft / bottomRight.
    path.addArc(tangent1End: bottomLeft, tangent2End: bottomRight, radius: glassBottomCornerRadius)
    path.addArc(tangent1End: bottomRight, tangent2End: topRight, radius: glassBottomCornerRadius)
    path.addLine(to: topRight)
    path.closeSubpath()
    return path
}

func drawIcon(in context: CGContext) {
    // 1. Squircle background with a soft shadow underneath.
    let squircleRect = CGRect(x: 0, y: 0, width: 1024, height: 1024).insetBy(dx: squircleInset, dy: squircleInset)
    let squircle = CGPath(roundedRect: squircleRect, cornerWidth: squircleCornerRadius,
                          cornerHeight: squircleCornerRadius, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0, 0, 0, alpha: 0.25))
    context.addPath(squircle)
    context.setFillColor(backgroundBottom)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(squircle)
    context.clip()
    context.drawLinearGradient(verticalGradient(top: backgroundTop, bottom: backgroundBottom),
                               start: CGPoint(x: 0, y: squircleRect.minY),
                               end: CGPoint(x: 0, y: squircleRect.maxY), options: [])
    context.restoreGState()

    // 2. The glass body (faint white fill).
    let glass = glassPath()
    context.addPath(glass)
    context.setFillColor(glassFill)
    context.fillPath()

    // 3. Water: clip to the glass, then fill everything below the water line.
    let waterLineY = glassBottomY + (glassTopY - glassBottomY) * waterLevel
    context.saveGState()
    context.addPath(glass)
    context.clip()
    context.clip(to: CGRect(x: 0, y: 0, width: 1024, height: waterLineY))
    context.drawLinearGradient(verticalGradient(top: waterTop, bottom: waterBottom),
                               start: CGPoint(x: 0, y: glassBottomY),
                               end: CGPoint(x: 0, y: waterLineY), options: [])
    // A thin lighter band at the surface.
    context.setFillColor(waterSurface)
    context.fill(CGRect(x: 0, y: waterLineY - waterSurfaceHeight, width: 1024, height: waterSurfaceHeight))
    context.restoreGState()

    // 4. The glass outline on top.
    context.addPath(glass)
    context.setStrokeColor(glassOutline)
    context.setLineWidth(glassOutlineWidth)
    context.setLineJoin(.round)
    context.strokePath()
}

// MARK: - Output

func renderPNG(pixelSize: Int, to url: URL) {
    let context = CGContext(data: nil, width: pixelSize, height: pixelSize, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(pixelSize) / 1024
    context.scaleBy(x: scale, y: scale)
    drawIcon(in: context)

    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
}

let scriptsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let projectDir = scriptsDir.deletingLastPathComponent()
let iconSetDir = projectDir.appendingPathComponent("water-reminder/Assets.xcassets/AppIcon.appiconset")

// macOS needs each point size at 1x and 2x.
var imageEntries: [String] = []
for pointSize in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = scale == 1 ? "icon_\(pointSize)x\(pointSize).png" : "icon_\(pointSize)x\(pointSize)@2x.png"
        renderPNG(pixelSize: pointSize * scale, to: iconSetDir.appendingPathComponent(filename))
        imageEntries.append("""
            {
              "filename" : "\(filename)",
              "idiom" : "mac",
              "scale" : "\(scale)x",
              "size" : "\(pointSize)x\(pointSize)"
            }
        """)
    }
}

let contentsJSON = """
{
  "images" : [
\(imageEntries.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

"""
try! contentsJSON.write(to: iconSetDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

renderPNG(pixelSize: 1024, to: scriptsDir.appendingPathComponent("icon_1024.png"))
print("Wrote app icons to \(iconSetDir.path)")
