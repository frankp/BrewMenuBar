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

struct BrewCommandResult {
    let status: Int32
    let lines: [String]

    /// The most useful line to show when the command failed: brew's own `Error:` line if present.
    var failureReason: String {
        lines.last { $0.hasPrefix("Error:") }
            ?? lines.last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            ?? "brew exited with status \(status)"
    }
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
        task.standardError = Pipe()

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
        Task {
            let updateTask = Process()
            updateTask.executableURL = URL(fileURLWithPath: self.brewPath)
            updateTask.arguments = ["update"]
            try? updateTask.run()
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: self.brewPath)
        task.arguments = ["outdated", "--json"]

        let pipe = Pipe()
        task.standardOutput = pipe

        try task.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return try BrewService.parse(data: data)
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
        let result = try await run(["upgrade", packageName], onLine: onOutput)
        if result.status != 0 {
            throw NSError(
                domain: "BrewService", code: Int(result.status),
                userInfo: [NSLocalizedDescriptionKey: result.failureReason])
        }
    }

    func uninstallPackage(packageName: String) async throws {
        let result = try await run(["uninstall", packageName])
        if result.status != 0 {
            throw NSError(
                domain: "BrewService", code: Int(result.status),
                userInfo: [NSLocalizedDescriptionKey: "Brew uninstall failed for \(packageName)"])
        }
    }

    /// Runs brew with stdout and stderr merged, reporting each line as it arrives.
    /// Draining the pipe while the process runs also stops brew blocking once the pipe buffer fills.
    private func run(
        _ arguments: [String], onLine: ((String) -> Void)? = nil
    ) async throws -> BrewCommandResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: self.brewPath)
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var splitter = LineSplitter()
                var lines: [String] = []
                let emit = { (line: String) in
                    lines.append(line)
                    onLine?(line)
                }

                let handle = pipe.fileHandleForReading
                while case let data = handle.availableData, !data.isEmpty {
                    splitter.append(data).forEach(emit)
                }
                splitter.flush().forEach(emit)

                task.waitUntilExit()
                continuation.resume(
                    returning: BrewCommandResult(status: task.terminationStatus, lines: lines))
            }
        }
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
        let task = Process()
        task.executableURL = URL(fileURLWithPath: self.brewPath)
        task.arguments = ["services", "list", "--json"]

        let pipe = Pipe()
        task.standardOutput = pipe

        try task.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return try BrewService.parseServices(data: data)
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
        let task = Process()
        task.executableURL = URL(fileURLWithPath: self.brewPath)
        task.arguments = ["services", command, serviceName]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            throw NSError(
                domain: "BrewService", code: Int(task.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Brew services \(command) failed for \(serviceName)"])
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
