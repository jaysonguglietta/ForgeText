import Foundation

struct EditorMutation {
    let replacementRange: NSRange
    let replacementText: String
    let selectedRange: NSRange
}

enum EditorBehavior {
    static func newlineMutation(in text: String, selectedRange: NSRange, language: DocumentLanguage) -> EditorMutation {
        let nsText = text as NSString
        let clampedSelection = clamp(selectedRange, upperBound: nsText.length)
        let lineRange = lineRange(containing: clampedSelection.location, in: nsText)
        let beforeCaretRange = NSRange(location: lineRange.location, length: clampedSelection.location - lineRange.location)
        let afterCaretRange = NSRange(
            location: clampedSelection.upperBound,
            length: max(0, NSMaxRange(lineRange) - clampedSelection.upperBound)
        )

        let beforeCaret = nsText.substring(with: beforeCaretRange)
        let afterCaret = nsText.substring(with: afterCaretRange)
        let baseIndent = leadingWhitespace(in: beforeCaret)
        let trimmedBefore = beforeCaret.trimmingCharacters(in: .whitespaces)
        let trimmedAfter = afterCaret.trimmingCharacters(in: .whitespacesAndNewlines)
        let indentUnit = language.indentUnit

        if
            let openingBracket = lastNonWhitespaceCharacter(in: beforeCaret),
            let closingBracket = language.bracketPairs[openingBracket],
            firstNonWhitespaceCharacter(in: afterCaret) == closingBracket
        {
            let inserted = "\n\(baseIndent)\(indentUnit)\n\(baseIndent)"
            let caretOffset = ("\n\(baseIndent)\(indentUnit)" as NSString).length
            return EditorMutation(
                replacementRange: clampedSelection,
                replacementText: inserted,
                selectedRange: NSRange(location: clampedSelection.location + caretOffset, length: 0)
            )
        }

        if language == .markdown, let continuationPrefix = markdownContinuationPrefix(for: beforeCaret) {
            let inserted = "\n\(continuationPrefix)"
            return EditorMutation(
                replacementRange: clampedSelection,
                replacementText: inserted,
                selectedRange: NSRange(location: clampedSelection.location + (inserted as NSString).length, length: 0)
            )
        }

        var indentation = baseIndent

        if language.shouldIncreaseIndent(after: trimmedBefore) {
            indentation += indentUnit
        } else if language.shouldDecreaseIndent(before: trimmedAfter) {
            indentation = removingIndentUnit(from: indentation, indentUnit: indentUnit)
        }

        let inserted = "\n\(indentation)"
        return EditorMutation(
            replacementRange: clampedSelection,
            replacementText: inserted,
            selectedRange: NSRange(location: clampedSelection.location + (inserted as NSString).length, length: 0)
        )
    }

    static func tabMutation(in text: String, selectedRange: NSRange, language: DocumentLanguage) -> EditorMutation {
        let nsText = text as NSString
        let clampedSelection = clamp(selectedRange, upperBound: nsText.length)
        let indentUnit = language.indentUnit

        guard clampedSelection.length > 0 else {
            return EditorMutation(
                replacementRange: clampedSelection,
                replacementText: indentUnit,
                selectedRange: NSRange(location: clampedSelection.location + (indentUnit as NSString).length, length: 0)
            )
        }

        let affectedRange = lineRange(covering: clampedSelection, in: nsText)
        let original = nsText.substring(with: affectedRange)
        let indented = original.replacingOccurrences(of: "(?m)^", with: indentUnit, options: .regularExpression)
        return EditorMutation(
            replacementRange: affectedRange,
            replacementText: indented,
            selectedRange: NSRange(location: affectedRange.location, length: (indented as NSString).length)
        )
    }

    static func backtabMutation(in text: String, selectedRange: NSRange, language: DocumentLanguage) -> EditorMutation? {
        let nsText = text as NSString
        let clampedSelection = clamp(selectedRange, upperBound: nsText.length)
        let indentUnit = language.indentUnit

        if clampedSelection.length == 0 {
            let affectedRange = lineRange(containing: clampedSelection.location, in: nsText)
            let original = nsText.substring(with: affectedRange)
            let removal = removableIndentPrefix(in: original, indentUnit: indentUnit)
            guard removal > 0 else {
                return nil
            }

            let updated = String(original.dropFirst(removal))
            let newLocation = max(affectedRange.location, clampedSelection.location - removal)
            return EditorMutation(
                replacementRange: affectedRange,
                replacementText: updated,
                selectedRange: NSRange(location: newLocation, length: 0)
            )
        }

        let affectedRange = lineRange(covering: clampedSelection, in: nsText)
        let original = nsText.substring(with: affectedRange)
        let fragments = splitLines(in: original)
        guard fragments.contains(where: { removableIndentPrefix(in: $0.content, indentUnit: indentUnit) > 0 }) else {
            return nil
        }

        let updated = fragments.map { fragment in
            let removal = removableIndentPrefix(in: fragment.content, indentUnit: indentUnit)
            return String(fragment.content.dropFirst(removal)) + fragment.lineEnding
        }.joined()

        return EditorMutation(
            replacementRange: affectedRange,
            replacementText: updated,
            selectedRange: NSRange(location: affectedRange.location, length: (updated as NSString).length)
        )
    }

    static func toggleCommentMutation(in text: String, selectedRange: NSRange, language: DocumentLanguage) -> EditorMutation? {
        guard let commentPrefix = language.lineCommentPrefix else {
            return nil
        }

        let nsText = text as NSString
        let clampedSelection = clamp(selectedRange, upperBound: nsText.length)
        let affectedRange = clampedSelection.length == 0
            ? lineRange(containing: clampedSelection.location, in: nsText)
            : lineRange(covering: clampedSelection, in: nsText)
        let original = nsText.substring(with: affectedRange)
        let fragments = splitLines(in: original)
        let nonBlankFragments = fragments.filter { !$0.content.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonBlankFragments.isEmpty else {
            return nil
        }

        let shouldUncomment = nonBlankFragments.allSatisfy { fragment in
            commentRemovalRange(in: fragment.content, prefix: commentPrefix) != nil
        }

        let updated = fragments.map { fragment in
            transform(fragment: fragment, commentPrefix: commentPrefix, uncomment: shouldUncomment)
        }.joined()

        if clampedSelection.length == 0 {
            let line = fragments[0]
            let cursorOffset = clampedSelection.location - affectedRange.location
            let insertionPoint = (leadingWhitespace(in: line.content) as NSString).length

            let adjustedOffset: Int
            if shouldUncomment, let removalRange = commentRemovalRange(in: line.content, prefix: commentPrefix) {
                if cursorOffset >= NSMaxRange(removalRange) {
                    adjustedOffset = cursorOffset - removalRange.length
                } else {
                    adjustedOffset = min(cursorOffset, removalRange.location)
                }
            } else {
                let insertion = commentPrefix + (line.content.trimmingCharacters(in: .whitespaces).isEmpty ? "" : " ")
                adjustedOffset = cursorOffset >= insertionPoint
                    ? cursorOffset + (insertion as NSString).length
                    : cursorOffset
            }

            return EditorMutation(
                replacementRange: affectedRange,
                replacementText: updated,
                selectedRange: NSRange(location: affectedRange.location + adjustedOffset, length: 0)
            )
        }

        return EditorMutation(
            replacementRange: affectedRange,
            replacementText: updated,
            selectedRange: NSRange(location: affectedRange.location, length: (updated as NSString).length)
        )
    }

    static func matchedBracketRanges(in text: String, selectedRange: NSRange, language: DocumentLanguage) -> [NSRange] {
        let nsText = text as NSString
        let clampedSelection = clamp(selectedRange, upperBound: nsText.length)
        guard clampedSelection.length == 0, nsText.length > 0 else {
            return []
        }

        let candidateLocations = [clampedSelection.location - 1, clampedSelection.location]
            .filter { $0 >= 0 && $0 < nsText.length }

        for location in candidateLocations {
            let value = character(at: location, in: nsText)

            if let closing = language.bracketPairs[value], let match = findMatchingBracket(
                in: nsText,
                from: location,
                opening: value,
                closing: closing
            ) {
                return [
                    NSRange(location: location, length: 1),
                    NSRange(location: match, length: 1),
                ]
            }

            if
                let opening = language.openingBracket(for: value),
                let match = findMatchingBracket(
                    in: nsText,
                    from: location,
                    opening: opening,
                    closing: value,
                    searchingBackward: true
                )
            {
                return [
                    NSRange(location: match, length: 1),
                    NSRange(location: location, length: 1),
                ]
            }
        }

        return []
    }

    private static func transform(fragment: LineFragment, commentPrefix: String, uncomment: Bool) -> String {
        guard !fragment.content.trimmingCharacters(in: .whitespaces).isEmpty else {
            return fragment.content + fragment.lineEnding
        }

        let indent = leadingWhitespace(in: fragment.content)

        if uncomment, let removalRange = commentRemovalRange(in: fragment.content, prefix: commentPrefix) {
            let nsContent = fragment.content as NSString
            let updated = nsContent.replacingCharacters(in: removalRange, with: "")
            return updated + fragment.lineEnding
        }

        let insertion = commentPrefix + " "
        let content = fragment.content
        let insertionIndex = content.index(content.startIndex, offsetBy: indent.count)
        let updated = content[..<insertionIndex] + insertion + content[insertionIndex...]
        return String(updated) + fragment.lineEnding
    }

    private static func commentRemovalRange(in line: String, prefix: String) -> NSRange? {
        let indentLength = (leadingWhitespace(in: line) as NSString).length
        let remainder = String(line.dropFirst(indentLength))
        guard remainder.hasPrefix(prefix) else {
            return nil
        }

        var removalLength = (prefix as NSString).length
        if remainder.dropFirst(prefix.count).hasPrefix(" ") {
            removalLength += 1
        }

        return NSRange(location: indentLength, length: removalLength)
    }

    private static func splitLines(in text: String) -> [LineFragment] {
        if text.isEmpty {
            return [LineFragment(content: "", lineEnding: "")]
        }

        var fragments: [LineFragment] = []
        var cursor = text.startIndex

        while cursor < text.endIndex {
            var lineEnd = cursor
            while lineEnd < text.endIndex, !text[lineEnd].isNewline {
                lineEnd = text.index(after: lineEnd)
            }

            var lineEnding = ""
            if lineEnd < text.endIndex {
                if text[lineEnd] == "\r" {
                    let next = text.index(after: lineEnd)
                    if next < text.endIndex, text[next] == "\n" {
                        lineEnding = "\r\n"
                        lineEnd = text.index(after: next)
                    } else {
                        lineEnding = "\r"
                        lineEnd = next
                    }
                } else {
                    lineEnding = "\n"
                    lineEnd = text.index(after: lineEnd)
                }
            }

            let contentEnd = lineEnding.isEmpty ? lineEnd : text.index(lineEnd, offsetBy: -lineEnding.count)
            let content = String(text[cursor..<contentEnd])
            fragments.append(LineFragment(content: content, lineEnding: lineEnding))
            cursor = lineEnd
        }

        return fragments
    }

    private static func leadingWhitespace(in text: String) -> String {
        String(text.prefix { $0 == " " || $0 == "\t" })
    }

    private static func removableIndentPrefix(in line: String, indentUnit: String) -> Int {
        if line.hasPrefix("\t") {
            return 1
        }

        let leadingSpaces = line.prefix { $0 == " " }.count
        return min(leadingSpaces, indentUnit.count)
    }

    private static func removingIndentUnit(from indentation: String, indentUnit: String) -> String {
        if indentation.hasSuffix(indentUnit) {
            return String(indentation.dropLast(indentUnit.count))
        }

        if indentation.hasSuffix("\t") {
            return String(indentation.dropLast())
        }

        let trailingSpaces = indentation.reversed().prefix { $0 == " " }.count
        return String(indentation.dropLast(min(indentUnit.count, trailingSpaces)))
    }

    private static func lastNonWhitespaceCharacter(in text: String) -> Character? {
        text.reversed().first { !$0.isWhitespace }
    }

    private static func firstNonWhitespaceCharacter(in text: String) -> Character? {
        text.first { !$0.isWhitespace }
    }

    private static func markdownContinuationPrefix(for lineBeforeCaret: String) -> String? {
        let pattern = #"^(\s*)([-*+]|\d+\.)\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(location: 0, length: (lineBeforeCaret as NSString).length)
        guard let match = regex.firstMatch(in: lineBeforeCaret, range: range), match.numberOfRanges == 4 else {
            return nil
        }

        let nsLine = lineBeforeCaret as NSString
        let indentation = nsLine.substring(with: match.range(at: 1))
        let marker = nsLine.substring(with: match.range(at: 2))
        let content = nsLine.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else {
            return nil
        }

        if Int(marker.dropLast()) != nil {
            let nextValue = (Int(marker.dropLast()) ?? 0) + 1
            return "\(indentation)\(nextValue). "
        }

        return "\(indentation)\(marker) "
    }

    private static func lineRange(containing location: Int, in nsText: NSString) -> NSRange {
        if nsText.length == 0 {
            return NSRange(location: 0, length: 0)
        }

        let clampedLocation = min(max(location, 0), nsText.length)
        return nsText.lineRange(for: NSRange(location: clampedLocation, length: 0))
    }

    private static func lineRange(covering selection: NSRange, in nsText: NSString) -> NSRange {
        if nsText.length == 0 {
            return NSRange(location: 0, length: 0)
        }

        let startLocation = min(max(selection.location, 0), nsText.length)
        let endLocation = min(max(selection.upperBound - (selection.length > 0 ? 1 : 0), 0), nsText.length)
        let startLine = nsText.lineRange(for: NSRange(location: startLocation, length: 0))
        let endLine = nsText.lineRange(for: NSRange(location: endLocation, length: 0))
        return NSUnionRange(startLine, endLine)
    }

    private static func findMatchingBracket(
        in nsText: NSString,
        from location: Int,
        opening: Character,
        closing: Character,
        searchingBackward: Bool = false
    ) -> Int? {
        var depth = 0
        var index = location

        while true {
            index += searchingBackward ? -1 : 1
            guard index >= 0, index < nsText.length else {
                return nil
            }

            let character = character(at: index, in: nsText)
            if character == opening {
                depth += searchingBackward ? -1 : 1
            } else if character == closing {
                depth += searchingBackward ? 1 : -1
            }

            if depth == (searchingBackward ? -1 : -1) {
                return index
            }
        }
    }

    private static func clamp(_ range: NSRange, upperBound: Int) -> NSRange {
        let location = min(max(range.location, 0), upperBound)
        let length = min(max(range.length, 0), upperBound - location)
        return NSRange(location: location, length: length)
    }

    private static func character(at index: Int, in nsText: NSString) -> Character {
        let scalar = UnicodeScalar(nsText.character(at: index)) ?? UnicodeScalar(32)!
        return Character(scalar)
    }
}

private struct LineFragment {
    let content: String
    let lineEnding: String
}

private extension NSRange {
    var upperBound: Int {
        location + length
    }
}
