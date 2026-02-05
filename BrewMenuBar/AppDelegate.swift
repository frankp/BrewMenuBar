import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    let brewService = BrewService()
    var timer: Timer?
    var preferencesWindow: NSWindow?
    var animationTimer: Timer?
    var animationFrame = 0

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print(error.localizedDescription)
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "mug", accessibilityDescription: "Brew Menu Bar")?.tint(
                    color: .white)
        }

        updateMenu()

        setupTimer()

        NotificationCenter.default.addObserver(
            self, selector: #selector(setupTimer), name: UserDefaults.didChangeNotification,
            object: nil)
    }

    @objc func setupTimer() {
        timer?.invalidate()
        let refreshInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        let interval = refreshInterval > 0 ? refreshInterval : 3600.0
        timer = Timer.scheduledTimer(
            timeInterval: interval, target: self, selector: #selector(updateMenu), userInfo: nil,
            repeats: true)
    }

    @objc func updateMenu() {
        startAnimation()
        let menu = NSMenu()
        menu.addItem(withTitle: "Checking for updates...", action: nil, keyEquivalent: "")
        statusItem?.menu = menu

        Task {
            do {
                let outdatedPackages = try await brewService.checkForUpdates()
                await MainActor.run {
                    self.stopAnimation()
                    let newMenu = NSMenu()

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .none
                    dateFormatter.timeStyle = .short
                    let lastCheckedTime = dateFormatter.string(from: Date())

                    let lastCheckedItem = newMenu.addItem(
                        withTitle: "Last Checked: \(lastCheckedTime)", action: nil,
                        keyEquivalent: "")
                    lastCheckedItem.isEnabled = false

                    newMenu.addItem(NSMenuItem.separator())

                    if outdatedPackages.isEmpty {
                        newMenu.addItem(
                            withTitle: "No updates available.", action: nil, keyEquivalent: "")
                    } else {
                        NotificationManager.shared.scheduleNotification(
                            outdatedPackages: outdatedPackages)
                        newMenu.addItem(
                            withTitle: "Outdated Packages:", action: nil, keyEquivalent: "")
                        for package in outdatedPackages {
                            let packageItem = newMenu.addItem(
                                withTitle:
                                    "\(package.name) (\(package.currentVersion) -> \(package.availableVersion))",
                                action: nil, keyEquivalent: "")

                            let packageMenu = NSMenu()

                            // Update Item
                            let updateItem = packageMenu.addItem(
                                withTitle: "Update", action: #selector(self.updatePackage),
                                keyEquivalent: "")
                            updateItem.target = self
                            updateItem.representedObject = package.name

                            // Uninstall Item
                            let uninstallItem = packageMenu.addItem(
                                withTitle: "Uninstall", action: #selector(self.uninstallPackage),
                                keyEquivalent: "")
                            uninstallItem.target = self
                            uninstallItem.representedObject = package.name

                            // Homepage Item
                            if let homepage = package.homepage, !homepage.isEmpty {
                                let homepageItem = packageMenu.addItem(
                                    withTitle: "Home Page", action: #selector(self.openHomepage),
                                    keyEquivalent: "")
                                homepageItem.target = self
                                homepageItem.representedObject = homepage
                            }

                            packageItem.submenu = packageMenu
                        }
                        newMenu.addItem(NSMenuItem.separator())
                        let updateAllItem = newMenu.addItem(
                            withTitle: "Update All", action: #selector(self.updateAll),
                            keyEquivalent: "u")
                        updateAllItem.target = self
                    }

                    newMenu.addItem(NSMenuItem.separator())
                    let refreshItem = newMenu.addItem(
                        withTitle: "Refresh", action: #selector(self.updateMenu), keyEquivalent: "r"
                    )
                    refreshItem.target = self

                    // Add Preferences item
                    newMenu.addItem(NSMenuItem.separator())
                    let preferencesItem = newMenu.addItem(
                        withTitle: "Preferences...", action: #selector(self.openPreferences),
                        keyEquivalent: ",")
                    preferencesItem.target = self
                    preferencesItem.image = NSImage(
                        systemSymbolName: "gearshape", accessibilityDescription: "Preferences")

                    newMenu.addItem(
                        withTitle: "Quit", action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

                    if let button = self.statusItem?.button {
                        if outdatedPackages.isEmpty {
                            button.image = NSImage(
                                systemSymbolName: "mug", accessibilityDescription: "Brew Menu Bar")?
                                .tint(color: .white)
                        } else {
                            button.image = NSImage(
                                systemSymbolName: "mug.fill",
                                accessibilityDescription: "Brew Menu Bar (Updates available)")?
                                .tint(
                                    color: .white)
                        }
                    }
                    self.statusItem?.menu = newMenu
                }
            } catch {
                await MainActor.run {
                    self.stopAnimation()
                    print("Error checking for updates: \(error)")
                    // Optionally show an error state in the menu
                    let errorMenu = NSMenu()
                    errorMenu.addItem(
                        withTitle: "Error checking for updates", action: nil, keyEquivalent: "")
                    errorMenu.addItem(
                        withTitle: "Try again", action: #selector(self.updateMenu),
                        keyEquivalent: "r")
                    errorMenu.addItem(NSMenuItem.separator())
                    errorMenu.addItem(
                        withTitle: "Quit", action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
                    self.statusItem?.menu = errorMenu
                }
            }
        }
    }

    @objc func uninstallPackage(_ sender: NSMenuItem) {
        guard let packageName = sender.representedObject as? String else { return }

        startAnimation()
        let menu = NSMenu()
        menu.addItem(withTitle: "Uninstalling \(packageName)...", action: nil, keyEquivalent: "")
        statusItem?.menu = menu

        Task {
            do {
                try await brewService.uninstallPackage(packageName: packageName)
                await MainActor.run {
                    self.stopAnimation()
                    self.updateMenu()
                }
            } catch {
                await MainActor.run {
                    self.stopAnimation()
                    print("Error uninstalling \(packageName): \(error)")
                }
            }
        }
    }

    @objc func openHomepage(_ sender: NSMenuItem) {
        guard let urlString = sender.representedObject as? String, let url = URL(string: urlString)
        else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func updateAll() {
        startAnimation()
        let menu = NSMenu()
        menu.addItem(withTitle: "Updating...", action: nil, keyEquivalent: "")
        statusItem?.menu = menu

        Task {
            do {
                try await brewService.updateAll()
                await MainActor.run {
                    self.stopAnimation()
                    self.updateMenu()
                }
            } catch {
                await MainActor.run {
                    self.stopAnimation()
                    print("Error updating all: \(error)")
                    // Provide feedback to user about failure, maybe via notification or alert
                }
            }
        }
    }

    @objc func updatePackage(_ sender: NSMenuItem) {
        guard let packageName = sender.representedObject as? String else { return }

        startAnimation()
        let menu = NSMenu()
        menu.addItem(withTitle: "Updating \(packageName)...", action: nil, keyEquivalent: "")
        statusItem?.menu = menu

        Task {
            do {
                try await brewService.updatePackage(packageName: packageName)
                await MainActor.run {
                    self.stopAnimation()
                    self.updateMenu()
                }
            } catch {
                await MainActor.run {
                    self.stopAnimation()
                    print("Error updating \(packageName): \(error)")
                }
            }
        }
    }

    @objc func openPreferences() {
        if preferencesWindow == nil {
            let preferencesView = PreferencesView()
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false)
            preferencesWindow?.center()
            preferencesWindow?.setFrameAutosaveName("Preferences")
            preferencesWindow?.contentView = NSHostingView(rootView: preferencesView)
            preferencesWindow?.isReleasedWhenClosed = false
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func startAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            self.animationFrame = (self.animationFrame + 1) % 8
            let rotation = Double(self.animationFrame) * 45.0

            if let button = self.statusItem?.button {
                let image = NSImage(
                    systemSymbolName: "arrow.2.circlepath",
                    accessibilityDescription: "Brew Menu Bar (Updating)")!
                let rotatedImage = image.rotated(by: CGFloat(rotation))
                button.image = rotatedImage
            }
        }
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "mug", accessibilityDescription: "Brew Menu Bar")?.tint(
                    color: .white)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension NSImage {
    func rotated(by degrees: CGFloat) -> NSImage {
        let rotated = NSImage(
            size: size, flipped: false,
            drawingHandler: { (dstRect: NSRect) -> Bool in
                let transform = NSAffineTransform()
                transform.translateX(by: dstRect.width / 2, yBy: dstRect.height / 2)
                transform.rotate(byDegrees: degrees)
                transform.translateX(by: -dstRect.width / 2, yBy: -dstRect.height / 2)
                transform.concat()
                self.draw(in: dstRect)
                return true
            })
        return rotated.tint(color: .white)
    }

    func tint(color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}
