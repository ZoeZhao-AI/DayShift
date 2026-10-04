import Foundation

/// Why a repository couldn't read or save. Says what went wrong and what to do next.
public enum PersistenceError: LocalizedError {
    case couldNotRead(underlying: Error)
    case couldNotSave(underlying: Error)
    case planNotFound
    case placeNotFound

    public var errorDescription: String? {
        switch self {
        case .couldNotRead:
            return "DayShift couldn't read what you saved."
        case .couldNotSave:
            return "Your change couldn't be saved."
        case .planNotFound:
            return "This plan no longer exists."
        case .placeNotFound:
            return "This place is no longer in My Places."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .couldNotRead:
            return "Close DayShift and open it again."
        case .couldNotSave:
            return "Please try again."
        case .planNotFound:
            return "Go back to Today to see your current plans."
        case .placeNotFound:
            return "Choose another place, or add it again in My Places."
        }
    }
}
