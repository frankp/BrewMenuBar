import Foundation

struct BrewPackage: Identifiable {
    let id = UUID()
    let name: String
    let installedVersions: [String]
    let currentVersion: String
    let availableVersion: String
    let homepage: String?
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
                homepage: formula.homepage
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

    func updateAll() async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: self.brewPath)
        task.arguments = ["upgrade"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            // We could capture stderr here for better error messages
            throw NSError(
                domain: "BrewService", code: Int(task.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Brew upgrade failed"])
        }
    }

    func updatePackage(packageName: String) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: self.brewPath)
        task.arguments = ["upgrade", packageName]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            throw NSError(
                domain: "BrewService", code: Int(task.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Brew upgrade failed for \(packageName)"])
        }
    }

    func uninstallPackage(packageName: String) async throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: self.brewPath)
        task.arguments = ["uninstall", packageName]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            throw NSError(
                domain: "BrewService", code: Int(task.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Brew uninstall failed for \(packageName)"])
        }
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
}

struct OutdatedCask: Decodable {
    let name: String
    let installed_versions: [String]
    let current_version: String
    let homepage: String?
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
