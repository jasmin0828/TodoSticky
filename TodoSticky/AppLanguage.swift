import Foundation

enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"
}
