import Combine
import DisplayRestoreKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var profiles: [DisplayProfile] = []
    @Published private(set) var statusLine = "Bootstrapping project scaffold."
    @Published private(set) var decisionLine = "No restore decision yet."
    @Published private(set) var lastCommand = ""
    @Published var autoRestoreEnabled = true

    private let store: ProfileStore
    private let coordinator: RestoreCoordinator
    private let currentDisplays: () -> [DisplaySnapshot]

    init(
        store: ProfileStore = ProfileStore(),
        coordinator: RestoreCoordinator = RestoreCoordinator(),
        currentDisplays: @escaping () -> [DisplaySnapshot] = { DisplaySnapshot.developmentDesk }
    ) {
        self.store = store
        self.coordinator = coordinator
        self.currentDisplays = currentDisplays

        Task {
            await bootstrap()
        }
    }

    func bootstrap() async {
        do {
            let loadedProfiles = try await store.loadProfiles()
            if loadedProfiles.isEmpty {
                profiles = [DisplayProfile.officeDock]
                try await store.saveProfiles(profiles)
            } else {
                profiles = loadedProfiles
            }

            autoRestoreEnabled = profiles.first?.settings.autoRestore ?? true
            evaluate()
            statusLine = "Repository scaffold ready for real display integration."
        } catch {
            profiles = [DisplayProfile.officeDock]
            statusLine = "Using fallback sample data because loading failed: \(error.localizedDescription)"
            evaluate()
        }
    }

    func fixNow() {
        evaluate()
        statusLine = "Manual restore flow evaluated."
    }

    func saveCurrentLayout() {
        let snapshot = currentDisplays()
        let nextIndex = profiles.count + 1
        let profile = DisplayProfile.draft(
            name: "Workspace \(nextIndex)",
            displays: snapshot,
            command: "displayplacer 'profile:\(nextIndex)'"
        )

        profiles.append(profile)
        persistProfiles()
        evaluate()
        statusLine = "Captured the current layout as \(profile.name)."
    }

    func swapLeftRight() {
        statusLine = "Swap action is stubbed. Wire this to a dedicated displayplacer command next."
        decisionLine = "Fallback actions exist in the app shell even before the real engine is connected."
    }

    func setAutoRestore(_ enabled: Bool) {
        autoRestoreEnabled = enabled

        guard !profiles.isEmpty else {
            return
        }

        profiles = profiles.map { profile in
            var updated = profile
            updated.settings.autoRestore = enabled
            return updated
        }

        persistProfiles()
        evaluate()
    }

    private func evaluate() {
        let decision = coordinator.decide(for: currentDisplays(), profiles: profiles)

        switch decision.action {
        case .autoRestore(let command):
            lastCommand = command
            decisionLine = "\(decision.reason) Score: \(decision.score ?? 0)."
        case .offerManualFix:
            lastCommand = ""
            decisionLine = decision.reason
        case .saveNewProfile:
            lastCommand = ""
            decisionLine = "Save a profile to enable matching."
        case .idle:
            lastCommand = ""
            decisionLine = decision.reason
        }
    }

    private func persistProfiles() {
        let profilesToSave = profiles

        Task {
            do {
                try await store.saveProfiles(profilesToSave)
            } catch {
                await MainActor.run {
                    self.statusLine = "Failed to save profiles: \(error.localizedDescription)"
                }
            }
        }
    }
}

