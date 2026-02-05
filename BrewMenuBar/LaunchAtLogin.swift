import Foundation
import ServiceManagement

class LaunchAtLogin {
    static let shared = LaunchAtLogin()
    private let bundleIdentifier = "com.example.BrewMenuBar"

    func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    if service.status == .enabled {
                        // Already enabled, do nothing or handle accordingly
                    } else {
                        try service.register()
                    }
                } else {
                    try service.unregister()
                }
            } catch {
                print("SMAppService failed: \(error)")
            }
        } else {
            // Fallback for older macOS versions
            if !SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled) {
                print("SMLoginItemSetEnabled failed")
            }
        }
    }
}
