import Foundation

enum ConfigurationFileError: LocalizedError, Equatable {
    case invalidJSON
    case unsupportedSchema(Int)
    case unreadableFile
    case unwritableFile
    case backupFailed

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "That file is not a valid macMender configuration."
        case .unsupportedSchema(let schemaVersion):
            "That configuration was created by a newer macMender version (schema \(schemaVersion))."
        case .unreadableFile:
            "macMender could not read the selected file."
        case .unwritableFile:
            "macMender could not write the configuration file."
        case .backupFailed:
            "macMender could not create a backup of the current configuration."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidJSON:
            "Choose an exported macMender config JSON file."
        case .unsupportedSchema:
            "Update macMender before importing this file."
        case .unreadableFile:
            "Check the file location and try again."
        case .unwritableFile:
            "Check folder permissions and available disk space, then try again."
        case .backupFailed:
            "Export your current configuration manually before importing."
        }
    }
}

struct ConfigurationImportPreview: Identifiable, Equatable {
    let id = UUID()
    let sourceURL: URL
    let config: AppConfig

    var profileCount: Int {
        config.profiles.count
    }

    var selectedProfileName: String {
        config.activeProfile.name
    }

    var includesCompletedOnboarding: Bool {
        config.hasCompletedOnboarding
    }

    var menuBarSpacingTitle: String {
        config.appBehavior.menuBarSpacing.title
    }
}

enum ConfigurationFileService {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    static func exportData(for config: AppConfig) throws -> Data {
        do {
            return try encoder.encode(config)
        } catch {
            throw ConfigurationFileError.unwritableFile
        }
    }

    static func decodeImportedConfig(from data: Data) throws -> AppConfig {
        let decoded: AppConfig
        do {
            decoded = try decoder.decode(AppConfig.self, from: data)
        } catch {
            throw ConfigurationFileError.invalidJSON
        }

        guard decoded.schemaVersion <= AppConfig.default.schemaVersion else {
            throw ConfigurationFileError.unsupportedSchema(decoded.schemaVersion)
        }

        return AppConfig.normalizedForStorage(decoded)
    }
}
