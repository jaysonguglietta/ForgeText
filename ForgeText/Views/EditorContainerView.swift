import AppKit
import SwiftUI

private final class EditorScroller: NSScroller {
    var theme: EditorTheme = .forge {
        didSet {
            if oldValue != theme {
                needsDisplay = true
            }
        }
    }

    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        18
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        let trackRect = slotRect.insetBy(dx: 2, dy: 2)
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 6, yRadius: 6)
        theme.gutterBackgroundColor.withAlphaComponent(0.95).setFill()
        trackPath.fill()

        theme.borderColor.withAlphaComponent(0.9).setStroke()
        trackPath.lineWidth = 1
        trackPath.stroke()
    }

    override func drawKnob() {
        let knobRect = rect(for: .knob).insetBy(dx: 2, dy: 2)
        guard knobRect.width > 0, knobRect.height > 0 else {
            return
        }

        let knobPath = NSBezierPath(roundedRect: knobRect, xRadius: 6, yRadius: 6)
        theme.accentColor.withAlphaComponent(0.92).setFill()
        knobPath.fill()
    }
}

private final class EditorScrollView: NSScrollView {
    weak var preferredFirstResponder: NSResponder?
    private var hasAppliedInitialFocus = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attemptInitialFocus()
    }

    func attemptInitialFocus() {
        guard !hasAppliedInitialFocus, window != nil, preferredFirstResponder != nil else {
            return
        }

        requestFocus()
    }

    func requestFocus() {
        guard let preferredFirstResponder else {
            return
        }

        DispatchQueue.main.async { [weak self, weak preferredFirstResponder] in
            guard let self, let preferredFirstResponder else {
                return
            }

            self.hasAppliedInitialFocus = self.window?.makeFirstResponder(preferredFirstResponder) ?? false
        }
    }
}

struct EditorContainerView: NSViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange

    let theme: EditorTheme
    let language: DocumentLanguage
    let sourceURL: URL?
    let wrapLines: Bool
    let fontSize: CGFloat
    let findState: FindState
    let largeFileMode: Bool
    let isEditable: Bool
    let focusRequestToken: UUID
    let lineDecorations: [EditorLineDecoration]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = EditorScrollView()
        let verticalScroller = EditorScroller()
        let horizontalScroller = EditorScroller()
        verticalScroller.theme = theme
        horizontalScroller.theme = theme
        scrollView.verticalScroller = verticalScroller
        scrollView.horizontalScroller = horizontalScroller
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.drawsBackground = true
        scrollView.usesPredominantAxisScrolling = false

        let initialSize = fallbackVisibleSize(for: scrollView)
        let textStorage = NSTextStorage(string: text)
        let layoutManager = NSLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(
            containerSize: NSSize(width: initialSize.width, height: CGFloat.greatestFiniteMagnitude)
        )
        layoutManager.addTextContainer(textContainer)

        let textView = EditorTextView(
            frame: NSRect(origin: .zero, size: initialSize),
            textContainer: textContainer
        )
        textView.delegate = context.coordinator
        textView.documentLanguage = language
        textView.completionSourceURL = sourceURL
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.usesFindBar = true
        textView.usesFindPanel = true
        textView.isIncrementalSearchingEnabled = true
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.minSize = NSSize(width: 0, height: initialSize.height)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        configureLayout(for: textView, in: scrollView)
        scrollView.documentView = textView
        scrollView.preferredFirstResponder = textView

        let rulerView = LineNumberRulerView(scrollView: scrollView, textView: textView, theme: theme)
        rulerView.lineDecorations = lineDecorations
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        context.coordinator.textView = textView
        context.coordinator.rulerView = rulerView

        SyntaxHighlighter.apply(
            to: textView,
            theme: theme,
            language: language,
            fontSize: fontSize,
            findState: findState,
            largeFileMode: largeFileMode,
            lineDecorations: lineDecorations
        )
        context.coordinator.lastFocusRequestToken = focusRequestToken
        scrollView.attemptInitialFocus()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else {
            return
        }

        context.coordinator.parent = self
        textView.documentLanguage = language
        textView.completionSourceURL = sourceURL
        textView.isEditable = isEditable
        let layoutState = Coordinator.LayoutState(
            theme: theme,
            wrapLines: wrapLines,
            fontSize: fontSize,
            isEditable: isEditable,
            visibleWidth: Int(fallbackVisibleSize(for: scrollView).width.rounded()),
            visibleHeight: Int(fallbackVisibleSize(for: scrollView).height.rounded())
        )
        if context.coordinator.lastLayoutState != layoutState {
            configureLayout(for: textView, in: scrollView)
            context.coordinator.lastLayoutState = layoutState
        }
        (scrollView.verticalScroller as? EditorScroller)?.theme = theme
        (scrollView.horizontalScroller as? EditorScroller)?.theme = theme
        context.coordinator.rulerView?.theme = theme
        context.coordinator.rulerView?.lineDecorations = lineDecorations

        let hadTextChange = (textView.string != text)
        if hadTextChange {
            context.coordinator.isSyncingFromSwiftUI = true
            textView.string = text
            context.coordinator.isSyncingFromSwiftUI = false
        }

        let clampedRange = clamp(selectedRange, upperBound: (text as NSString).length)
        if textView.selectedRange() != clampedRange {
            context.coordinator.isSyncingFromSwiftUI = true
            textView.setSelectedRange(clampedRange)
            context.coordinator.isSyncingFromSwiftUI = false
        }

        let renderState = Coordinator.RenderState(
            theme: theme,
            language: language,
            wrapLines: wrapLines,
            fontSize: fontSize,
            query: findState.query,
            isCaseSensitive: findState.isCaseSensitive,
            usesRegularExpression: findState.usesRegularExpression,
            currentMatchIndex: findState.currentMatchIndex,
            matchCount: findState.matchRanges.count,
            largeFileMode: largeFileMode,
            lineDecorations: lineDecorations
        )

        if hadTextChange || context.coordinator.lastRenderState != renderState {
            context.coordinator.withRenderPass {
                SyntaxHighlighter.apply(
                    to: textView,
                    theme: theme,
                    language: language,
                    fontSize: fontSize,
                    findState: findState,
                    largeFileMode: largeFileMode,
                    lineDecorations: lineDecorations
                )
            }
            context.coordinator.lastRenderState = renderState
            context.coordinator.rulerView?.needsDisplay = true
        }

        if context.coordinator.lastFocusRequestToken != focusRequestToken {
            context.coordinator.lastFocusRequestToken = focusRequestToken
            (scrollView as? EditorScrollView)?.requestFocus()
        }

        (scrollView as? EditorScrollView)?.attemptInitialFocus()
    }

    private func configureLayout(for textView: NSTextView, in scrollView: NSScrollView) {
        let baseAttributes = baseTextAttributes()
        let visibleSize = fallbackVisibleSize(for: scrollView)

        textView.frame.size = NSSize(
            width: wrapLines ? visibleSize.width : max(textView.frame.size.width, visibleSize.width),
            height: max(textView.frame.size.height, visibleSize.height)
        )
        textView.minSize = NSSize(width: 0, height: visibleSize.height)
        textView.font = baseAttributes[.font] as? NSFont
        textView.backgroundColor = theme.backgroundColor
        textView.textColor = theme.textColor
        textView.insertionPointColor = theme.accentColor
        textView.typingAttributes = baseAttributes
        textView.selectedTextAttributes = [
            .backgroundColor: theme.selectionColor,
            .foregroundColor: theme.textColor,
        ]
        scrollView.backgroundColor = theme.backgroundColor

        if wrapLines {
            scrollView.hasHorizontalScroller = true
            textView.isHorizontallyResizable = false
            textView.isVerticallyResizable = true
            textView.autoresizingMask = [.width]
            textView.textContainer?.containerSize = NSSize(
                width: visibleSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.heightTracksTextView = false
        } else {
            scrollView.hasHorizontalScroller = true
            textView.isHorizontallyResizable = true
            textView.isVerticallyResizable = true
            textView.autoresizingMask = []
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.heightTracksTextView = false
        }
    }

    private func baseTextAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: theme.textColor,
        ]
    }

    private func fallbackVisibleSize(for scrollView: NSScrollView) -> NSSize {
        let visibleSize = scrollView.contentSize
        let width = max(visibleSize.width, 320)
        let height = max(visibleSize.height, 200)
        return NSSize(width: width, height: height)
    }

    private func clamp(_ range: NSRange, upperBound: Int) -> NSRange {
        let location = min(max(range.location, 0), upperBound)
        let length = min(max(range.length, 0), upperBound - location)
        return NSRange(location: location, length: length)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        struct RenderState: Equatable {
            let theme: EditorTheme
            let language: DocumentLanguage
            let wrapLines: Bool
            let fontSize: CGFloat
            let query: String
            let isCaseSensitive: Bool
            let usesRegularExpression: Bool
            let currentMatchIndex: Int?
            let matchCount: Int
            let largeFileMode: Bool
            let lineDecorations: [EditorLineDecoration]
        }

        struct LayoutState: Equatable {
            let theme: EditorTheme
            let wrapLines: Bool
            let fontSize: CGFloat
            let isEditable: Bool
            let visibleWidth: Int
            let visibleHeight: Int
        }

        var parent: EditorContainerView
        weak var textView: EditorTextView?
        weak var rulerView: LineNumberRulerView?
        var isSyncingFromSwiftUI = false
        var isApplyingRenderPass = false
        var lastLayoutState: LayoutState?
        var lastRenderState: RenderState?
        var lastFocusRequestToken: UUID?

        init(_ parent: EditorContainerView) {
            self.parent = parent
        }

        func withRenderPass(_ operation: () -> Void) {
            isApplyingRenderPass = true
            defer { isApplyingRenderPass = false }
            operation()
        }

        func textDidChange(_ notification: Notification) {
            guard !isSyncingFromSwiftUI, let textView else {
                return
            }

            let updatedText = textView.string
            rulerView?.needsDisplay = true

            withRenderPass {
                SyntaxHighlighter.apply(
                    to: textView,
                    theme: parent.theme,
                    language: parent.language,
                    fontSize: parent.fontSize,
                    findState: parent.findState,
                    largeFileMode: parent.largeFileMode,
                    lineDecorations: parent.lineDecorations
                )
            }

            let updatedSelection = textView.selectedRange()
            lastRenderState = renderState()

            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isSyncingFromSwiftUI else {
                    return
                }

                self.parent.text = updatedText
                self.parent.selectedRange = updatedSelection
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isSyncingFromSwiftUI, !isApplyingRenderPass, let textView else {
                return
            }

            let updatedSelection = textView.selectedRange()
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isSyncingFromSwiftUI else {
                    return
                }

                self.parent.selectedRange = updatedSelection
            }
        }

        func renderState() -> RenderState {
            RenderState(
                theme: parent.theme,
                language: parent.language,
                wrapLines: parent.wrapLines,
                fontSize: parent.fontSize,
                query: parent.findState.query,
                isCaseSensitive: parent.findState.isCaseSensitive,
                usesRegularExpression: parent.findState.usesRegularExpression,
                currentMatchIndex: parent.findState.currentMatchIndex,
                matchCount: parent.findState.matchRanges.count,
                largeFileMode: parent.largeFileMode,
                lineDecorations: parent.lineDecorations
            )
        }
    }
}
