import Foundation

public struct DisplayplacerRestoreExecutor: RestoreExecuting {
    public var timeout: TimeInterval

    public init(timeout: TimeInterval = 10) {
        self.timeout = timeout
    }

    public func dependencyStatus() async -> RestoreDependencyStatus {
        await Task.detached(priority: .utility) {
            let result = runBlocking(command: "command -v displayplacer", timeout: 2)

            guard result.outcome == .success else {
                return RestoreDependencyStatus(
                    isAvailable: false,
                    details: L10n.t("restoreExecutor.dependencyMissing")
                )
            }

            let location = result.stdout
                .split(whereSeparator: \.isNewline)
                .first
                .map(String.init)

            return RestoreDependencyStatus(
                isAvailable: location != nil,
                location: location,
                details: location.map { L10n.t("restoreExecutor.availableAt", $0) } ?? L10n.t("restoreExecutor.dependencyMissing")
            )
        }.value
    }

    public func execute(command: String) async -> RestoreExecutionResult {
        let dependency = await dependencyStatus()

        guard dependency.isAvailable else {
            return RestoreExecutionResult(
                outcome: .dependencyMissing,
                command: command,
                details: dependency.details
            )
        }

        return await Task.detached(priority: .userInitiated) {
            runBlocking(command: command, timeout: timeout)
        }.value
    }

    private func runBlocking(command: String, timeout: TimeInterval) -> RestoreExecutionResult {
        let startDate = Date()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let process = Process()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return RestoreExecutionResult(
                outcome: .failure,
                command: command,
                stdout: "",
                stderr: "",
                duration: Date().timeIntervalSince(startDate),
                details: error.localizedDescription
            )
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()

            return RestoreExecutionResult(
                outcome: .timedOut,
                command: command,
                exitCode: process.terminationStatus,
                stdout: dataString(from: stdoutPipe),
                stderr: dataString(from: stderrPipe),
                duration: Date().timeIntervalSince(startDate),
                details: L10n.t("restoreExecutor.timedOut", Int(timeout))
            )
        }

        let stdout = dataString(from: stdoutPipe)
        let stderr = dataString(from: stderrPipe)
        let duration = Date().timeIntervalSince(startDate)

        if process.terminationStatus == 0 {
            return RestoreExecutionResult(
                outcome: .success,
                command: command,
                exitCode: process.terminationStatus,
                stdout: stdout,
                stderr: stderr,
                duration: duration,
                details: L10n.t("restoreExecutor.success")
            )
        }

        return RestoreExecutionResult(
            outcome: .failure,
            command: command,
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            duration: duration,
            details: failureDetails(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
        )
    }

    private func dataString(from pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func failureDetails(exitCode: Int32, stdout: String, stderr: String) -> String {
        let message = [stderr, stdout]
            .first { !$0.isEmpty }
            .map { $0.replacingOccurrences(of: "\n", with: " ") }

        if let message {
            return L10n.t("restoreExecutor.failureWithMessage", exitCode, message)
        }

        return L10n.t("restoreExecutor.failure", exitCode)
    }
}
