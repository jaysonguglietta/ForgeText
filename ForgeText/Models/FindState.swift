import Foundation

struct FindState {
    var isPresented = false
    var query = ""
    var replacement = ""
    var isCaseSensitive = false
    var usesRegularExpression = false
    var matchRanges: [NSRange] = []
    var currentMatchIndex: Int?
    var errorMessage: String?

    var currentMatchRange: NSRange? {
        guard let currentMatchIndex, matchRanges.indices.contains(currentMatchIndex) else {
            return nil
        }

        return matchRanges[currentMatchIndex]
    }

    var summary: String {
        if let errorMessage {
            return errorMessage
        }

        guard !query.isEmpty else {
            return "Find in document"
        }

        if matchRanges.isEmpty {
            return "No matches"
        }

        if let currentMatchIndex {
            return "\(currentMatchIndex + 1) of \(matchRanges.count)"
        }

        return "\(matchRanges.count) matches"
    }
}

