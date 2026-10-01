import Foundation

enum AppBuildInfo {
    static var version: String {
        value(for: "CFBundleShortVersionString")
    }

    static var build: String {
        value(for: "CFBundleVersion")
    }

    private static func value(for key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "—"
    }
}
