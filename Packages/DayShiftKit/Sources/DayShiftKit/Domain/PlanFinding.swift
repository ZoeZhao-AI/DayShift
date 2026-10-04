import Foundation

/// One result of checking a plan, in plain language.
public struct PlanFinding: Hashable, Sendable {
    public enum Factor: String, CaseIterable, Hashable, Sendable {
        case conditions
        case travel
        case openingHours
        case crowds
    }

    public enum Severity: String, CaseIterable, Hashable, Sendable {
        case fine
        case tip
        case problem

        /// Time outside on the way shorter than this is only a tip,
        /// even when a condition is above Lin's limit.
        public static let shortTimeOutsideMinutes = 10

        /// Severity for a condition above Lin's limit while getting to a plan:
        /// "UV 9 · 4 min outside, wear sunscreen" is a tip; 10 minutes or more is a problem.
        public static func forLimitExceededOnTheWay(minutesOutside: Int) -> Severity {
            minutesOutside < shortTimeOutsideMinutes ? .tip : .problem
        }
    }

    public let factor: Factor
    public let severity: Severity
    public let message: String

    /// Crowds are always estimates, so they are never a problem.
    public init(factor: Factor, severity: Severity, message: String) throws {
        guard !(factor == .crowds && severity == .problem) else {
            throw PlanFindingError.crowdsCannotBeAProblem
        }
        self.factor = factor
        self.severity = severity
        self.message = message
    }
}

public enum PlanFindingError: Error, Equatable {
    case crowdsCannotBeAProblem
}
