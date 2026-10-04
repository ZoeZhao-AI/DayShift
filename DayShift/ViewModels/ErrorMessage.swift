import Foundation

/// An error in Lin's words: `title` in bold, `detail` below (Section 7.4).
struct ErrorMessage: Equatable {
    let title: String
    let detail: String

    init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }

    init(_ error: Error) {
        let localized = error as? LocalizedError
        title = localized?.errorDescription ?? "Something went wrong."
        detail = localized?.recoverySuggestion ?? "Please try again."
    }
}
