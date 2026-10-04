import Foundation

/// Why weather and air quality couldn't be fetched. Says what went wrong and
/// what to do next.
public enum ConditionsServiceError: LocalizedError {
    /// No connection, or the request timed out.
    case unreachable(underlying: Error)
    /// Open-Meteo answered with an HTTP status other than 200.
    case requestFailed(statusCode: Int)
    /// The response couldn't be read as a forecast.
    case invalidResponse(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .unreachable:
            return "DayShift couldn't reach the weather service."
        case .requestFailed, .invalidResponse:
            return "The weather service didn't send a usable forecast."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unreachable:
            return "Check your internet connection and try again."
        case .requestFailed, .invalidResponse:
            return "Try again in a few minutes."
        }
    }
}
