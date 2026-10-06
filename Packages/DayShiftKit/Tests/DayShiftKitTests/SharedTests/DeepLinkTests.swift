import Foundation
import Testing
@testable import DayShiftKit

struct DeepLinkTests {
    @Test("Every link it builds reads back to the same destination, and other URLs are rejected")
    func linksRoundTripAndOthersAreRejected() throws {
        let day = try LinsThursday()
        let links: [DeepLink] = [.today, .plan(day.run.id), .options(day.focusWork.id)]

        for link in links {
            #expect(DeepLink(url: link.url) == link)
        }
        #expect(DeepLink.today.url.absoluteString == "dayshift://today")
        #expect(DeepLink.plan(day.run.id).url.absoluteString == "dayshift://plan/\(day.run.id.uuidString)")

        let others = [
            "https://dayshift.app/plan/\(day.run.id.uuidString)",   // another scheme
            "dayshift://history",                                   // not a DayShift screen
            "dayshift://plan/not-a-plan-id",                        // no valid id
            "dayshift://plan"                                       // no id at all
        ]
        for text in others {
            let url = try #require(URL(string: text))
            #expect(DeepLink(url: url) == nil, "\(text) should be rejected")
        }
    }
}
