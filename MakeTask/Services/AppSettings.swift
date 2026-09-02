import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    enum SettingsTab: Hashable {
        case general
        case appearance
        case shortcuts
        case backup
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

    enum Typography: String, CaseIterable, Identifiable {
        case system
        case rounded
        case serif
        case monospaced

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: "System"
            case .rounded: "Rounded"
            case .serif: "Serif"
            case .monospaced: "Monospaced"
            }
        }

        fileprivate var swiftUIDesign: Font.Design {
            switch self {
            case .system: .default
            case .rounded: .rounded
            case .serif: .serif
            case .monospaced: .monospaced
            }
        }

        fileprivate var appKitDesign: NSFontDescriptor.SystemDesign? {
            switch self {
            case .system: nil
            case .rounded: .rounded
            case .serif: .serif
            case .monospaced: .monospaced
            }
        }
    }

    enum CompletionSound: String, CaseIterable, Identifiable {
        case none
        case pop
        case tink
        case glass
        case funk
        case purr
        case bottle
        case blow
        case ping

        var id: String { rawValue }

        var title: String {
            switch self {
            case .none: "None"
            case .pop: "Pop"
            case .tink: "Tink"
            case .glass: "Glass"
            case .funk: "Funk"
            case .purr: "Purr — Soft"
            case .bottle: "Bottle — Soft"
            case .blow: "Blow — Airy"
            case .ping: "Ping — Light"
            }
        }

        private var systemSoundName: String? {
            switch self {
            case .none: nil
            case .pop: "Pop"
            case .tink: "Tink"
            case .glass: "Glass"
            case .funk: "Funk"
            case .purr: "Purr"
            case .bottle: "Bottle"
            case .blow: "Blow"
            case .ping: "Ping"
            }
        }

        func play(volume: Double) {
            guard
                let systemSoundName,
                let sound = NSSound(named: NSSound.Name(systemSoundName))
            else { return }

            sound.volume = Float(min(max(volume, 0), 1))
            sound.stop()
            sound.play()
        }
    }

    private enum Key {
        static let appearance = "appearance"
        static let typography = "typography"
        static let transparency = "transparency"
        static let noteOpacity = "noteOpacity"
        static let hideCompleted = "hideCompleted"
        static let completionSound = "completionSound"
        static let completionSoundVolume = "completionSoundVolume"
        static let defaultListID = "defaultListID"
        static let lastQuickCaptureListID = "lastQuickCaptureListID"
        static let shortcutBindings = "shortcutBindings.v2"
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

    @Published var typography: Typography {
        didSet { defaults.set(typography.rawValue, forKey: Key.typography) }
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

    @Published var completionSound: CompletionSound {
        didSet { defaults.set(completionSound.rawValue, forKey: Key.completionSound) }
    }

    @Published var completionSoundVolume: Double {
        didSet { defaults.set(completionSoundVolume, forKey: Key.completionSoundVolume) }
    }

    @Published var defaultListID: UUID? {
        didSet { defaults.set(defaultListID?.uuidString, forKey: Key.defaultListID) }
    }

    @Published var lastQuickCaptureListID: UUID? {
        didSet { defaults.set(lastQuickCaptureListID?.uuidString, forKey: Key.lastQuickCaptureListID) }
    }

    @Published private(set) var shortcutBindings: [AppShortcutAction: AppShortcut] {
        didSet { persistShortcutBindings() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        appearance = AppearanceMode(
            rawValue: defaults.string(forKey: Key.appearance) ?? "system"
        ) ?? .system
        typography = Typography(
            rawValue: defaults.string(forKey: Key.typography) ?? Typography.system.rawValue
        ) ?? .system

        transparencyEnabled = defaults.object(forKey: Key.transparency) as? Bool ?? true
        let savedOpacity = defaults.object(forKey: Key.noteOpacity) as? Double ?? 0.92
        noteOpacity = min(max(savedOpacity, 0.45), 1.0)
        hideCompletedTasks = defaults.bool(forKey: Key.hideCompleted)
        completionSound = CompletionSound(
            rawValue: defaults.string(forKey: Key.completionSound) ?? CompletionSound.pop.rawValue
        ) ?? .pop
        let savedSoundVolume = defaults.object(forKey: Key.completionSoundVolume) as? Double ?? 0.65
        completionSoundVolume = min(max(savedSoundVolume, 0), 1)
        defaultListID = defaults.string(forKey: Key.defaultListID).flatMap(UUID.init(uuidString:))
        lastQuickCaptureListID = defaults.string(forKey: Key.lastQuickCaptureListID).flatMap(UUID.init(uuidString:))
        shortcutBindings = Self.loadShortcutBindings(from: defaults)
    }

    var quickAddShortcutDescription: String {
        shortcutDescription(for: .quickAdd)
    }

    func shortcut(for action: AppShortcutAction) -> AppShortcut {
        shortcutBindings[action] ?? action.defaultShortcut
    }

    func shortcutDescription(for action: AppShortcutAction) -> String {
        shortcut(for: action).displayString
    }

    func action(matching event: NSEvent) -> AppShortcutAction? {
        AppShortcutAction.allCases.first { shortcut(for: $0).matches(event) }
    }

    func conflictingActions(
        for shortcut: AppShortcut,
        excluding action: AppShortcutAction
    ) -> [AppShortcutAction] {
        AppShortcutAction.allCases.filter {
            $0 != action && self.shortcut(for: $0) == shortcut
        }
    }

    func setShortcut(_ shortcut: AppShortcut, for action: AppShortcutAction) {
        shortcutBindings[action] = shortcut
    }

    func resetShortcut(_ action: AppShortcutAction) {
        shortcutBindings[action] = action.defaultShortcut
    }

    func resetAllShortcuts() {
        shortcutBindings = Self.defaultShortcutBindings
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

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: typography.swiftUIDesign)
    }

    func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let baseFont = NSFont.systemFont(ofSize: size, weight: weight)
        guard
            let design = typography.appKitDesign,
            let descriptor = baseFont.fontDescriptor.withDesign(design),
            let designedFont = NSFont(descriptor: descriptor, size: size)
        else {
            return baseFont
        }
        return designedFont
    }

    func playCompletionSound() {
        completionSound.play(volume: completionSoundVolume)
    }

    func playSubtaskCompletionSound() {
        completionSound.play(volume: completionSoundVolume * 0.35)
    }

    private static var defaultShortcutBindings: [AppShortcutAction: AppShortcut] {
        Dictionary(uniqueKeysWithValues: AppShortcutAction.allCases.map {
            ($0, $0.defaultShortcut)
        })
    }

    private static func loadShortcutBindings(
        from defaults: UserDefaults
    ) -> [AppShortcutAction: AppShortcut] {
        var result = defaultShortcutBindings

        if let data = defaults.data(forKey: Key.shortcutBindings),
           let stored = try? JSONDecoder().decode([String: AppShortcut].self, from: data) {
            for (rawAction, shortcut) in stored {
                guard let action = AppShortcutAction(rawValue: rawAction) else { continue }
                result[action] = shortcut
            }
            return result
        }

        var legacyModifiers: ShortcutModifiers = []
        if defaults.object(forKey: Key.quickAddCommand) as? Bool ?? true {
            legacyModifiers.insert(.command)
        }
        if defaults.object(forKey: Key.quickAddShift) as? Bool ?? true {
            legacyModifiers.insert(.shift)
        }
        if defaults.bool(forKey: Key.quickAddOption) {
            legacyModifiers.insert(.option)
        }
        if defaults.bool(forKey: Key.quickAddControl) {
            legacyModifiers.insert(.control)
        }
        let legacyKeyCode = defaults.object(forKey: Key.quickAddKeyCode) as? Int
            ?? Int(AppShortcutAction.quickAdd.defaultShortcut.keyCode)
        result[.quickAdd] = AppShortcut(
            keyCode: legacyKeyCode,
            modifiers: legacyModifiers
        )
        return result
    }

    private func persistShortcutBindings() {
        let stored = Dictionary(uniqueKeysWithValues: shortcutBindings.map {
            ($0.key.rawValue, $0.value)
        })
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: Key.shortcutBindings)
    }
}
