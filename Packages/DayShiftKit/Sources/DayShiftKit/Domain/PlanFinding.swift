import Foundation

/// One result of checking a plan, in plain language.
public struct PlanFinding: Hashable, Sendable {
    public enum Factor: String, CaseIterable, Codable, Hashable, Sendable {
        case conditions
        case travel
        case openingHours
        case crowds
    }

    public enum Severity: String, CaseIterable, Codable, Hashable, Sendable {
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

/// Stored as JSON in `ActivityEntity.findingsData`. Decoding runs the same
/// checks as `init(factor:severity:message:)`.
extension PlanFinding: Codable {
    private enum CodingKeys: String, CodingKey {
        case factor
        case severity
        case message
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            factor: container.decode(Factor.self, forKey: .factor),
            severity: container.decode(Severity.self, forKey: .severity),
            message: container.decode(String.self, forKey: .message)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(factor, forKey: .factor)
        try container.encode(severity, forKey: .severity)
        try container.encode(message, forKey: .message)
    }
}
