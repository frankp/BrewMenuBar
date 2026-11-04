import Foundation

struct BrewPackage: Identifiable {
    let id = UUID()
    let name: String
    let installedVersions: [String]
    let currentVersion: String
    let availableVersion: String
    let homepage: String?
    var pinned: Bool = false
}

final class BrewService {
    private lazy var brewPath: String = {
        let resolved = resolveBrewPath()
        return resolved
    }()

    private func resolveBrewPath() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-lc", "command -v brew"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = FileHandle.nullDevice
        task.standardInput = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Failed to resolve brew path: \(error.localizedDescription)")
        }

        if task.terminationStatus == 0 {
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty,
               FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        let paths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "/usr/local/bin/brew"
    }

    func checkForUpdates() async throws -> [BrewPackage] {
        // Refresh brew's metadata first, and wait for it: running it alongside `outdated`/`upgrade`
        // made them contend for brew's lock. Failure here is fine - we just report slightly stale data.
        let update = try? await run(["update"], limits: .update)
        if let update, !update.succeeded {
            print("brew update failed: \(update.failureReason)")
        }

        let result = try await run(["outdated", "--json"], limits: .query, captureStdout: true)
        guard result.succeeded else { throw BrewError(message: result.failureReason) }
        return try BrewService.parse(data: result.stdout)
    }

    static func parse(data: Data) throws -> [BrewPackage] {
        // If data is empty or invalid JSON, this will throw, which is good.
        let outdatedInfo = try JSONDecoder().decode(BrewOutdated.self, from: data)

        let formulaPackages = outdatedInfo.formulae.map { formula in
            BrewPackage(
                name: formula.name,
                installedVersions: formula.installed_versions,
                currentVersion: formula.installed_versions.first ?? "N/A",
                availableVersion: formula.current_version,
                homepage: formula.homepage,
                pinned: formula.pinned ?? false
            )
        }

        let caskPackages = outdatedInfo.casks.map { cask in
            BrewPackage(
                name: cask.name,
                installedVersions: cask.installed_versions,
                currentVersion: cask.installed_versions.first ?? "N/A",
                availableVersion: cask.current_version,
                homepage: cask.homepage
            )
        }

        return formulaPackages + caskPackages
    }

    func updatePackage(
        packageName: String, onOutput: ((String) -> Void)? = nil
    ) async throws {
        let result = try await run(["upgrade", packageName], limits: .upgrade, onLine: onOutput)
        guard result.succeeded else { throw BrewError(message: result.failureReason) }
    }

    func uninstallPackage(packageName: String) async throws {
        let result = try await run(["uninstall", packageName], limits: .action)
        guard result.succeeded else {
            throw BrewError(message: "Uninstall of \(packageName) failed: \(result.failureReason)")
        }
    }

    /// Stops whatever brew command is running; its caller gets a "Cancelled" failure.
    func cancelCurrentCommand() {
        activeLock.lock()
        let runner = activeRunner
        activeLock.unlock()
        runner?.cancel()
    }

    // Plain sync helpers: NSLock can't be taken directly inside an async function.
    private func setActiveRunner(_ runner: CommandRunner) {
        activeLock.lock()
        activeRunner = runner
        activeLock.unlock()
    }

    private func clearActiveRunner(_ runner: CommandRunner) {
        activeLock.lock()
        if activeRunner === runner { activeRunner = nil }
        activeLock.unlock()
    }

    private let activeLock = NSLock()
    private var activeRunner: CommandRunner?

    /// Environment for brew: the app already runs `brew update` itself, so stop `upgrade` from
    /// auto-updating (slow, and a second source of lock contention) and drop the env-hint noise.
    private var brewEnvironment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        return env
    }

    private func run(
        _ arguments: [String], limits: CommandLimits, captureStdout: Bool = false,
        onLine: ((String) -> Void)? = nil
    ) async throws -> BrewCommandResult {
        let runner = CommandRunner(
            executable: brewPath, arguments: arguments, environment: brewEnvironment,
            limits: limits, captureStdout: captureStdout, onLine: onLine)
        setActiveRunner(runner)
        defer { clearActiveRunner(runner) }
        return try await runner.run()
    }

    /// Roughly how far through one package's upgrade a step is (0...1), or nil if the step says nothing.
    /// brew doesn't report real percentages, so this maps its phases onto the bar.
    static func progressFraction(forStep step: String) -> Double? {
        let verb = step.split(separator: " ").first.map(String.init) ?? step
        switch verb {
        case "Fetching", "Fetched", "Downloading": return 0.25
        case "Upgrading": return 0.5
        case "Pouring", "Installing", "Moving", "Linking": return 0.7
        case "Installed", "Caveats", "Summary": return 0.9
        case "Cleaning", "Removing", "Purging": return 0.95
        default: return nil
        }
    }

    /// Turns a line of `brew upgrade` output into a short status, or nil if it isn't worth showing.
    static func progressStep(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("Error:") { return trimmed }
        if trimmed.hasPrefix("🍺") { return "Installed" }
        // Newer brew reports each finished parallel download as "✔︎ Bottle node (22.2.0)".
        if trimmed.unicodeScalars.first == "\u{2714}" {
            return "Fetched " + trimmed.drop { !$0.isLetter }
        }
        guard trimmed.hasPrefix("==> ") else { return nil }

        let message = String(trimmed.dropFirst(4))
        let words = message.split(separator: " ")
        // URLs and bottle filenames are noise in a menu - keep just the verb ("Downloading", "Pouring").
        if words.dropFirst().contains(where: { $0.contains("://") || $0.hasSuffix(".tar.gz") }),
           let verb = words.first {
            return String(verb)
        }
        return message.count > 60 ? String(message.prefix(59)) + "…" : message
    }

    func fetchServices() async throws -> [BrewServiceInfo] {
        let result = try await run(["services", "list", "--json"], limits: .query, captureStdout: true)
        guard result.succeeded else { throw BrewError(message: result.failureReason) }
        return try BrewService.parseServices(data: result.stdout)
    }

    static func parseServices(data: Data) throws -> [BrewServiceInfo] {
        return try JSONDecoder().decode([BrewServiceInfo].self, from: data)
    }

    func startService(name: String) async throws {
        try await runServiceCommand(command: "start", serviceName: name)
    }

    func stopService(name: String) async throws {
        try await runServiceCommand(command: "stop", serviceName: name)
    }

    func restartService(name: String) async throws {
        try await runServiceCommand(command: "restart", serviceName: name)
    }

    private func runServiceCommand(command: String, serviceName: String) async throws {
        let result = try await run(["services", command, serviceName], limits: .action)
        guard result.succeeded else {
            throw BrewError(
                message: "brew services \(command) \(serviceName) failed: \(result.failureReason)")
        }
    }
}

struct BrewOutdated: Decodable {
    let formulae: [OutdatedFormula]
    let casks: [OutdatedCask]
}

struct OutdatedFormula: Decodable {
    let name: String
    let installed_versions: [String]
    let current_version: String
    let homepage: String?
    let pinned: Bool?
}

struct OutdatedCask: Decodable {
    let name: String
    let installed_versions: [String]
    let current_version: String
    let homepage: String?
}

/// Splits a byte stream into lines, holding back a trailing partial line until more data arrives.
struct LineSplitter {
    private var buffer = Data()

    mutating func append(_ data: Data) -> [String] {
        buffer.append(data)
        var lines: [String] = []
        while let index = buffer.firstIndex(where: { $0 == UInt8(ascii: "\n") || $0 == UInt8(ascii: "\r") }) {
            let line = buffer[buffer.startIndex..<index]
            buffer = Data(buffer[buffer.index(after: index)...])
            if !line.isEmpty { lines.append(String(decoding: line, as: UTF8.self)) }
        }
        return lines
    }

    mutating func flush() -> [String] {
        defer { buffer = Data() }
        return buffer.isEmpty ? [] : [String(decoding: buffer, as: UTF8.self)]
    }
}

struct BrewServiceInfo: Decodable, Identifiable {
    let name: String
    let status: String
    let user: String?
    let file: String?
    let exit_code: Int?

    var id: String { name }

    var isRunning: Bool {
        return status == "started"
    }
    
    var isError: Bool {
        return status == "error"
    }
}
