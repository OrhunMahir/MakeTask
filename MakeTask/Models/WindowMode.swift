import Foundation

enum WindowMode: String, CaseIterable, Codable, Identifiable {
    case desktop
    case alwaysOnTop
    case normal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .desktop: "Stay on Desktop"
        case .alwaysOnTop: "Always on Top"
        case .normal: "Normal Window"
        }
    }
}
