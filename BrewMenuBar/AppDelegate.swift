import AppKit
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem?
    let brewService = BrewService()
    var timer: Timer?
    var preferencesWindow: NSWindow?
    var animationTimer: Timer?
    var animationFrame = 0
    var isBusy = false
    var hasOutdatedPackages = false
    var outdatedPackages: [BrewPackage] = []
    var lastUpgradeFailures: [(name: String, reason: String)] = []
    private var progressView: UpgradeProgressView?

    private lazy var mugImage: NSImage? = {
        makeSystemSymbolImage(named: "mug", description: "Brew Menu Bar")
    }()
    private lazy var mugFilledImage: NSImage? = {
        makeSystemSymbolImage(
            named: "mug.fill", description: "Brew Menu Bar (Updates available)")
    }()
    private lazy var updatingImage: NSImage? = {
        makeSystemSymbolImage(
            named: "arrow.2.circlepath", description: "Brew Menu Bar (Updating)")
    }()

    private lazy var flaskUpImage: NSImage? = {
        loadCustomIcon(
            named: "menubar-concept-1-flask-up", description: "Brew Menu Bar (Flask + Up Arrow)")
    }()
    private lazy var flaskUpUpdateImage: NSImage? = {
        flaskUpImage?.withUpdateBadge()
    }()

    private lazy var bottleRefreshImage: NSImage? = {
        loadCustomIcon(
            named: "menubar-concept-2-bottle-refresh",
            description: "Brew Menu Bar (Bottle + Refresh)")
    }()
    private lazy var bottleRefreshUpdateImage: NSImage? = {
        bottleRefreshImage?.withUpdateBadge()
    }()

    private lazy var terminalUpImage: NSImage? = {
        loadCustomIcon(
            named: "menubar-concept-3-terminal-up", description: "Brew Menu Bar (Terminal + Up)")
    }()
    private lazy var terminalUpUpdateImage: NSImage? = {
        terminalUpImage?.withUpdateBadge()
    }()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission denied: \(error.localizedDescription)")
            } else {
                print("Notification permission denied (unknown reason).")
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.imagePosition = .imageLeft
        statusItem?.button?.font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)

        applyStatusIcon()

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

        if !isBusy {
            applyStatusIcon()
        }
    }

    @objc func updateMenu() {
        if isBusy { return }
        isBusy = true
        startAnimation()
        let menu = NSMenu()
        menu.addItem(withTitle: "Checking for updates...", action: nil, keyEquivalent: "")
        statusItem?.menu = menu

        Task {
            do {
                // Run sequentially to avoid brew lock contention
                let outdatedPackages = try await brewService.checkForUpdates()
                let services = try await brewService.fetchServices()

                await MainActor.run {
                    self.stopAnimation()
                    self.isBusy = false
                    let newMenu = NSMenu()

                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .none
                    dateFormatter.timeStyle = .short
                    let lastCheckedTime = dateFormatter.string(from: Date())

                    let lastCheckedItem = newMenu.addItem(
                        withTitle: "Last Checked: \(lastCheckedTime)", action: nil,
                        keyEquivalent: "")
                    lastCheckedItem.isEnabled = false

                    if !self.lastUpgradeFailures.isEmpty {
                        let failures = self.lastUpgradeFailures
                        let failedItem = newMenu.addItem(
                            withTitle: "⚠️ \(failures.count) update\(failures.count == 1 ? "" : "s") failed",
                            action: nil, keyEquivalent: "")
                        let failedMenu = NSMenu()
                        for failure in failures {
                            let item = failedMenu.addItem(
                                withTitle: "\(failure.name): \(failure.reason)", action: nil,
                                keyEquivalent: "")
                            item.isEnabled = false
                        }
                        failedItem.submenu = failedMenu
                    }

                    newMenu.addItem(NSMenuItem.separator())

                    if outdatedPackages.isEmpty {
                        newMenu.addItem(
                            withTitle: "No updates available.", action: nil, keyEquivalent: "")
                    } else {
                        NotificationManager.shared.maybeScheduleNotification(
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

                    // Services Section
                    newMenu.addItem(NSMenuItem.separator())
                    let servicesItem = newMenu.addItem(withTitle: "Services", action: nil, keyEquivalent: "")
                    let servicesMenu = NSMenu()
                    servicesItem.submenu = servicesMenu

                    if services.isEmpty {
                        let noServicesItem = servicesMenu.addItem(
                            withTitle: "No services found", action: nil, keyEquivalent: "")
                        noServicesItem.isEnabled = false
                    } else {
                        for service in services {
                            let statusColor: NSColor = service.isRunning
                                ? .green : (service.isError ? .red : .gray)
                            
                            let serviceItem = servicesMenu.addItem(
                                withTitle: service.name, action: nil, keyEquivalent: "")
                            serviceItem.image = self.makeStatusDot(color: statusColor)

                            let serviceMenu = NSMenu()
                            serviceMenu.autoenablesItems = false

                            // Start
                            let startItem = serviceMenu.addItem(
                                withTitle: "Start", action: #selector(self.startService),
                                keyEquivalent: "")
                            startItem.target = self
                            startItem.representedObject = service.name
                            if service.isRunning { startItem.isEnabled = false }

                            // Stop
                            let stopItem = serviceMenu.addItem(
                                withTitle: "Stop", action: #selector(self.stopService),
                                keyEquivalent: "")
                            stopItem.target = self
                            stopItem.representedObject = service.name
                            if !service.isRunning { stopItem.isEnabled = false }

                            // Restart
                            let restartItem = serviceMenu.addItem(
                                withTitle: "Restart", action: #selector(self.restartService),
                                keyEquivalent: "")
                            restartItem.target = self
                            restartItem.representedObject = service.name

                            serviceItem.submenu = serviceMenu
                        }
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

                    newMenu.addItem(self.versionMenuItem())
                    newMenu.addItem(
                        withTitle: "Quit", action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

                    self.outdatedPackages = outdatedPackages
                    self.hasOutdatedPackages = !outdatedPackages.isEmpty
                    self.applyStatusIcon()
                    self.statusItem?.menu = newMenu
                }
            } catch {
                await MainActor.run {
                    self.stopAnimation()
                    self.isBusy = false
                    print("Error checking for updates: \(error)")
                    // Optionally show an error state in the menu
                    let errorMenu = NSMenu()
                    errorMenu.addItem(
                        withTitle: "Error checking for updates", action: nil, keyEquivalent: "")
                    errorMenu.addItem(
                        withTitle: "Try again", action: #selector(self.updateMenu),
                        keyEquivalent: "r")
                    errorMenu.addItem(NSMenuItem.separator())
                    errorMenu.addItem(self.versionMenuItem())
                    errorMenu.addItem(
                        withTitle: "Quit", action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
                    self.statusItem?.menu = errorMenu
                }
            }
        }
    }

    @objc func startService(_ sender: NSMenuItem) {
        guard let serviceName = sender.representedObject as? String else { return }
        performServiceAction(action: "Starting", serviceName: serviceName) {
            try await self.brewService.startService(name: serviceName)
        }
    }

    @objc func stopService(_ sender: NSMenuItem) {
        guard let serviceName = sender.representedObject as? String else { return }
        performServiceAction(action: "Stopping", serviceName: serviceName) {
            try await self.brewService.stopService(name: serviceName)
        }
    }

    @objc func restartService(_ sender: NSMenuItem) {
        guard let serviceName = sender.representedObject as? String else { return }
        performServiceAction(action: "Restarting", serviceName: serviceName) {
            try await self.brewService.restartService(name: serviceName)
        }
    }

    private func performServiceAction(
        action: String, serviceName: String, operation: @escaping () async throws -> Void
    ) {
        if isBusy { return }
        isBusy = true
        startAnimation()
        let menu = NSMenu()
        menu.addItem(withTitle: "\(action) \(serviceName)...", action: nil, keyEquivalent: "")
        statusItem?.menu = menu

        Task {
            do {
                try await operation()
                await MainActor.run {
                    self.stopAnimation()
                    self.isBusy = false
                    self.updateMenu()
                }
            } catch {
                await MainActor.run {
                    self.stopAnimation()
                    self.isBusy = false
                    print("Error \(action) \(serviceName): \(error)")
                    self.updateMenu() // Reload menu even on error to restore state
                }
            }
        }
    }

    @objc func uninstallPackage(_ sender: NSMenuItem) {
        guard let packageName = sender.representedObject as? String else { return }

        let alert = NSAlert()
        alert.messageText = "Uninstall \(packageName)?"
        alert.informativeText = "This will remove \(packageName) from your system. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        if isBusy { return }
        isBusy = true

        startAnimation()
        let menu = NSMenu()
        menu.addItem(withTitle: "Uninstalling \(packageName)...", action: nil, keyEquivalent: "")
        statusItem?.menu = menu

        Task {
            do {
                try await brewService.uninstallPackage(packageName: packageName)
                await MainActor.run {
                    self.stopAnimation()
                    self.isBusy = false
                    self.updateMenu()
                }
            } catch {
                await MainActor.run {
                    self.stopAnimation()
                    self.isBusy = false
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
        // Pinned formulae are skipped by a plain `brew upgrade`, but fail when named explicitly.
        let names = outdatedPackages.filter { !$0.pinned }.map(\.name)
        guard !names.isEmpty else { return }
        runUpgrades(names)
    }

    @objc func updatePackage(_ sender: NSMenuItem) {
        guard let packageName = sender.representedObject as? String else { return }
        runUpgrades([packageName])
    }

    /// Upgrades packages one at a time so progress ("2/5") and failures can be reported per package.
    private func runUpgrades(_ names: [String]) {
        if isBusy { return }
        isBusy = true

        startAnimation()
        showProgressMenu()

        Task {
            var failures: [(name: String, reason: String)] = []

            for (index, name) in names.enumerated() {
                await MainActor.run {
                    self.setUpgradeProgress(
                        name: name, index: index, total: names.count, step: "Starting…", fraction: 0)
                }
                do {
                    try await brewService.updatePackage(packageName: name) { line in
                        guard let step = BrewService.progressStep(from: line) else { return }
                        Task { @MainActor in
                            self.setUpgradeProgress(
                                name: name, index: index, total: names.count, step: step,
                                fraction: BrewService.progressFraction(forStep: step))
                        }
                    }
                } catch {
                    print("Error updating \(name): \(error)")
                    failures.append((name: name, reason: error.localizedDescription))
                }
            }

            let finalFailures = failures
            await MainActor.run {
                self.lastUpgradeFailures = finalFailures
                NotificationManager.shared.notifyUpgradeFinished(
                    succeeded: names.count - finalFailures.count, failed: finalFailures.map(\.name))
                self.stopAnimation()
                self.isBusy = false
                self.updateMenu()
            }
        }
    }

    private func showProgressMenu() {
        let menu = NSMenu()
        let view = UpgradeProgressView()
        let item = NSMenuItem()
        item.view = view
        menu.addItem(item)
        progressView = view
        statusItem?.menu = menu
    }

    /// Updates the open menu, the counter beside the icon, and the icon's tooltip.
    /// `fraction` is progress through the current package; nil keeps the bar where it is.
    private func setUpgradeProgress(
        name: String, index: Int, total: Int, step: String, fraction: Double?
    ) {
        let position = total > 1 ? " (\(index + 1) of \(total))" : ""
        let overall = (Double(index) + (fraction ?? 0)) / Double(total)
        progressView?.update(title: "Updating \(name)\(position)", step: step, fraction: overall)

        // Packages finished so far (updated or failed), not the one in progress.
        statusItem?.button?.title = "\(index)/\(total)"
        statusItem?.button?.toolTip = "Updating \(name)\(position): \(step)"
    }

    /// Disabled menu item showing the app version from the bundle's Info.plist.
    func versionMenuItem() -> NSMenuItem {
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let item = NSMenuItem(title: "BrewMenuBar v\(version)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc func openPreferences() {
        if preferencesWindow == nil {
            let preferencesView = PreferencesView()
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
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
        animationTimer = Timer(timeInterval: 0.2, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            self.animationFrame = (self.animationFrame + 1) % 8
            let rotation = Double(self.animationFrame) * 45.0

            if let button = self.statusItem?.button,
               let baseImage = self.updatingImage {
                let rotatedImage = baseImage.rotated(by: CGFloat(rotation))
                button.image = rotatedImage
            }
        }
        // Common modes keep the icon spinning while the menu is open.
        if let animationTimer { RunLoop.main.add(animationTimer, forMode: .common) }
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        statusItem?.button?.title = ""
        statusItem?.button?.toolTip = nil
        applyStatusIcon()
    }

    private func applyStatusIcon() {
        guard let button = statusItem?.button else { return }
        let fallbackImage = hasOutdatedPackages ? mugFilledImage : mugImage
        button.image = currentStatusIcon() ?? fallbackImage
    }

    private func makeStatusDot(color: NSColor) -> NSImage {
        return NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
    }

    private func currentStatusIcon() -> NSImage? {
        switch selectedIconStyle() {
        case .systemMug:
            return hasOutdatedPackages ? mugFilledImage : mugImage
        case .flaskUp:
            return hasOutdatedPackages ? (flaskUpUpdateImage ?? flaskUpImage) : flaskUpImage
        case .bottleRefresh:
            return hasOutdatedPackages
                ? (bottleRefreshUpdateImage ?? bottleRefreshImage) : bottleRefreshImage
        case .terminalUp:
            return hasOutdatedPackages ? (terminalUpUpdateImage ?? terminalUpImage) : terminalUpImage
        }
    }

    private func selectedIconStyle() -> StatusBarIconStyle {
        let savedRawValue =
            UserDefaults.standard.string(forKey: StatusBarIconStyle.userDefaultsKey)
            ?? StatusBarIconStyle.systemMug.rawValue
        return StatusBarIconStyle(rawValue: savedRawValue) ?? .systemMug
    }

    private func makeSystemSymbolImage(named symbolName: String, description: String) -> NSImage? {
        guard let image = NSImage(
            systemSymbolName: symbolName, accessibilityDescription: description)
        else { return nil }

        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    private func loadCustomIcon(named fileName: String, description: String) -> NSImage? {
        let iconURL =
            Bundle.main.url(
                forResource: fileName,
                withExtension: "svg",
                subdirectory: "icon-concepts")
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("icon-concepts/\(fileName).svg")

        guard let image = NSImage(contentsOf: iconURL) else {
            print("Failed to load icon: \(fileName).svg")
            return nil
        }

        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        image.accessibilityDescription = description
        return image
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even if the app is in the foreground
        completionHandler([.banner, .sound, .badge])
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
        rotated.isTemplate = isTemplate
        return rotated
    }

    func withUpdateBadge() -> NSImage {
        let badgeImage = NSImage(
            size: size, flipped: false,
            drawingHandler: { dstRect in
                self.draw(in: dstRect)

                let badgeSize = min(dstRect.width, dstRect.height) * 0.28
                let badgeRect = NSRect(
                    x: dstRect.maxX - badgeSize - 0.8,
                    y: dstRect.maxY - badgeSize - 0.8,
                    width: badgeSize,
                    height: badgeSize)

                NSColor.black.setFill()
                NSBezierPath(ovalIn: badgeRect).fill()
                return true
            })
        badgeImage.isTemplate = true
        return badgeImage
    }
}
