import SwiftUI

enum NoteColor: String, CaseIterable, Codable, Identifiable {
    case yellow
    case orange
    case red
    case pink
    case purple
    case indigo
    case blue
    case teal
    case green
    case graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yellow: "Yellow"
        case .orange: "Orange"
        case .red: "Red"
        case .pink: "Pink"
        case .purple: "Purple"
        case .indigo: "Indigo"
        case .blue: "Blue"
        case .teal: "Teal"
        case .green: "Green"
        case .graphite: "Graphite"
        }
    }

    var tint: Color {
        switch self {
        case .yellow: Color(red: 1.00, green: 0.78, blue: 0.20)
        case .orange: Color(red: 1.00, green: 0.55, blue: 0.18)
        case .red: Color(red: 0.96, green: 0.31, blue: 0.32)
        case .pink: Color(red: 1.00, green: 0.43, blue: 0.66)
        case .purple: Color(red: 0.68, green: 0.46, blue: 0.95)
        case .indigo: Color(red: 0.38, green: 0.45, blue: 0.92)
        case .blue: Color(red: 0.28, green: 0.64, blue: 1.00)
        case .teal: Color(red: 0.20, green: 0.75, blue: 0.75)
        case .green: Color(red: 0.33, green: 0.78, blue: 0.48)
        case .graphite: Color(red: 0.55, green: 0.57, blue: 0.62)
        }
    }
}
