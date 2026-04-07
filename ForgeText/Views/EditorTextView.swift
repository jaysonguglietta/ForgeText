import AppKit

@MainActor
final class EditorTextView: NSTextView {
    var documentLanguage: DocumentLanguage = .plainText

    override func insertNewline(_ sender: Any?) {
        apply(EditorBehavior.newlineMutation(in: string, selectedRange: selectedRange(), language: documentLanguage), actionName: "Insert Newline")
    }

    override func insertTab(_ sender: Any?) {
        apply(EditorBehavior.tabMutation(in: string, selectedRange: selectedRange(), language: documentLanguage), actionName: "Indent")
    }

    override func insertBacktab(_ sender: Any?) {
        guard let mutation = EditorBehavior.backtabMutation(in: string, selectedRange: selectedRange(), language: documentLanguage) else {
            NSSound.beep()
            return
        }

        apply(mutation, actionName: "Outdent")
    }

    @objc func toggleCommentSelection(_ sender: Any?) {
        guard let mutation = EditorBehavior.toggleCommentMutation(in: string, selectedRange: selectedRange(), language: documentLanguage) else {
            NSSound.beep()
            return
        }

        apply(mutation, actionName: "Toggle Comment")
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(toggleCommentSelection(_:)) {
            return documentLanguage.lineCommentPrefix != nil
        }

        return super.validateUserInterfaceItem(item)
    }

    private func apply(_ mutation: EditorMutation, actionName: String) {
        guard let textStorage else {
            return
        }

        let currentSelection = selectedRange()
        let replacementRange = clamp(mutation.replacementRange, upperBound: (string as NSString).length)
        let replacementString = mutation.replacementText

        guard shouldChangeText(in: replacementRange, replacementString: replacementString) else {
            return
        }

        textStorage.replaceCharacters(in: replacementRange, with: replacementString)
        didChangeText()
        setSelectedRange(mutation.selectedRange)

        if currentSelection != mutation.selectedRange {
            scrollRangeToVisible(mutation.selectedRange)
        }

        undoManager?.setActionName(actionName)
    }

    private func clamp(_ range: NSRange, upperBound: Int) -> NSRange {
        let location = min(max(range.location, 0), upperBound)
        let length = min(max(range.length, 0), upperBound - location)
        return NSRange(location: location, length: length)
    }
}
