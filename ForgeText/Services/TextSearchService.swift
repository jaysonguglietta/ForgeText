import Foundation

struct SearchOptions: Hashable {
    var isCaseSensitive = false
    var usesRegularExpression = false
}

struct SearchResult {
    let ranges: [NSRange]
    let errorMessage: String?
}

struct ReplacementResult {
    let text: String
    let selectedRange: NSRange
    let replacementCount: Int
}

enum TextSearchService {
    static func search(in text: String, query: String, options: SearchOptions) -> SearchResult {
        guard !query.isEmpty else {
            return SearchResult(ranges: [], errorMessage: nil)
        }

        if options.usesRegularExpression {
            do {
                let regex = try NSRegularExpression(
                    pattern: query,
                    options: options.isCaseSensitive ? [] : [.caseInsensitive]
                )
                let fullRange = NSRange(location: 0, length: (text as NSString).length)
                let matches = regex.matches(in: text, range: fullRange).map(\.range)
                return SearchResult(ranges: matches, errorMessage: nil)
            } catch {
                return SearchResult(ranges: [], errorMessage: "Invalid regular expression")
            }
        }

        let nsText = text as NSString
        let compareOptions: NSString.CompareOptions = options.isCaseSensitive ? [] : [.caseInsensitive]
        var searchRange = NSRange(location: 0, length: nsText.length)
        var matches: [NSRange] = []

        while searchRange.length > 0 {
            let found = nsText.range(of: query, options: compareOptions, range: searchRange)
            if found.location == NSNotFound {
                break
            }

            matches.append(found)

            let nextLocation = found.location + max(found.length, 1)
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }

        return SearchResult(ranges: matches, errorMessage: nil)
    }

    static func replaceCurrent(
        in text: String,
        selectedRange: NSRange,
        query: String,
        replacement: String,
        options: SearchOptions
    ) -> ReplacementResult? {
        guard !query.isEmpty else {
            return nil
        }

        let nsText = text as NSString

        if options.usesRegularExpression {
            guard
                let regex = try? NSRegularExpression(
                    pattern: query,
                    options: options.isCaseSensitive ? [] : [.caseInsensitive]
                ),
                let match = regex.firstMatch(in: text, options: [.anchored], range: selectedRange)
            else {
                return nil
            }

            let replacementString = regex.replacementString(
                for: match,
                in: text,
                offset: 0,
                template: replacement
            )

            let updatedText = nsText.replacingCharacters(in: match.range, with: replacementString)
            return ReplacementResult(
                text: updatedText,
                selectedRange: NSRange(location: match.range.location, length: (replacementString as NSString).length),
                replacementCount: 1
            )
        }

        let queryRange = nsText.range(of: query, options: options.isCaseSensitive ? [] : [.caseInsensitive], range: selectedRange)
        guard queryRange.location != NSNotFound, queryRange == selectedRange else {
            return nil
        }

        let updatedText = nsText.replacingCharacters(in: selectedRange, with: replacement)
        return ReplacementResult(
            text: updatedText,
            selectedRange: NSRange(location: selectedRange.location, length: (replacement as NSString).length),
            replacementCount: 1
        )
    }

    static func replaceAll(
        in text: String,
        query: String,
        replacement: String,
        options: SearchOptions
    ) -> ReplacementResult? {
        guard !query.isEmpty else {
            return nil
        }

        let matches = search(in: text, query: query, options: options)
        guard !matches.ranges.isEmpty else {
            return ReplacementResult(text: text, selectedRange: NSRange(location: 0, length: 0), replacementCount: 0)
        }

        if options.usesRegularExpression {
            guard let regex = try? NSRegularExpression(
                pattern: query,
                options: options.isCaseSensitive ? [] : [.caseInsensitive]
            ) else {
                return nil
            }

            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            let replaced = regex.stringByReplacingMatches(in: text, range: fullRange, withTemplate: replacement)
            return ReplacementResult(
                text: replaced,
                selectedRange: NSRange(location: 0, length: 0),
                replacementCount: matches.ranges.count
            )
        }

        let nsText = text as NSString
        var updatedText = text

        for range in matches.ranges.reversed() {
            updatedText = (updatedText as NSString).replacingCharacters(in: range, with: replacement)
        }

        let finalLocation = min((updatedText as NSString).length, nsText.length)
        return ReplacementResult(
            text: updatedText,
            selectedRange: NSRange(location: finalLocation, length: 0),
            replacementCount: matches.ranges.count
        )
    }
}

