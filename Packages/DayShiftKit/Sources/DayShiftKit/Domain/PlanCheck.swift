import Foundation

/// The result of checking one plan against conditions, travel,
/// opening hours and crowds.
public struct PlanCheck: Hashable, Sendable {
    /// Raw values are stored in Core Data as `checkStatusRaw`.
    public enum Status: String, CaseIterable, Hashable, Sendable {
        case looksGood
        case needsAttention
    }

    public let planID: UUID
    public let checkedAt: Date
    public let leaveBy: Date?
    public let travel: TravelEstimate?
    public let findings: [PlanFinding]

    public init(
        planID: UUID,
        checkedAt: Date,
        leaveBy: Date?,
        travel: TravelEstimate?,
        findings: [PlanFinding]
    ) {
        self.planID = planID
        self.checkedAt = checkedAt
        self.leaveBy = leaveBy
        self.travel = travel
        self.findings = findings
    }

    /// Needs attention when any finding is a problem.
    public var overallStatus: Status {
        findings.contains { $0.severity == .problem } ? .needsAttention : .looksGood
    }
}
