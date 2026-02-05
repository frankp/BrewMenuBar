import Foundation

struct BrewPackage: Identifiable {
    let id = UUID()
    let name: String
    let installedVersions: [String]
    let currentVersion: String
    let availableVersion: String
    let homepage: String?
}

class BrewService {
    private var brewPath: String = {
        let paths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "/usr/local/bin/brew"
    }()

    func checkForUpdates() async throws -> [BrewPackage] {
        // First, run 'brew update' to fetch the latest package definitions
        let updateTask = Process()
        updateTask.executableURL = URL(fileURLWithPath: self.brewPath)
        updateTask.arguments = ["update"]

        // Run update, but don't stop if it fails (e.g. no internet); just check against local cache.
        try? updateTask.run()
        updateTask.waitUntilExit()

        let task = Process()
        task.executableURL = URL(fileURLWithPath: self.brewPath)
        task.arguments = ["outdated", "--json"]

        let pipe = Pipe()
        task.standardOutput = pipe

        try task.run()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
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
