import SwiftUI

enum StickyColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case yellow
    case blue
    case green
    case pink
    case purple
    case gray

    var id: Self { self }

    var title: String {
        switch self {
        case .yellow: String(localized: "color.yellow")
        case .blue: String(localized: "color.blue")
        case .green: String(localized: "color.green")
        case .pink: String(localized: "color.pink")
        case .purple: String(localized: "color.purple")
        case .gray: String(localized: "color.gray")
        }
    }

    var color: Color {
        switch self {
        case .yellow: Color(red: 1.00, green: 0.93, blue: 0.58)
        case .blue: Color(red: 0.78, green: 0.88, blue: 0.98)
        case .green: Color(red: 0.80, green: 0.92, blue: 0.78)
        case .pink: Color(red: 0.98, green: 0.82, blue: 0.86)
        case .purple: Color(red: 0.87, green: 0.83, blue: 0.96)
        case .gray: Color(red: 0.86, green: 0.87, blue: 0.88)
        }
    }
}
