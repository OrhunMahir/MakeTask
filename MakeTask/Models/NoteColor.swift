import SwiftUI

enum NoteColor: String, CaseIterable, Codable, Identifiable {
    case yellow
    case blue
    case green
    case pink
    case graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yellow: "Yellow"
        case .blue: "Blue"
        case .green: "Green"
        case .pink: "Pink"
        case .graphite: "Graphite"
        }
    }

    var tint: Color {
        switch self {
        case .yellow: Color(red: 1.00, green: 0.78, blue: 0.20)
        case .blue: Color(red: 0.28, green: 0.64, blue: 1.00)
        case .green: Color(red: 0.33, green: 0.78, blue: 0.48)
        case .pink: Color(red: 1.00, green: 0.43, blue: 0.66)
        case .graphite: Color(red: 0.55, green: 0.57, blue: 0.62)
        }
    }
}
