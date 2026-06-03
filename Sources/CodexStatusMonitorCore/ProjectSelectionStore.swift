import Foundation

public final class ProjectSelectionStore {
    private let defaults: UserDefaults
    private let projectDirectoryKey = "selectedProjectDirectory"
    private let providerKey = "selectedProvider"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var selectedProjectDirectory: URL? {
        get {
            guard let path = defaults.string(forKey: projectDirectoryKey), !path.isEmpty else {
                return nil
            }
            return URL(fileURLWithPath: path)
        }
        set {
            defaults.set(newValue?.path, forKey: projectDirectoryKey)
        }
    }

    public var selectedProvider: ProviderKind {
        get {
            guard let value = defaults.string(forKey: providerKey),
                  let provider = ProviderKind(rawValue: value)
            else {
                return .codex
            }
            return provider
        }
        set {
            defaults.set(newValue.rawValue, forKey: providerKey)
        }
    }
}
