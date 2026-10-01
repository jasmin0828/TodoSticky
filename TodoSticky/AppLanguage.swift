import Foundation

enum AppLanguage: String, CaseIterable, Codable, Hashable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"
}
