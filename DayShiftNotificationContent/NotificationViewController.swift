//
//  NotificationViewController.swift
//  DayShiftNotificationContent
//
//  Created by Alex W on 3/10/2026.
//

import DayShiftKit
import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

/// The expanded view for the `upcomingPlan` category (Section 6.3). It only
/// displays the payload the app put in `userInfo`: no network, no store.
/// Choosing an option happens in the app ("See options" opens it).
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var hosting: UIHostingController<NotificationContentView>?

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let payload = try? NotificationPayload(userInfo: content.userInfo)
        setActions(for: payload?.situation)

        let contentView = NotificationContentView(title: content.title, bodyText: content.body, payload: payload)
        if let hosting {
            hosting.rootView = contentView
        } else {
            let hosting = UIHostingController(rootView: contentView)
            addChild(hosting)
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            hosting.view.backgroundColor = .clear
            self.view.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                hosting.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])
            hosting.didMove(toParent: self)
            self.hosting = hosting
        }
        let fitting = hosting?.sizeThatFits(in: CGSize(width: view.bounds.width, height: .greatestFiniteMagnitude))
        if let fitting {
            preferredContentSize = CGSize(width: view.bounds.width, height: fitting.height)
        }
    }

    /// A: "Got it" only. B: "See options" and "Keep my plan" (6.3).
    private func setActions(for situation: NotificationPayload.Situation?) {
        switch situation {
        case .leaveReminder:
            extensionContext?.notificationActions = [
                UNNotificationAction(identifier: "gotIt", title: "Got it", options: [])
            ]
        case .planAffected:
            extensionContext?.notificationActions = [
                UNNotificationAction(identifier: "seeOptions", title: "See options", options: [.foreground]),
                UNNotificationAction(identifier: "keepPlan", title: "Keep my plan", options: [])
            ]
        case nil:
            break
        }
    }
}
