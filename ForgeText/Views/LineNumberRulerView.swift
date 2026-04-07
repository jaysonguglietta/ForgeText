import AppKit

@MainActor
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    var theme: EditorTheme {
        didSet {
            needsDisplay = true
        }
    }

    private let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)

    init(scrollView: NSScrollView, textView: NSTextView, theme: EditorTheme) {
        self.textView = textView
        self.theme = theme
        super.init(scrollView: scrollView, orientation: .verticalRuler)

        clientView = textView
        ruleThickness = 44
        installObservers(for: textView)
        invalidateRuleThickness()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else {
            return
        }

        let gutterRect = bounds

        theme.gutterBackgroundColor.setFill()
        gutterRect.fill()
        drawSeparator(in: gutterRect)

        let text = textView.string as NSString
        let origin = textView.textContainerOrigin

        if text.length == 0 {
            drawLineNumber(1, atY: origin.y + 12, in: gutterRect)
            return
        }

        let visibleRect = textView.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let firstVisibleIndex = min(characterRange.location, max(text.length - 1, 0))

        var lineNumber = lineNumber(at: firstVisibleIndex, in: text)
        var lineStart = text.lineRange(for: NSRange(location: firstVisibleIndex, length: 0)).location

        while lineStart < text.length, lineStart <= NSMaxRange(characterRange) {
            let lineRange = text.lineRange(for: NSRange(location: lineStart, length: 0))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            drawLineNumber(lineNumber, atY: lineRect.minY + origin.y + 1, in: gutterRect)

            lineStart = NSMaxRange(lineRange)
            lineNumber += 1
        }
    }

    private func installObservers(for textView: NSTextView) {
        let center = NotificationCenter.default

        center.addObserver(
            self,
            selector: #selector(handleTextDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )

        center.addObserver(
            self,
            selector: #selector(handleSelectionDidChange),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )

        if let clipView = textView.enclosingScrollView?.contentView {
            clipView.postsBoundsChangedNotifications = true
            center.addObserver(
                self,
                selector: #selector(handleClipViewBoundsDidChange),
                name: NSView.boundsDidChangeNotification,
                object: clipView
            )
        }
    }

    @objc private func handleTextDidChange(_ notification: Notification) {
        invalidateRuleThickness()
        needsDisplay = true
    }

    @objc private func handleSelectionDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    @objc private func handleClipViewBoundsDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    private func invalidateRuleThickness() {
        guard let textView else {
            return
        }

        let lineCount = EditorMetrics(text: textView.string, selectedRange: .init(location: 0, length: 0)).lineCount
        let digits = max(2, String(lineCount).count)
        let sample = String(repeating: "8", count: digits) as NSString
        let width = sample.size(withAttributes: [.font: font]).width
        ruleThickness = max(44, width + 18)
    }

    private func drawSeparator(in rect: NSRect) {
        theme.borderColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.maxX - 0.5, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX - 0.5, y: rect.maxY))
        path.lineWidth = 1
        path.stroke()
    }

    private func drawLineNumber(_ number: Int, atY y: CGFloat, in rect: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: theme.gutterTextColor,
        ]

        let label = "\(number)" as NSString
        let labelSize = label.size(withAttributes: attributes)
        let labelRect = NSRect(
            x: rect.maxX - labelSize.width - 8,
            y: y + 1,
            width: labelSize.width,
            height: labelSize.height
        )

        label.draw(in: labelRect, withAttributes: attributes)
    }

    private func lineNumber(at characterIndex: Int, in text: NSString) -> Int {
        if characterIndex <= 0 {
            return 1
        }

        let prefix = text.substring(to: min(characterIndex, text.length))
        let normalized = prefix
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return normalized.reduce(into: 1) { result, character in
            if character == "\n" {
                result += 1
            }
        }
    }
}
