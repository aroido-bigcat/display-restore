import AppKit
import Foundation
import LayoutRecallKit

struct AppRelease: Equatable, Sendable, Identifiable {
    let tagName: String
    let version: String
    let assetName: String
    let downloadURL: URL
    let publishedAt: Date?
    let releaseNotes: String?

    var id: String {
        versionIdentifier
    }

    var versionIdentifier: String {
        if !version.isEmpty {
            return version
        }

        return tagName
    }

    var displayVersion: String {
        versionIdentifier
    }

    var promptSummary: String? {
        guard let releaseNotes else {
            return nil
        }

        let trimmed = releaseNotes
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return nil
        }

        let firstParagraph = trimmed
            .components(separatedBy: "\n\n")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let firstParagraph, !firstParagraph.isEmpty else {
            return nil
        }

        if firstParagraph.count <= 220 {
            return firstParagraph
        }

        let index = firstParagraph.index(firstParagraph.startIndex, offsetBy: 220)
        return String(firstParagraph[..<index]) + "…"
    }
}

enum AppUpdateState: Equatable {
    case idle
    case checking
    case noPublishedReleases
    case upToDate
    case available(AppRelease)
    case skipped(AppRelease)
    case downloading(AppRelease)
    case installing(AppRelease)
    case failed(String)

    var release: AppRelease? {
        switch self {
        case .available(let release),
             .skipped(let release),
             .downloading(let release),
             .installing(let release):
            return release
        case .idle, .checking, .noPublishedReleases, .upToDate, .failed:
            return nil
        }
    }

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .installing:
            return true
        case .idle, .noPublishedReleases, .upToDate, .available, .skipped, .failed:
            return false
        }
    }
}

enum AppUpdatePromptResponse {
    case install
    case skipThisVersion
    case later
}

protocol AppUpdateChecking: Sendable {
    func fetchLatestRelease() async throws -> AppRelease?
}

protocol AppUpdateInstalling: Sendable {
    func prepareUpdateInstallation(release: AppRelease, replacing bundleURL: URL) async throws
}

protocol AppUpdatePrompting {
    @MainActor
    func promptToInstall(release: AppRelease, currentVersion: String) async -> AppUpdatePromptResponse
}

enum AppUpdateError: LocalizedError, Equatable {
    case missingRepository
    case noPublishedReleases
    case invalidResponse
    case requestFailed(Int)
    case releaseAssetMissing
    case extractionFailed(String)
    case extractedAppMissing
    case installLocationUnavailable
    case installScriptFailed(String)
    case unsupportedBundleLocation

    var errorDescription: String? {
        switch self {
        case .missingRepository:
            return L10n.t("update.error.missingRepository")
        case .noPublishedReleases:
            return L10n.t("update.error.noPublishedReleases")
        case .invalidResponse:
            return L10n.t("update.error.invalidResponse")
        case .requestFailed(let statusCode):
            return L10n.t("update.error.requestFailed", statusCode)
        case .releaseAssetMissing:
            return L10n.t("update.error.releaseAssetMissing")
        case .extractionFailed(let details):
            return L10n.t("update.error.extractionFailed", details)
        case .extractedAppMissing:
            return L10n.t("update.error.extractedAppMissing")
        case .installLocationUnavailable:
            return L10n.t("update.error.installLocationUnavailable")
        case .installScriptFailed(let details):
            return L10n.t("update.error.installScriptFailed", details)
        case .unsupportedBundleLocation:
            return L10n.t("update.error.unsupportedBundleLocation")
        }
    }
}

private struct GitHubReleasePayload: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        let state: String?

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case state
        }
    }

    let tagName: String
    let name: String?
    let body: String?
    let publishedAt: Date?
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case publishedAt = "published_at"
        case assets
    }
}

enum AppRuntimeMetadata {
    static var currentVersion: String {
        let bundle = Bundle.main
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let shortVersion, !shortVersion.isEmpty {
            return shortVersion
        }

        if let buildVersion, !buildVersion.isEmpty {
            return buildVersion
        }

        return "0"
    }

    static var githubRepository: String? {
        if let overrideRepository = ProcessInfo.processInfo.environment["LAYOUTRECALL_GITHUB_REPOSITORY"],
           !overrideRepository.isEmpty
        {
            return overrideRepository
        }

        return Bundle.main.object(forInfoDictionaryKey: "LayoutRecallGitHubRepository") as? String
    }

    static var releasesAPIURL: URL? {
        guard let overrideURL = ProcessInfo.processInfo.environment["LAYOUTRECALL_RELEASES_API_URL"],
              !overrideURL.isEmpty
        else {
            return nil
        }

        return URL(string: overrideURL)
    }
}

enum AppVersionComparator {
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        compare(candidate, current) == .orderedDescending
    }

    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        guard let lhsComponents = parse(lhs), let rhsComponents = parse(rhs) else {
            return lhs.compare(rhs, options: [.numeric, .caseInsensitive])
        }

        let count = max(lhsComponents.count, rhsComponents.count)
        for index in 0..<count {
            let lhsValue = index < lhsComponents.count ? lhsComponents[index] : 0
            let rhsValue = index < rhsComponents.count ? rhsComponents[index] : 0

            if lhsValue < rhsValue {
                return .orderedAscending
            }

            if lhsValue > rhsValue {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    private static func parse(_ value: String) -> [Int]? {
        let trimmed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)

        guard !trimmed.isEmpty else {
            return nil
        }

        let mainComponent = trimmed.split(separator: "-", maxSplits: 1).first.map(String.init) ?? trimmed
        let parts = mainComponent.split(separator: ".")
        guard !parts.isEmpty else {
            return nil
        }

        var integers: [Int] = []
        for part in parts {
            guard let number = Int(part) else {
                return nil
            }
            integers.append(number)
        }

        return integers
    }
}

struct NoopAppUpdateChecker: AppUpdateChecking {
    func fetchLatestRelease() async throws -> AppRelease? {
        nil
    }
}

struct NoopAppUpdateInstaller: AppUpdateInstalling {
    func prepareUpdateInstallation(release: AppRelease, replacing bundleURL: URL) async throws {}
}

struct NoopAppUpdatePrompt: AppUpdatePrompting {
    @MainActor
    func promptToInstall(release: AppRelease, currentVersion: String) async -> AppUpdatePromptResponse {
        .later
    }
}

struct GitHubReleaseChecker: AppUpdateChecking {
    let repository: String?
    let session: URLSession

    init(
        repository: String? = AppRuntimeMetadata.githubRepository,
        session: URLSession = .shared
    ) {
        self.repository = repository
        self.session = session
    }

    func fetchLatestRelease() async throws -> AppRelease? {
        if let releasesAPIURL = AppRuntimeMetadata.releasesAPIURL {
            return try await fetchLatestRelease(from: releasesAPIURL)
        }

        guard let repository, !repository.isEmpty else {
            throw AppUpdateError.missingRepository
        }

        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw AppUpdateError.invalidResponse
        }

        return try await fetchLatestRelease(from: url)
    }

    private func fetchLatestRelease(from url: URL) async throws -> AppRelease? {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("LayoutRecall/\(AppRuntimeMetadata.currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdateError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            return nil
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw AppUpdateError.requestFailed(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(GitHubReleasePayload.self, from: data)

        guard let asset = Self.preferredAsset(from: payload.assets) else {
            throw AppUpdateError.releaseAssetMissing
        }

        return AppRelease(
            tagName: payload.tagName,
            version: Self.normalizedVersion(from: payload.tagName, fallback: payload.name),
            assetName: asset.name,
            downloadURL: asset.browserDownloadURL,
            publishedAt: payload.publishedAt,
            releaseNotes: payload.body
        )
    }

    static func normalizedVersion(from tagName: String, fallback: String?) -> String {
        let cleanedTag = tagName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)

        if !cleanedTag.isEmpty {
            return cleanedTag
        }

        return fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? tagName
    }

    fileprivate static func preferredAsset(from assets: [GitHubReleasePayload.Asset]) -> GitHubReleasePayload.Asset? {
        let zipAssets = assets.filter { asset in
            let lowercasedName = asset.name.lowercased()
            return lowercasedName.hasSuffix(".zip") && (asset.state == nil || asset.state == "uploaded")
        }

        guard !zipAssets.isEmpty else {
            return nil
        }

        let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "LayoutRecall").lowercased()
        let repositoryName = AppRuntimeMetadata.githubRepository?
            .split(separator: "/")
            .last
            .map { $0.lowercased() } ?? "layoutrecall"

        return zipAssets.max { lhs, rhs in
            assetScore(lhs.name, appName: appName, repositoryName: repositoryName)
                < assetScore(rhs.name, appName: appName, repositoryName: repositoryName)
        }
    }

    private static func assetScore(_ name: String, appName: String, repositoryName: String) -> Int {
        let lowercased = name.lowercased()
        var score = 0

        if lowercased.contains(appName) {
            score += 10
        }

        if lowercased.contains(repositoryName) {
            score += 5
        }

        if lowercased.contains("mac") || lowercased.contains("darwin") {
            score += 3
        }

        return score
    }
}

struct GitHubReleaseInstaller: AppUpdateInstalling {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func prepareUpdateInstallation(release: AppRelease, replacing bundleURL: URL) async throws {
        let fileManager = FileManager.default
        let standardizedBundleURL = bundleURL.standardizedFileURL

        guard standardizedBundleURL.pathExtension == "app" else {
            throw AppUpdateError.unsupportedBundleLocation
        }

        let destinationDirectory = standardizedBundleURL.deletingLastPathComponent()
        guard fileManager.isWritableFile(atPath: destinationDirectory.path) else {
            throw AppUpdateError.installLocationUnavailable
        }

        let stagingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("LayoutRecallUpdate-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)

        let archiveURL = stagingDirectory.appendingPathComponent(release.assetName, isDirectory: false)
        try await downloadReleaseArchive(from: release.downloadURL, to: archiveURL)

        let extractedDirectory = stagingDirectory.appendingPathComponent("Extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractedDirectory, withIntermediateDirectories: true)
        try unzipArchive(at: archiveURL, to: extractedDirectory)

        guard let extractedAppURL = findAppBundle(in: extractedDirectory) else {
            throw AppUpdateError.extractedAppMissing
        }

        let installerScriptURL = stagingDirectory.appendingPathComponent("install-update.sh", isDirectory: false)
        try writeInstallerScript(at: installerScriptURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            installerScriptURL.path,
            String(ProcessInfo.processInfo.processIdentifier),
            extractedAppURL.path,
            standardizedBundleURL.path
        ]

        do {
            try process.run()
        } catch {
            throw AppUpdateError.installScriptFailed(error.localizedDescription)
        }
    }

    private func downloadReleaseArchive(from sourceURL: URL, to destinationURL: URL) async throws {
        let fileManager = FileManager.default
        var request = URLRequest(url: sourceURL)
        request.setValue("LayoutRecall/\(AppRuntimeMetadata.currentVersion)", forHTTPHeaderField: "User-Agent")

        let (downloadedURL, response) = try await session.download(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdateError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw AppUpdateError.requestFailed(httpResponse.statusCode)
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: downloadedURL, to: destinationURL)
    }

    private func unzipArchive(at archiveURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destinationURL.path]

        let stderr = Pipe()
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let details = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw AppUpdateError.extractionFailed(details ?? archiveURL.lastPathComponent)
        }
    }

    private func findAppBundle(in directoryURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let candidateURL as URL in enumerator {
            if candidateURL.pathExtension == "app" {
                return candidateURL
            }
        }

        return nil
    }

    private func writeInstallerScript(at scriptURL: URL) throws {
        let fileManager = FileManager.default
        let script = """
        #!/bin/zsh
        set -euo pipefail

        APP_PID="$1"
        SOURCE_APP="$2"
        DEST_APP="$3"

        while kill -0 "$APP_PID" 2>/dev/null; do
          sleep 0.2
        done

        rm -rf "$DEST_APP"
        ditto "$SOURCE_APP" "$DEST_APP"
        open "$DEST_APP"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }
}

@MainActor
struct NSAlertUpdatePrompt: AppUpdatePrompting {
    func promptToInstall(release: AppRelease, currentVersion: String) async -> AppUpdatePromptResponse {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.t("update.prompt.title", release.displayVersion)

        var message = L10n.t("update.prompt.message", currentVersion, release.displayVersion)
        if let summary = release.promptSummary {
            message += "\n\n" + summary
        }

        alert.informativeText = message
        alert.addButton(withTitle: L10n.t("update.action.install"))
        alert.addButton(withTitle: L10n.t("update.action.skipVersion"))
        alert.addButton(withTitle: L10n.t("update.action.later"))

        NSApp.activate(ignoringOtherApps: true)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .install
        case .alertSecondButtonReturn:
            return .skipThisVersion
        default:
            return .later
        }
    }
}
