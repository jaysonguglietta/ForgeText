import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first
    ?? "ForgeText/Assets.xcassets/AppIcon.appiconset"
let outputDirectory = URL(fileURLWithPath: outputPath, isDirectory: true)

let iconSpecs: [(filename: String, size: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for icon in iconSpecs {
    let pngData = try renderIcon(size: icon.size)
    try pngData.write(to: outputDirectory.appendingPathComponent(icon.filename), options: .atomic)
}

private func renderIcon(size: CGFloat) throws -> Data {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        throw NSError(domain: "ForgeTextIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create drawing context."])
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
    let cornerRadius = size * 0.24

    let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    backgroundPath.addClip()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1),
        NSColor(calibratedRed: 0.24, green: 0.27, blue: 0.33, alpha: 1),
    ])!
    gradient.draw(in: backgroundPath, angle: -45)

    NSColor.white.withAlphaComponent(0.08).setStroke()
    backgroundPath.lineWidth = max(1, size * 0.008)
    backgroundPath.stroke()

    drawPage(in: rect, size: size)
    drawCaret(in: rect, size: size)

    image.unlockFocus()

    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "ForgeTextIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not export PNG data."])
    }

    return pngData
}

private func drawPage(in rect: CGRect, size: CGFloat) {
    let width = size * 0.58
    let height = size * 0.68
    let originX = size * 0.23
    let originY = size * 0.16
    let corner = size * 0.08
    let fold = size * 0.14

    let page = NSBezierPath()
    page.move(to: CGPoint(x: originX + corner, y: originY))
    page.line(to: CGPoint(x: originX + width - fold, y: originY))
    page.line(to: CGPoint(x: originX + width, y: originY + fold))
    page.line(to: CGPoint(x: originX + width, y: originY + height - corner))
    page.curve(
        to: CGPoint(x: originX + width - corner, y: originY + height),
        controlPoint1: CGPoint(x: originX + width, y: originY + height),
        controlPoint2: CGPoint(x: originX + width, y: originY + height)
    )
    page.line(to: CGPoint(x: originX + corner, y: originY + height))
    page.curve(
        to: CGPoint(x: originX, y: originY + height - corner),
        controlPoint1: CGPoint(x: originX, y: originY + height),
        controlPoint2: CGPoint(x: originX, y: originY + height)
    )
    page.line(to: CGPoint(x: originX, y: originY + corner))
    page.curve(
        to: CGPoint(x: originX + corner, y: originY),
        controlPoint1: CGPoint(x: originX, y: originY),
        controlPoint2: CGPoint(x: originX, y: originY)
    )
    page.close()

    NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.88, alpha: 1).setFill()
    page.fill()

    NSColor.black.withAlphaComponent(0.08).setStroke()
    page.lineWidth = max(1, size * 0.004)
    page.stroke()

    let foldPath = NSBezierPath()
    foldPath.move(to: CGPoint(x: originX + width - fold, y: originY))
    foldPath.line(to: CGPoint(x: originX + width - fold, y: originY + fold))
    foldPath.line(to: CGPoint(x: originX + width, y: originY + fold))
    NSColor.white.withAlphaComponent(0.25).setFill()
    foldPath.fill()
}

private func drawCaret(in rect: CGRect, size: CGFloat) {
    let caretWidth = size * 0.10
    let caretHeight = size * 0.43
    let caretX = size * 0.47
    let caretY = size * 0.28

    let caretRect = CGRect(x: caretX, y: caretY, width: caretWidth, height: caretHeight)
    let caretPath = NSBezierPath(roundedRect: caretRect, xRadius: caretWidth / 2, yRadius: caretWidth / 2)

    let accentGradient = NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.50, blue: 0.27, alpha: 1),
        NSColor(calibratedRed: 0.96, green: 0.28, blue: 0.16, alpha: 1),
    ])!
    accentGradient.draw(in: caretPath, angle: -90)

    let crossbarRect = CGRect(
        x: size * 0.43,
        y: size * 0.57,
        width: size * 0.17,
        height: size * 0.09
    )
    let crossbar = NSBezierPath(roundedRect: crossbarRect, xRadius: size * 0.02, yRadius: size * 0.02)
    NSColor(calibratedRed: 1.0, green: 0.50, blue: 0.27, alpha: 1).setFill()
    crossbar.fill()
}

print("Generated ForgeText app icons in \(outputDirectory.path)")
