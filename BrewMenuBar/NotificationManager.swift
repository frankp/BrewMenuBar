import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private let lastNotifiedKey = "lastNotifiedOutdatedSignature"

    func maybeScheduleNotification(outdatedPackages: [BrewPackage]) {
        let signature = signatureForPackages(outdatedPackages)

        if signature.isEmpty {
            UserDefaults.standard.removeObject(forKey: lastNotifiedKey)
            return
        }

        let lastSignature = UserDefaults.standard.string(forKey: lastNotifiedKey)
        guard signature != lastSignature else { return }

        UserDefaults.standard.set(signature, forKey: lastNotifiedKey)
        scheduleNotification(outdatedPackages: outdatedPackages)
    }

    func notifyUpgradeFinished(succeeded: Int, failed: [String]) {
        let content = UNMutableNotificationContent()
        content.title = "Brew Menu Bar"
        content.subtitle = failed.isEmpty
            ? "Updated \(succeeded) package\(succeeded == 1 ? "" : "s")"
            : "Updated \(succeeded), \(failed.count) failed"
        if !failed.isEmpty {
            content.body = "Failed: " + failed.joined(separator: ", ")
        }
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func signatureForPackages(_ packages: [BrewPackage]) -> String {
        let parts = packages.map { "\($0.name)|\($0.currentVersion)->\($0.availableVersion)" }
        return parts.sorted().joined(separator: ";")
    }

    private func scheduleNotification(outdatedPackages: [BrewPackage]) {
        let content = UNMutableNotificationContent()
        content.title = "Brew Menu Bar"
        content.subtitle = "\(outdatedPackages.count) outdated packages"
        content.sound = UNNotificationSound.default

        var body = ""
        for package in outdatedPackages {
            body += "\(package.name) (\(package.currentVersion) -> \(package.availableVersion))\n"
        }
        content.body = body

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }
}
