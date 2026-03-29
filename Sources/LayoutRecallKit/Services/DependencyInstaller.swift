import Foundation

public struct DisplayplacerInstaller: DependencyInstalling {
    public var installTimeout: TimeInterval
    public var homebrewBootstrapTimeout: TimeInterval

    public init(
        installTimeout: TimeInterval = 1_200,
        homebrewBootstrapTimeout: TimeInterval = 1_800
    ) {
        self.installTimeout = installTimeout
        self.homebrewBootstrapTimeout = homebrewBootstrapTimeout
    }

    public func installDisplayplacerIfNeeded() async -> DependencyInstallResult {
        await Task.detached(priority: .utility) {
            if let location = resolvedExecutable(named: "displayplacer") {
                return DependencyInstallResult(
                    outcome: .alreadyInstalled,
                    dependency: "displayplacer",
                    location: location,
                    details: "displayplacer is already installed at \(location)."
                )
            }

            var brewPath = resolvedBrewPath()
            if brewPath == nil {
                let bootstrap = runShell(
                    command: #"NONINTERACTIVE=1 CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#,
                    timeout: homebrewBootstrapTimeout
                )

                guard bootstrap.exitCode == 0 else {
                    return DependencyInstallResult(
                        outcome: .failed,
                        dependency: "displayplacer",
                        details: [
                            "Homebrew could not be installed automatically.",
                            bootstrap.summary
                        ]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    )
                }

                brewPath = resolvedBrewPath()
            }

            guard let brewPath else {
                return DependencyInstallResult(
                    outcome: .failed,
                    dependency: "displayplacer",
                    details: "Homebrew installation finished but brew could not be found on disk."
                )
            }

            let install = runShell(
                command: #"HOMEBREW_NO_AUTO_UPDATE=1 "\#(brewPath)" install displayplacer"#,
                timeout: installTimeout
            )

            guard install.exitCode == 0 else {
                return DependencyInstallResult(
                    outcome: .failed,
                    dependency: "displayplacer",
                    details: [
                        "displayplacer could not be installed automatically.",
                        install.summary
                    ]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                )
            }

            guard let displayplacerPath = resolvedExecutable(named: "displayplacer") else {
                return DependencyInstallResult(
                    outcome: .failed,
                    dependency: "displayplacer",
                    details: "displayplacer was installed but could not be resolved on PATH."
                )
            }

            return DependencyInstallResult(
                outcome: .installed,
                dependency: "displayplacer",
                location: displayplacerPath,
                details: "displayplacer was installed automatically at \(displayplacerPath)."
            )
        }.value
    }

    private func resolvedBrewPath() -> String? {
        resolvedExecutable(named: "brew")
            ?? ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first(where: {
                FileManager.default.isExecutableFile(atPath: $0)
            })
    }

    private func resolvedExecutable(named name: String) -> String? {
        let result = runShell(command: "command -v \(name)", timeout: 3)
        guard result.exitCode == 0 else {
            return nil
        }

        return result.stdout
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)
    }

    private func runShell(command: String, timeout: TimeInterval) -> ShellRunResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let startDate = Date()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return ShellRunResult(
                exitCode: -1,
                stdout: "",
                stderr: "",
                duration: Date().timeIntervalSince(startDate),
                summary: error.localizedDescription
            )
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()

            return ShellRunResult(
                exitCode: process.terminationStatus,
                stdout: dataString(from: stdoutPipe),
                stderr: dataString(from: stderrPipe),
                duration: Date().timeIntervalSince(startDate),
                summary: "Command timed out after \(Int(timeout)) seconds."
            )
        }

        let stdout = dataString(from: stdoutPipe)
        let stderr = dataString(from: stderrPipe)

        return ShellRunResult(
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            duration: Date().timeIntervalSince(startDate),
            summary: [stdout, stderr]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        )
    }

    private func dataString(from pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ShellRunResult {
    var exitCode: Int32
    var stdout: String
    var stderr: String
    var duration: TimeInterval
    var summary: String
}
