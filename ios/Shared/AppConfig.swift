import Foundation

enum AppConfig {
    /// Must match the App Group configured in project.yml for both the app and the share extension.
    static let appGroupIdentifier = "group.com.kukjinman.aidetector"

    private static let backendURLDefaultsKey = "backendBaseURLString"

    /// `localhost` only resolves to the backend when running in the
    /// Simulator (it shares the Mac's network namespace). On a physical
    /// device, `localhost` is the device itself, so this must be the Mac's
    /// LAN IP (e.g. http://192.168.x.x:8787) while developing, or a real
    /// deployed HTTPS URL for release. Editable from Settings so it doesn't
    /// require a rebuild when the LAN IP changes; stored in the shared App
    /// Group defaults so the Share Extension picks up the same value.
    static var backendBaseURL: URL {
        get {
            #if DEBUG
            if engineeringEnabled { return URL(string: "https://kukjinman.com/aidetector-test/")! }
            if let stored = sharedDefaults.string(forKey: backendURLDefaultsKey),
               let url = URL(string: stored) {
                return url
            }
            #endif
            return URL(string: Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String ?? "https://api.example.invalid")!
        }
        set {
            sharedDefaults.set(newValue.absoluteString, forKey: backendURLDefaultsKey)
        }
    }

    static var engineeringEnabled: Bool {
        #if DEBUG
        return sharedDefaults.bool(forKey: "engineeringEnabled") && engineeringKey != nil
        #else
        return false
        #endif
    }
    static var engineeringKey: String? {
        #if DEBUG
        guard let value = Bundle.main.object(forInfoDictionaryKey: "EngineeringAccessKey") as? String,
              value.count == 64 else { return nil }
        return value
        #else
        return nil
        #endif
    }
    static var website: URL { URL(string: Bundle.main.object(forInfoDictionaryKey: "PublicWebsiteURL") as? String ?? "https://example.invalid")! }
    static func legalURL(_ path: String) -> URL { backendBaseURL.appendingPathComponent(path) }
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
