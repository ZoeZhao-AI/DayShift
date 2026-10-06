import Foundation

/// DayShift's links (Section 7.2), shared by the app, which opens them, and
/// the widget and notifications, which create them.
public enum DeepLink: Equatable, Sendable {
    /// dayshift://today
    case today
    /// dayshift://plan/<id>
    case plan(UUID)
    /// dayshift://options/<id>
    case options(UUID)

    public static let scheme = "dayshift"

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .today:
            components.host = "today"
        case let .plan(id):
            components.host = "plan"
            components.path = "/\(id.uuidString)"
        case let .options(id):
            components.host = "options"
            components.path = "/\(id.uuidString)"
        }
        // Built from fixed parts, so it is always a valid URL.
        return components.url ?? URL(fileURLWithPath: "/")
    }

    /// nil for anything that isn't one of DayShift's links.
    public init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        let id = UUID(uuidString: url.lastPathComponent)
        switch (url.host, id) {
        case ("today", _): self = .today
        case let ("plan", id?): self = .plan(id)
        case let ("options", id?): self = .options(id)
        default: return nil
        }
    }
}
