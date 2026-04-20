import AppKit
import SwiftUI

private final class StructuredScroller: NSScroller {
    var theme: EditorTheme = .forge {
        didSet {
            needsDisplay = true
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

struct StructuredScrollViewConfigurator: NSViewRepresentable {
    let theme: EditorTheme
    var showsHorizontal: Bool = false
    var showsVertical: Bool = true

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            self.applyConfiguration(from: view)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            self.applyConfiguration(from: view)
        }
    }

    @MainActor
    private func applyConfiguration(from view: NSView) {
        guard let scrollView = enclosingScrollView(startingAt: view) else {
            return
        }

        scrollView.scrollerStyle = .legacy
        scrollView.autohidesScrollers = false
        scrollView.hasHorizontalScroller = showsHorizontal
        scrollView.hasVerticalScroller = showsVertical

        if showsVertical {
            if let scroller = scrollView.verticalScroller as? StructuredScroller {
                scroller.theme = theme
            } else {
                let scroller = StructuredScroller()
                scroller.theme = theme
                scrollView.verticalScroller = scroller
            }
        }

        if showsHorizontal {
            if let scroller = scrollView.horizontalScroller as? StructuredScroller {
                scroller.theme = theme
            } else {
                let scroller = StructuredScroller()
                scroller.theme = theme
                scrollView.horizontalScroller = scroller
            }
        }
    }

    private func enclosingScrollView(startingAt view: NSView?) -> NSScrollView? {
        var currentView = view
        while let candidateView = currentView {
            if let scrollView = candidateView as? NSScrollView {
                return scrollView
            }

            if let scrollView = candidateView.enclosingScrollView {
                return scrollView
            }

            currentView = candidateView.superview
        }

        return nil
    }
}
