import Foundation

enum AppMetadata {
    static let fallbackBundleIdentifier = "io.github.tomato-ga.NatureRemoMac"
    static let fallbackShortVersion = "0.1.0"

    static var bundleIdentifier: String {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return fallbackBundleIdentifier
        }
        return Bundle.main.bundleIdentifier ?? fallbackBundleIdentifier
    }

    static var shortVersion: String {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            return fallbackShortVersion
        }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? fallbackShortVersion
    }

    static var userAgent: String {
        "NatureRemoMac/\(shortVersion)"
    }
}
