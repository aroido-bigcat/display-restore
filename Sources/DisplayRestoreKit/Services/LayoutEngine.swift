import Foundation

public protocol LayoutEngine {
    func restoreCommand(for profile: DisplayProfile) throws -> String
}

public enum LayoutEngineError: Error, LocalizedError, Sendable {
    case unsupportedEngine(String)
    case missingCommand

    public var errorDescription: String? {
        switch self {
        case .unsupportedEngine(let type):
            return "Unsupported layout engine: \(type)"
        case .missingCommand:
            return "The profile does not include a restore command."
        }
    }
}

public struct DisplayplacerLayoutEngine: LayoutEngine, Sendable {
    public init() {}

    public func restoreCommand(for profile: DisplayProfile) throws -> String {
        guard profile.layout.engine.type == "displayplacer" else {
            throw LayoutEngineError.unsupportedEngine(profile.layout.engine.type)
        }

        guard !profile.layout.engine.command.isEmpty else {
            throw LayoutEngineError.missingCommand
        }

        return profile.layout.engine.command
    }
}

