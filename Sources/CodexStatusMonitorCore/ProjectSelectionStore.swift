import Foundation

public final class ProjectSelectionStore {
    private let defaults: UserDefaults
    private let key = "selectedProjectDirectory"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var selectedProjectDirectory: URL? {
        get {
            guard let path = defaults.string(forKey: key), !path.isEmpty else {
                return nil
            }
            return URL(fileURLWithPath: path)
        }
        set {
            defaults.set(newValue?.path, forKey: key)
        }
    }
}
