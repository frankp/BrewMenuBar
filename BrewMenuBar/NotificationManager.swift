import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func scheduleNotification(outdatedPackages: [BrewPackage]) {
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
