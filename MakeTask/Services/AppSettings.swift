import AppKit
import Carbon.HIToolbox
import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    enum SettingsTab: Hashable {
        case general
        case appearance
        case shortcuts
        case guide
    }

    enum AppearanceMode: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }
    }

    private enum Key {
        static let appearance = "appearance"
        static let transparency = "transparency"
        static let noteOpacity = "noteOpacity"
        static let hideCompleted = "hideCompleted"
        static let defaultListID = "defaultListID"
        static let lastQuickCaptureListID = "lastQuickCaptureListID"
        static let quickAddKeyCode = "quickAddKeyCode"
        static let quickAddCommand = "quickAddCommand"
        static let quickAddShift = "quickAddShift"
        static let quickAddOption = "quickAddOption"
        static let quickAddControl = "quickAddControl"
    }

    private let defaults: UserDefaults

    @Published var selectedSettingsTab: SettingsTab = .general

    @Published var appearance: AppearanceMode {
        didSet {
            defaults.set(appearance.rawValue, forKey: Key.appearance)
            applyAppearance()
        }
    }

    @Published var transparencyEnabled: Bool {
        didSet { defaults.set(transparencyEnabled, forKey: Key.transparency) }
    }

    @Published var noteOpacity: Double {
        didSet { defaults.set(noteOpacity, forKey: Key.noteOpacity) }
    }

    @Published var hideCompletedTasks: Bool {
        didSet { defaults.set(hideCompletedTasks, forKey: Key.hideCompleted) }
    }

    @Published var defaultListID: UUID? {
        didSet { defaults.set(defaultListID?.uuidString, forKey: Key.defaultListID) }
    }

    @Published var lastQuickCaptureListID: UUID? {
        didSet { defaults.set(lastQuickCaptureListID?.uuidString, forKey: Key.lastQuickCaptureListID) }
    }

    @Published var quickAddKeyCode: UInt32 {
        didSet { defaults.set(Int(quickAddKeyCode), forKey: Key.quickAddKeyCode) }
    }

    @Published var quickAddUsesCommand: Bool {
        didSet { defaults.set(quickAddUsesCommand, forKey: Key.quickAddCommand) }
    }

    @Published var quickAddUsesShift: Bool {
        didSet { defaults.set(quickAddUsesShift, forKey: Key.quickAddShift) }
    }

    @Published var quickAddUsesOption: Bool {
        didSet { defaults.set(quickAddUsesOption, forKey: Key.quickAddOption) }
    }

    @Published var quickAddUsesControl: Bool {
        didSet { defaults.set(quickAddUsesControl, forKey: Key.quickAddControl) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        appearance = AppearanceMode(
            rawValue: defaults.string(forKey: Key.appearance) ?? "system"
        ) ?? .system

        transparencyEnabled = defaults.object(forKey: Key.transparency) as? Bool ?? true
        let savedOpacity = defaults.object(forKey: Key.noteOpacity) as? Double ?? 0.92
        noteOpacity = min(max(savedOpacity, 0.45), 1.0)
        hideCompletedTasks = defaults.bool(forKey: Key.hideCompleted)
        defaultListID = defaults.string(forKey: Key.defaultListID).flatMap(UUID.init(uuidString:))
        lastQuickCaptureListID = defaults.string(forKey: Key.lastQuickCaptureListID).flatMap(UUID.init(uuidString:))

        quickAddKeyCode = UInt32(
            defaults.object(forKey: Key.quickAddKeyCode) as? Int ?? Int(kVK_Space)
        )
        quickAddUsesCommand = defaults.object(forKey: Key.quickAddCommand) as? Bool ?? true
        quickAddUsesShift = defaults.object(forKey: Key.quickAddShift) as? Bool ?? true
        quickAddUsesOption = defaults.bool(forKey: Key.quickAddOption)
        quickAddUsesControl = defaults.bool(forKey: Key.quickAddControl)
    }

    var quickAddCarbonModifiers: UInt32 {
        var modifiers: UInt32 = 0
        if quickAddUsesCommand { modifiers |= UInt32(cmdKey) }
        if quickAddUsesShift { modifiers |= UInt32(shiftKey) }
        if quickAddUsesOption { modifiers |= UInt32(optionKey) }
        if quickAddUsesControl { modifiers |= UInt32(controlKey) }
        return modifiers
    }

    var quickAddShortcutDescription: String {
        var result = ""
        if quickAddUsesControl { result += "⌃" }
        if quickAddUsesOption { result += "⌥" }
        if quickAddUsesShift { result += "⇧" }
        if quickAddUsesCommand { result += "⌘" }
        result += Self.keyName(for: quickAddKeyCode)
        return result
    }

    func applyAppearance() {
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: "Space"
        case kVK_Return: "Return"
        case kVK_ANSI_A: "A"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_T: "T"
        default: "Key \(keyCode)"
        }
    }
}
