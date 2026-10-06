import DayShiftKit
import Foundation
import Observation
import UserNotifications

/// The notification centre's delegate (6.3): shows banners while the app is
/// open, and turns a tap or "See options" into a link Today opens.
@Observable
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    /// The link from the last notification Lin opened; Today clears it.
    private(set) var pendingLink: DeepLink?

    func linkOpened() {
        pendingLink = nil
    }

    /// Call at launch, before a notification can open the app. The centre
    /// holds its delegate weakly, so the caller keeps this router.
    func becomeDelegate(of center: UNUserNotificationCenter = .current()) {
        center.delegate = self
    }

    /// Alerts show as banners even while DayShift is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Tapping a notification opens its plan; "See options" opens its options.
    /// "Keep my plan" and "Got it" only dismiss.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let planID = (try? NotificationPayload(userInfo: userInfo))?.planID else { return }

        let link: DeepLink?
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            link = .plan(planID)
        case LocalNotificationScheduler.Action.seeOptions.rawValue:
            link = .options(planID)
        default:
            link = nil
        }
        if let link {
            await MainActor.run { pendingLink = link }
        }
    }
}
