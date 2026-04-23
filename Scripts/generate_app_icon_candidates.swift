import AppKit
import Foundation

private struct IconSpec {
    let filename: String
    let size: CGFloat
    let logicalSize: String
    let scale: String
}

private enum IconCandidate: String, CaseIterable {
    case retroCRT = "retro-crt"
    case floppyScript = "floppy-script"
    case pixelForge = "pixel-forge"
    case neonNotebook = "neon-notebook"

    var assetName: String {
        switch self {
        case .retroCRT: "AppIconRetroCRT"
        case .floppyScript: "AppIconFloppyScript"
        case .pixelForge: "AppIconPixelForge"
        case .neonNotebook: "AppIconNeonNotebook"
        }
    }

    var displayName: String {
        switch self {
        case .retroCRT: "Retro CRT"
        case .floppyScript: "Floppy Script"
        case .pixelForge: "Pixel Forge"
        case .neonNotebook: "Neon Notebook"
        }
    }

    var shortDescription: String {
        switch self {
        case .retroCRT: "A beige CRT terminal with green scanlines and a chunky text prompt."
        case .floppyScript: "A 3.5-inch floppy disk with a paper label and code-note personality."
        case .pixelForge: "A forged document-and-caret mark with pixel sparks and industrial color."
        case .neonNotebook: "A neon 90s editor window stacked over a notebook page."
        }
    }
}

private let iconSpecs: [IconSpec] = [
    IconSpec(filename: "icon_16x16.png", size: 16, logicalSize: "16x16", scale: "1x"),
    IconSpec(filename: "icon_16x16@2x.png", size: 32, logicalSize: "16x16", scale: "2x"),
    IconSpec(filename: "icon_32x32.png", size: 32, logicalSize: "32x32", scale: "1x"),
    IconSpec(filename: "icon_32x32@2x.png", size: 64, logicalSize: "32x32", scale: "2x"),
    IconSpec(filename: "icon_128x128.png", size: 128, logicalSize: "128x128", scale: "1x"),
    IconSpec(filename: "icon_128x128@2x.png", size: 256, logicalSize: "128x128", scale: "2x"),
    IconSpec(filename: "icon_256x256.png", size: 256, logicalSize: "256x256", scale: "1x"),
    IconSpec(filename: "icon_256x256@2x.png", size: 512, logicalSize: "256x256", scale: "2x"),
    IconSpec(filename: "icon_512x512.png", size: 512, logicalSize: "512x512", scale: "1x"),
    IconSpec(filename: "icon_512x512@2x.png", size: 1024, logicalSize: "512x512", scale: "2x"),
]

private let assetCatalogURL = URL(fileURLWithPath: "ForgeText/Assets.xcassets", isDirectory: true)
private let previewDirectoryURL = URL(fileURLWithPath: "docs/icon-candidates", isDirectory: true)

private enum GeneratorError: LocalizedError {
    case unknownCandidate(String)
    case missingInstallCandidate
    case exportFailed
    case graphicsContextUnavailable

    var errorDescription: String? {
        switch self {
        case .unknownCandidate(let slug):
            "Unknown icon candidate '\(slug)'. Valid options: \(IconCandidate.allCases.map(\.rawValue).joined(separator: ", "))."
        case .missingInstallCandidate:
            "Pass a candidate slug after --install, for example: --install retro-crt"
        case .exportFailed:
            "Could not export PNG data."
        case .graphicsContextUnavailable:
            "Could not create a drawing context."
        }
    }
}

private let arguments = Array(CommandLine.arguments.dropFirst())

if let installIndex = arguments.firstIndex(of: "--install") {
    guard arguments.indices.contains(installIndex + 1) else {
        throw GeneratorError.missingInstallCandidate
    }

    let slug = arguments[installIndex + 1]
    guard let candidate = IconCandidate(rawValue: slug) else {
        throw GeneratorError.unknownCandidate(slug)
    }

    try render(candidate, to: assetCatalogURL.appendingPathComponent("AppIcon.appiconset", isDirectory: true))
    try renderPreviews(for: [candidate])
    print("Installed \(candidate.displayName) into ForgeText/Assets.xcassets/AppIcon.appiconset")
} else {
    try renderAllCandidates()
    print("Generated \(IconCandidate.allCases.count) ForgeText icon candidates.")
}

private func renderAllCandidates() throws {
    for candidate in IconCandidate.allCases {
        let candidateDirectory = assetCatalogURL.appendingPathComponent("\(candidate.assetName).appiconset", isDirectory: true)
        try render(candidate, to: candidateDirectory)
    }

    try renderPreviews(for: IconCandidate.allCases)
    try renderContactSheet()
}

private func render(_ candidate: IconCandidate, to outputDirectory: URL) throws {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    for spec in iconSpecs {
        let data = try renderIcon(candidate, size: spec.size)
        try data.write(to: outputDirectory.appendingPathComponent(spec.filename), options: .atomic)
    }

    try contentsJSON().write(
        to: outputDirectory.appendingPathComponent("Contents.json"),
        atomically: true,
        encoding: .utf8
    )
}

private func renderPreviews(for candidates: [IconCandidate]) throws {
    try FileManager.default.createDirectory(at: previewDirectoryURL, withIntermediateDirectories: true)

    for candidate in candidates {
        let data = try renderIcon(candidate, size: 1024)
        try data.write(to: previewDirectoryURL.appendingPathComponent("\(candidate.rawValue).png"), options: .atomic)
    }
}

private func renderContactSheet() throws {
    try FileManager.default.createDirectory(at: previewDirectoryURL, withIntermediateDirectories: true)

    let tileSize: CGFloat = 360
    let padding: CGFloat = 36
    let labelHeight: CGFloat = 92
    let sheetWidth = (tileSize * 2) + (padding * 3)
    let sheetHeight = ((tileSize + labelHeight) * 2) + (padding * 3)
    let image = NSImage(size: NSSize(width: sheetWidth, height: sheetHeight))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        throw GeneratorError.graphicsContextUnavailable
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let sheetRect = CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight)
    NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.10, alpha: 1).setFill()
    NSBezierPath(rect: sheetRect).fill()

    for (index, candidate) in IconCandidate.allCases.enumerated() {
        let column = index % 2
        let row = index / 2
        let originX = padding + CGFloat(column) * (tileSize + padding)
        let originY = sheetHeight - padding - tileSize - CGFloat(row) * (tileSize + labelHeight + padding)

        let iconData = try renderIcon(candidate, size: tileSize)
        guard let iconImage = NSImage(data: iconData) else {
            throw GeneratorError.exportFailed
        }

        iconImage.draw(in: CGRect(x: originX, y: originY, width: tileSize, height: tileSize))

        let titleRect = CGRect(x: originX, y: originY - 36, width: tileSize, height: 28)
        drawText(candidate.displayName, in: titleRect, size: 22, weight: .bold, color: NSColor(calibratedRed: 0.98, green: 0.90, blue: 0.62, alpha: 1))

        let bodyRect = CGRect(x: originX, y: originY - 76, width: tileSize, height: 42)
        drawText(candidate.shortDescription, in: bodyRect, size: 12, weight: .medium, color: NSColor.white.withAlphaComponent(0.68))
    }

    image.unlockFocus()
    let data = try pngData(from: image)
    try data.write(to: previewDirectoryURL.appendingPathComponent("contact-sheet.png"), options: .atomic)
}

private func renderIcon(_ candidate: IconCandidate, size: CGFloat) throws -> Data {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        throw GeneratorError.graphicsContextUnavailable
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    switch candidate {
    case .retroCRT:
        drawRetroCRT(size: size, context: context)
    case .floppyScript:
        drawFloppyScript(size: size, context: context)
    case .pixelForge:
        drawPixelForge(size: size, context: context)
    case .neonNotebook:
        drawNeonNotebook(size: size, context: context)
    }

    image.unlockFocus()
    return try pngData(from: image)
}

private func drawRetroCRT(size: CGFloat, context: CGContext) {
    drawIconBackground(
        size: size,
        colors: [
            NSColor(calibratedRed: 0.03, green: 0.07, blue: 0.10, alpha: 1),
            NSColor(calibratedRed: 0.04, green: 0.22, blue: 0.22, alpha: 1),
            NSColor(calibratedRed: 0.16, green: 0.09, blue: 0.24, alpha: 1),
        ],
        context: context
    ) {
        drawPixelGrid(size: size, color: NSColor(calibratedRed: 0.23, green: 0.95, blue: 0.76, alpha: 0.10), spacing: size * 0.085)
    }

    let body = CGRect(x: size * 0.17, y: size * 0.23, width: size * 0.66, height: size * 0.56)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: size * 0.08, yRadius: size * 0.08)
    drawShadow(context: context, size: size) {
        NSColor(calibratedRed: 0.82, green: 0.76, blue: 0.62, alpha: 1).setFill()
        bodyPath.fill()
    }

    NSColor(calibratedRed: 0.43, green: 0.35, blue: 0.26, alpha: 1).setStroke()
    bodyPath.lineWidth = max(1, size * 0.012)
    bodyPath.stroke()

    let screen = CGRect(x: size * 0.25, y: size * 0.39, width: size * 0.50, height: size * 0.29)
    let screenPath = NSBezierPath(roundedRect: screen, xRadius: size * 0.045, yRadius: size * 0.045)
    NSColor(calibratedRed: 0.02, green: 0.12, blue: 0.09, alpha: 1).setFill()
    screenPath.fill()

    NSColor(calibratedRed: 0.47, green: 1.0, blue: 0.48, alpha: 0.88).setStroke()
    for index in 0..<6 {
        let y = screen.minY + screen.height * (0.24 + CGFloat(index) * 0.105)
        let line = NSBezierPath()
        line.move(to: CGPoint(x: screen.minX + screen.width * 0.12, y: y))
        line.line(to: CGPoint(x: screen.maxX - screen.width * 0.12, y: y))
        line.lineWidth = max(1, size * 0.009)
        line.stroke()
    }

    drawText("FT", in: CGRect(x: screen.minX, y: screen.midY - size * 0.07, width: screen.width, height: size * 0.16), size: size * 0.13, weight: .heavy, color: NSColor(calibratedRed: 0.62, green: 1.0, blue: 0.54, alpha: 1), centered: true)

    let base = NSBezierPath(roundedRect: CGRect(x: size * 0.31, y: size * 0.19, width: size * 0.38, height: size * 0.07), xRadius: size * 0.025, yRadius: size * 0.025)
    NSColor(calibratedRed: 0.60, green: 0.49, blue: 0.35, alpha: 1).setFill()
    base.fill()

    drawPixelSparkles(size: size, colors: [
        NSColor(calibratedRed: 1.0, green: 0.40, blue: 0.68, alpha: 1),
        NSColor(calibratedRed: 0.95, green: 0.90, blue: 0.35, alpha: 1),
    ])
}

private func drawFloppyScript(size: CGFloat, context: CGContext) {
    drawIconBackground(
        size: size,
        colors: [
            NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.18, alpha: 1),
            NSColor(calibratedRed: 0.06, green: 0.26, blue: 0.50, alpha: 1),
            NSColor(calibratedRed: 0.46, green: 0.10, blue: 0.45, alpha: 1),
        ],
        context: context
    ) {
        drawDiagonalStripes(size: size, color: NSColor.white.withAlphaComponent(0.07), spacing: size * 0.16)
    }

    let disk = CGRect(x: size * 0.18, y: size * 0.13, width: size * 0.64, height: size * 0.74)
    let diskPath = NSBezierPath(roundedRect: disk, xRadius: size * 0.09, yRadius: size * 0.09)
    drawShadow(context: context, size: size) {
        NSColor(calibratedRed: 0.10, green: 0.36, blue: 0.76, alpha: 1).setFill()
        diskPath.fill()
    }

    NSColor(calibratedRed: 0.74, green: 0.91, blue: 1.0, alpha: 0.34).setStroke()
    diskPath.lineWidth = max(1, size * 0.012)
    diskPath.stroke()

    let shutter = NSBezierPath(roundedRect: CGRect(x: size * 0.28, y: size * 0.62, width: size * 0.43, height: size * 0.17), xRadius: size * 0.02, yRadius: size * 0.02)
    NSColor(calibratedRed: 0.77, green: 0.81, blue: 0.84, alpha: 1).setFill()
    shutter.fill()

    let slot = NSBezierPath(roundedRect: CGRect(x: size * 0.48, y: size * 0.64, width: size * 0.16, height: size * 0.11), xRadius: size * 0.012, yRadius: size * 0.012)
    NSColor(calibratedRed: 0.17, green: 0.20, blue: 0.25, alpha: 1).setFill()
    slot.fill()

    let label = NSBezierPath(roundedRect: CGRect(x: size * 0.28, y: size * 0.25, width: size * 0.44, height: size * 0.27), xRadius: size * 0.025, yRadius: size * 0.025)
    NSColor(calibratedRed: 0.97, green: 0.90, blue: 0.70, alpha: 1).setFill()
    label.fill()

    NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.31, alpha: 0.45).setStroke()
    for index in 0..<3 {
        let y = size * (0.33 + CGFloat(index) * 0.055)
        let line = NSBezierPath()
        line.move(to: CGPoint(x: size * 0.34, y: y))
        line.line(to: CGPoint(x: size * 0.66, y: y))
        line.lineWidth = max(1, size * 0.01)
        line.stroke()
    }

    drawText("{ }", in: CGRect(x: size * 0.29, y: size * 0.13, width: size * 0.42, height: size * 0.13), size: size * 0.10, weight: .heavy, color: NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.31, alpha: 1), centered: true)
    drawPixelSparkles(size: size, colors: [NSColor(calibratedRed: 0.87, green: 0.95, blue: 1, alpha: 1)])
}

private func drawPixelForge(size: CGFloat, context: CGContext) {
    drawIconBackground(
        size: size,
        colors: [
            NSColor(calibratedRed: 0.12, green: 0.10, blue: 0.08, alpha: 1),
            NSColor(calibratedRed: 0.37, green: 0.19, blue: 0.06, alpha: 1),
            NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.14, alpha: 1),
        ],
        context: context
    ) {
        drawCheckerboard(size: size, color: NSColor(calibratedRed: 1.0, green: 0.63, blue: 0.16, alpha: 0.12), block: size * 0.09)
    }

    let page = CGRect(x: size * 0.25, y: size * 0.19, width: size * 0.47, height: size * 0.61)
    let pagePath = foldedPagePath(rect: page, fold: size * 0.13, corner: size * 0.055)
    drawShadow(context: context, size: size) {
        NSColor(calibratedRed: 0.93, green: 0.84, blue: 0.61, alpha: 1).setFill()
        pagePath.fill()
    }

    NSColor(calibratedRed: 0.35, green: 0.22, blue: 0.12, alpha: 0.35).setStroke()
    pagePath.lineWidth = max(1, size * 0.01)
    pagePath.stroke()

    let caret = NSBezierPath(roundedRect: CGRect(x: size * 0.48, y: size * 0.32, width: size * 0.10, height: size * 0.34), xRadius: size * 0.035, yRadius: size * 0.035)
    NSColor(calibratedRed: 0.95, green: 0.24, blue: 0.12, alpha: 1).setFill()
    caret.fill()

    context.saveGState()
    context.translateBy(x: size * 0.62, y: size * 0.36)
    context.rotate(by: -33 * .pi / 180)

    let hammerHandle = NSBezierPath(roundedRect: CGRect(x: -size * 0.045, y: -size * 0.20, width: size * 0.09, height: size * 0.40), xRadius: size * 0.025, yRadius: size * 0.025)
    NSColor(calibratedRed: 0.45, green: 0.24, blue: 0.10, alpha: 1).setFill()
    hammerHandle.fill()

    let hammerHead = NSBezierPath(roundedRect: CGRect(x: -size * 0.17, y: size * 0.14, width: size * 0.34, height: size * 0.10), xRadius: size * 0.025, yRadius: size * 0.025)
    NSColor(calibratedRed: 0.80, green: 0.84, blue: 0.82, alpha: 1).setFill()
    hammerHead.fill()
    context.restoreGState()

    drawPixelSparkles(size: size, colors: [
        NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.28, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.30, blue: 0.18, alpha: 1),
    ])
}

private func drawNeonNotebook(size: CGFloat, context: CGContext) {
    drawIconBackground(
        size: size,
        colors: [
            NSColor(calibratedRed: 0.07, green: 0.04, blue: 0.16, alpha: 1),
            NSColor(calibratedRed: 0.18, green: 0.11, blue: 0.36, alpha: 1),
            NSColor(calibratedRed: 0.03, green: 0.21, blue: 0.30, alpha: 1),
        ],
        context: context
    ) {
        drawPixelGrid(size: size, color: NSColor(calibratedRed: 1.0, green: 0.25, blue: 0.70, alpha: 0.10), spacing: size * 0.10)
    }

    let backPage = NSBezierPath(roundedRect: CGRect(x: size * 0.24, y: size * 0.20, width: size * 0.53, height: size * 0.58), xRadius: size * 0.055, yRadius: size * 0.055)
    drawShadow(context: context, size: size) {
        NSColor(calibratedRed: 0.99, green: 0.83, blue: 0.38, alpha: 1).setFill()
        backPage.fill()
    }

    let window = CGRect(x: size * 0.18, y: size * 0.29, width: size * 0.64, height: size * 0.48)
    let windowPath = NSBezierPath(roundedRect: window, xRadius: size * 0.06, yRadius: size * 0.06)
    NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.16, alpha: 1).setFill()
    windowPath.fill()

    NSColor(calibratedRed: 0.03, green: 0.92, blue: 1.0, alpha: 1).setStroke()
    windowPath.lineWidth = max(2, size * 0.014)
    windowPath.stroke()

    let titlebar = NSBezierPath(roundedRect: CGRect(x: window.minX, y: window.maxY - size * 0.11, width: window.width, height: size * 0.11), xRadius: size * 0.055, yRadius: size * 0.055)
    NSColor(calibratedRed: 0.98, green: 0.21, blue: 0.57, alpha: 1).setFill()
    titlebar.fill()

    for index in 0..<3 {
        let dot = NSBezierPath(ovalIn: CGRect(x: window.minX + size * (0.06 + CGFloat(index) * 0.055), y: window.maxY - size * 0.075, width: size * 0.027, height: size * 0.027))
        NSColor(calibratedRed: 0.99, green: 0.90, blue: 0.42, alpha: 1).setFill()
        dot.fill()
    }

    NSColor(calibratedRed: 0.45, green: 1.0, blue: 0.84, alpha: 0.92).setStroke()
    for index in 0..<4 {
        let y = window.minY + size * (0.12 + CGFloat(index) * 0.07)
        let line = NSBezierPath()
        line.move(to: CGPoint(x: window.minX + size * 0.09, y: y))
        line.line(to: CGPoint(x: window.maxX - size * (index == 3 ? 0.21 : 0.10), y: y))
        line.lineWidth = max(1, size * 0.012)
        line.stroke()
    }

    drawText("</>", in: CGRect(x: window.minX, y: window.minY + size * 0.03, width: window.width, height: size * 0.16), size: size * 0.10, weight: .heavy, color: NSColor(calibratedRed: 1.0, green: 0.89, blue: 0.36, alpha: 1), centered: true)
}

private func drawIconBackground(size: CGFloat, colors: [NSColor], context: CGContext, overlay: () -> Void) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.235
    let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    context.saveGState()
    backgroundPath.addClip()
    NSGradient(colors: colors)?.draw(in: backgroundPath, angle: -38)
    overlay()
    context.restoreGState()

    NSColor.white.withAlphaComponent(0.13).setStroke()
    backgroundPath.lineWidth = max(1, size * 0.01)
    backgroundPath.stroke()
}

private func drawShadow(context: CGContext, size: CGFloat, drawing: () -> Void) {
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -size * 0.035), blur: size * 0.05, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    drawing()
    context.restoreGState()
}

private func drawPixelGrid(size: CGFloat, color: NSColor, spacing: CGFloat) {
    color.setStroke()
    let lineWidth = max(1, size * 0.004)
    var position: CGFloat = 0

    while position <= size {
        let vertical = NSBezierPath()
        vertical.move(to: CGPoint(x: position, y: 0))
        vertical.line(to: CGPoint(x: position, y: size))
        vertical.lineWidth = lineWidth
        vertical.stroke()

        let horizontal = NSBezierPath()
        horizontal.move(to: CGPoint(x: 0, y: position))
        horizontal.line(to: CGPoint(x: size, y: position))
        horizontal.lineWidth = lineWidth
        horizontal.stroke()

        position += spacing
    }
}

private func drawDiagonalStripes(size: CGFloat, color: NSColor, spacing: CGFloat) {
    color.setStroke()
    var offset = -size

    while offset < size * 2 {
        let stripe = NSBezierPath()
        stripe.move(to: CGPoint(x: offset, y: 0))
        stripe.line(to: CGPoint(x: offset + size, y: size))
        stripe.lineWidth = max(2, size * 0.02)
        stripe.stroke()
        offset += spacing
    }
}

private func drawCheckerboard(size: CGFloat, color: NSColor, block: CGFloat) {
    color.setFill()

    for row in 0..<12 {
        for column in 0..<12 where (row + column).isMultiple(of: 2) {
            let rect = CGRect(x: CGFloat(column) * block, y: CGFloat(row) * block, width: block, height: block)
            NSBezierPath(rect: rect).fill()
        }
    }
}

private func drawPixelSparkles(size: CGFloat, colors: [NSColor]) {
    let sparkleRects = [
        CGRect(x: size * 0.14, y: size * 0.72, width: size * 0.05, height: size * 0.05),
        CGRect(x: size * 0.78, y: size * 0.62, width: size * 0.04, height: size * 0.04),
        CGRect(x: size * 0.18, y: size * 0.20, width: size * 0.035, height: size * 0.035),
        CGRect(x: size * 0.72, y: size * 0.18, width: size * 0.055, height: size * 0.055),
    ]

    for (index, rect) in sparkleRects.enumerated() {
        colors[index % colors.count].setFill()
        NSBezierPath(rect: rect).fill()
    }
}

private func foldedPagePath(rect: CGRect, fold: CGFloat, corner: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
    path.line(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
    path.line(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
    path.line(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
    path.curve(
        to: CGPoint(x: rect.maxX - corner, y: rect.maxY),
        controlPoint1: CGPoint(x: rect.maxX, y: rect.maxY),
        controlPoint2: CGPoint(x: rect.maxX, y: rect.maxY)
    )
    path.line(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
    path.curve(
        to: CGPoint(x: rect.minX, y: rect.maxY - corner),
        controlPoint1: CGPoint(x: rect.minX, y: rect.maxY),
        controlPoint2: CGPoint(x: rect.minX, y: rect.maxY)
    )
    path.line(to: CGPoint(x: rect.minX, y: rect.minY + corner))
    path.curve(
        to: CGPoint(x: rect.minX + corner, y: rect.minY),
        controlPoint1: CGPoint(x: rect.minX, y: rect.minY),
        controlPoint2: CGPoint(x: rect.minX, y: rect.minY)
    )
    path.close()
    return path
}

private func drawText(
    _ text: String,
    in rect: CGRect,
    size: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    centered: Bool = false
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = centered ? .center : .left
    paragraph.lineBreakMode = .byWordWrapping

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph,
    ]
    (text as NSString).draw(in: rect, withAttributes: attributes)
}

private func pngData(from image: NSImage) throws -> Data {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw GeneratorError.exportFailed
    }

    return pngData
}

private func contentsJSON() -> String {
    let images = iconSpecs.map { spec in
        """
            {
              "filename" : "\(spec.filename)",
              "idiom" : "mac",
              "scale" : "\(spec.scale)",
              "size" : "\(spec.logicalSize)"
            }
        """
    }.joined(separator: ",\n")

    return """
    {
      "images" : [
    \(images)
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    
    """
}
