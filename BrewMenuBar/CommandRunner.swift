import Foundation

/// How long a command may run before it is stopped.
struct CommandLimits {
    /// Wall-clock limit for the whole command.
    let total: TimeInterval
    /// Stop if the command prints nothing for this long (nil = no idle limit).
    let idle: TimeInterval?

    /// Quick read-only queries such as `brew outdated --json`.
    static let query = CommandLimits(total: 120, idle: nil)
    /// `brew update` - best effort, never worth waiting on for long.
    static let update = CommandLimits(total: 180, idle: nil)
    /// One package upgrade. Large bottles download silently when there's no TTY, so the idle limit is generous.
    static let upgrade = CommandLimits(total: 45 * 60, idle: 10 * 60)
    /// Uninstalls and `brew services` start/stop/restart.
    static let action = CommandLimits(total: 5 * 60, idle: nil)
}

struct BrewCommandResult {
    let status: Int32
    /// stdout and stderr lines in arrival order (stdout is excluded when captured as data).
    let lines: [String]
    /// Raw stdout, only filled when the command was run with `captureStdout`.
    let stdout: Data
    /// Why the app stopped the command (timeout, no output, cancelled), or nil if it exited by itself.
    var stopReason: String? = nil

    var succeeded: Bool { stopReason == nil && status == 0 }

    /// The most useful line to show when the command failed: why we stopped it, else brew's own `Error:` line.
    var failureReason: String {
        if let stopReason { return stopReason }
        return lines.last { $0.hasPrefix("Error:") }
            ?? lines.last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            ?? "brew exited with status \(status)"
    }
}

struct BrewError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Runs one process with no stdin, streams its output, and enforces `CommandLimits`.
///
/// Completion is driven by the process exiting, not by its pipes closing: a helper that brew leaves
/// running in the background can hold the pipes open indefinitely, which used to leave the app
/// waiting forever after brew itself had finished.
/// `@unchecked Sendable`: all mutable state is confined to `queue`.
final class CommandRunner: @unchecked Sendable {
    private let queue = DispatchQueue(label: "BrewMenuBar.CommandRunner")
    private let process = Process()
    private let outPipe = Pipe()
    private let errPipe = Pipe()
    private let limits: CommandLimits
    private let captureStdout: Bool
    private let onLine: ((String) -> Void)?

    // State below is only touched on `queue`.
    private var stdoutData = Data()
    private var outSplitter = LineSplitter()
    private var errSplitter = LineSplitter()
    private var lines: [String] = []
    private var startedAt = Date()
    private var lastOutputAt = Date()
    private var openPipes = 2
    private var exited = false
    private var finished = false
    private var stopReason: String?
    private var completion: ((Result<BrewCommandResult, Error>) -> Void)?
    /// Keeps the runner alive while the command is in flight; callbacks only hold it weakly.
    private var keepAlive: CommandRunner?

    /// Seconds to keep reading after exit before giving up on pipes a leftover child holds open.
    static let drainGrace: TimeInterval = 1
    static let watchdogInterval: TimeInterval = 1

    init(
        executable: String, arguments: [String], environment: [String: String]? = nil,
        limits: CommandLimits, captureStdout: Bool = false, onLine: ((String) -> Void)? = nil
    ) {
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment { process.environment = environment }
        // Nothing should ever wait for input we can't give it.
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outPipe
        process.standardError = errPipe
        self.limits = limits
        self.captureStdout = captureStdout
        self.onLine = onLine
    }

    func run() async throws -> BrewCommandResult {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.start { continuation.resume(with: $0) }
            }
        }
    }

    /// Stops the command; it then completes with `stopReason` set.
    func cancel(reason: String = "Cancelled") {
        queue.async { self.stop(reason: reason) }
    }

    // MARK: - Internals (on `queue`)

    private func start(completion: @escaping (Result<BrewCommandResult, Error>) -> Void) {
        self.completion = completion
        keepAlive = self

        for (pipe, isStdout) in [(outPipe, true), (errPipe, false)] {
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if data.isEmpty { handle.readabilityHandler = nil }
                self?.queue.async { self?.received(data, isStdout: isStdout) }
            }
        }
        process.terminationHandler = { [weak self] _ in
            self?.queue.async { self?.processExited() }
        }

        let command = ([process.executableURL?.lastPathComponent ?? ""] + (process.arguments ?? []))
            .joined(separator: " ")
        CommandLog.shared.write("$ \(command)")

        do {
            try process.run()
        } catch {
            finished = true
            clearHandlers()
            CommandLog.shared.write("! failed to launch: \(error.localizedDescription)")
            completion(.failure(error))
            keepAlive = nil
            return
        }
        startedAt = Date()
        lastOutputAt = startedAt
        scheduleWatchdog()
    }

    private func received(_ data: Data, isStdout: Bool) {
        guard !finished else { return }
        if data.isEmpty {
            openPipes -= 1
            if exited && openPipes == 0 { finish() }
            return
        }
        lastOutputAt = Date()
        if isStdout && captureStdout {
            stdoutData.append(data)
            return
        }
        let newLines = isStdout ? outSplitter.append(data) : errSplitter.append(data)
        newLines.forEach(emit)
    }

    private func emit(_ line: String) {
        lines.append(line)
        CommandLog.shared.write(line)
        onLine?(line)
    }

    private func processExited() {
        exited = true
        if openPipes == 0 {
            finish()
        } else {
            queue.asyncAfter(deadline: .now() + Self.drainGrace) { self.finish() }
        }
    }

    private func scheduleWatchdog() {
        queue.asyncAfter(deadline: .now() + Self.watchdogInterval) {
            guard !self.exited else { return }
            let now = Date()
            if now.timeIntervalSince(self.startedAt) > self.limits.total {
                self.stop(reason: "Timed out after \(Self.describe(self.limits.total))")
            } else if let idle = self.limits.idle, now.timeIntervalSince(self.lastOutputAt) > idle {
                let last = self.lines.last.map { " (last output: \($0))" } ?? ""
                self.stop(reason: "Stalled - no output for \(Self.describe(idle))\(last)")
            }
            self.scheduleWatchdog()
        }
    }

    private func stop(reason: String) {
        guard !exited, !finished else { return }
        if stopReason == nil {
            stopReason = reason
            CommandLog.shared.write("! stopping: \(reason)")
        }
        process.terminate()
        let pid = process.processIdentifier
        queue.asyncAfter(deadline: .now() + 5) {
            if !self.exited { kill(pid, SIGKILL) }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        clearHandlers()
        (outSplitter.flush() + errSplitter.flush()).forEach(emit)

        let result = BrewCommandResult(
            status: process.terminationStatus, lines: lines, stdout: stdoutData,
            stopReason: stopReason)
        CommandLog.shared.write(
            "= exit \(result.status)\(stopReason.map { " (\($0))" } ?? "") after \(Self.describe(Date().timeIntervalSince(startedAt)))"
        )
        completion?(.success(result))
        completion = nil
        keepAlive = nil
    }

    private func clearHandlers() {
        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
    }

    static func describe(_ interval: TimeInterval) -> String {
        if interval >= 120 { return "\(Int(interval / 60)) min" }
        if interval >= 10 { return "\(Int(interval))s" }
        return String(format: "%.1fs", interval)
    }
}

/// Append-only log of every brew command and its output, so a hang can be traced to a package.
/// Lives at ~/Library/Logs/BrewMenuBar/brew.log.
final class CommandLog {
    static let shared = CommandLog()
    static let maxSize = 2 * 1024 * 1024

    let url: URL
    private let queue = DispatchQueue(label: "BrewMenuBar.CommandLog")
    private var handle: FileHandle?
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/BrewMenuBar", isDirectory: true)
        url = dir.appendingPathComponent("brew.log")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Start over once the log gets large rather than growing forever.
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        if size > Self.maxSize { try? FileManager.default.removeItem(at: url) }
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try? FileHandle(forWritingTo: url)
        handle?.seekToEndOfFile()
    }

    func write(_ line: String) {
        let stamped = "\(formatter.string(from: Date()))  \(line)\n"
        queue.async { self.handle?.write(Data(stamped.utf8)) }
    }
}
