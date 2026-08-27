import AppKit
import Carbon.HIToolbox
import Foundation

struct ShortcutModifiers: OptionSet, Codable, Hashable {
    let rawValue: UInt8

    static let command = ShortcutModifiers(rawValue: 1 << 0)
    static let shift = ShortcutModifiers(rawValue: 1 << 1)
    static let option = ShortcutModifiers(rawValue: 1 << 2)
    static let control = ShortcutModifiers(rawValue: 1 << 3)

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    init(eventFlags: NSEvent.ModifierFlags) {
        let flags = eventFlags.intersection(.deviceIndependentFlagsMask)
        var result: ShortcutModifiers = []
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        self = result
    }

    var carbonValue: UInt32 {
        var result: UInt32 = 0
        if contains(.command) { result |= UInt32(cmdKey) }
        if contains(.shift) { result |= UInt32(shiftKey) }
        if contains(.option) { result |= UInt32(optionKey) }
        if contains(.control) { result |= UInt32(controlKey) }
        return result
    }

    var displayString: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}

struct AppShortcut: Codable, Hashable {
    let keyCode: UInt16
    let modifiers: ShortcutModifiers
    let keyLabel: String

    init(keyCode: Int, modifiers: ShortcutModifiers = [], keyLabel: String? = nil) {
        self.keyCode = UInt16(keyCode)
        self.modifiers = modifiers
        self.keyLabel = keyLabel ?? Self.label(for: UInt16(keyCode), fallback: nil)
    }

    init(event: NSEvent) {
        keyCode = event.keyCode
        modifiers = ShortcutModifiers(eventFlags: event.modifierFlags)
        keyLabel = Self.label(for: event.keyCode, fallback: event.charactersIgnoringModifiers)
    }

    var displayString: String {
        modifiers.displayString + keyLabel
    }

    var systemConflictDescription: String? {
        if modifiers == [.command] {
            switch Int(keyCode) {
            case kVK_ANSI_Q: return "Reserved for Quit MakeTask"
            case kVK_ANSI_Comma: return "Reserved for MakeTask Settings"
            case kVK_ANSI_H: return "Reserved for macOS Hide Application"
            case kVK_Tab: return "Reserved for the macOS App Switcher"
            case kVK_Space: return "Reserved for macOS Spotlight"
            default: break
            }
        }

        if Int(keyCode) == kVK_Escape, modifiers == [.command, .option] {
            return "Reserved for the macOS Force Quit window"
        }
        if Int(keyCode) == kVK_ANSI_Q, modifiers == [.command, .control] {
            return "Reserved for Lock Screen"
        }
        return nil
    }

    func matches(_ event: NSEvent) -> Bool {
        keyCode == event.keyCode
            && modifiers == ShortcutModifiers(eventFlags: event.modifierFlags)
    }

    static func == (lhs: AppShortcut, rhs: AppShortcut) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifiers == rhs.modifiers
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(modifiers)
    }

    private static func label(for keyCode: UInt16, fallback: String?) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: "A"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"
        case kVK_ANSI_K: "K"
        case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_Z: "Z"
        case kVK_ANSI_0: "0"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_ANSI_Equal: "="
        case kVK_ANSI_Minus: "−"
        case kVK_ANSI_LeftBracket: "["
        case kVK_ANSI_RightBracket: "]"
        case kVK_ANSI_Quote: "'"
        case kVK_ANSI_Semicolon: ";"
        case kVK_ANSI_Backslash: "\\"
        case kVK_ANSI_Comma: ","
        case kVK_ANSI_Slash: "/"
        case kVK_ANSI_Period: "."
        case kVK_ANSI_Grave: "`"
        case kVK_Return, kVK_ANSI_KeypadEnter: "Return"
        case kVK_Tab: "Tab"
        case kVK_Space: "Space"
        case kVK_Delete: "⌫"
        case kVK_ForwardDelete: "⌦"
        case kVK_Escape: "Esc"
        case kVK_LeftArrow: "←"
        case kVK_RightArrow: "→"
        case kVK_DownArrow: "↓"
        case kVK_UpArrow: "↑"
        case kVK_Home: "Home"
        case kVK_End: "End"
        case kVK_PageUp: "Page Up"
        case kVK_PageDown: "Page Down"
        case kVK_F1: "F1"
        case kVK_F2: "F2"
        case kVK_F3: "F3"
        case kVK_F4: "F4"
        case kVK_F5: "F5"
        case kVK_F6: "F6"
        case kVK_F7: "F7"
        case kVK_F8: "F8"
        case kVK_F9: "F9"
        case kVK_F10: "F10"
        case kVK_F11: "F11"
        case kVK_F12: "F12"
        default:
            fallback?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().nonEmpty
                ?? "Key \(keyCode)"
        }
    }
}

enum AppShortcutSection: String, CaseIterable, Identifiable {
    case global
    case notes
    case tasks
    case listNavigation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .global: "Global Shortcuts"
        case .notes: "Notes & Lists"
        case .tasks: "Tasks"
        case .listNavigation: "List Navigation"
        }
    }

    var detail: String {
        switch self {
        case .global: "Available while you are working in another app."
        case .notes: "Commands for creating and managing MakeTask notes."
        case .tasks: "Commands for the selected task in the active note."
        case .listNavigation: "Direct shortcuts for your first nine lists."
        }
    }
}

enum AppShortcutAction: String, CaseIterable, Codable, Identifiable {
    case quickAdd
    case toggleAllNotesVisibility
    case newTask
    case newList
    case hideCurrentNote
    case collapseCurrentNote
    case searchTasks
    case undo
    case redo
    case deleteCurrentNote
    case renameCurrentList
    case toggleCompletedTasks
    case clearCompletedTasks
    case selectPreviousTask
    case selectNextTask
    case completeSelectedTask
    case editSelectedTask
    case deleteSelectedTask
    case moveSelectedTaskUp
    case moveSelectedTaskDown
    case moveTaskToPreviousList
    case moveTaskToNextList
    case switchToList1
    case switchToList2
    case switchToList3
    case switchToList4
    case switchToList5
    case switchToList6
    case switchToList7
    case switchToList8
    case switchToList9

    var id: String { rawValue }

    var section: AppShortcutSection {
        switch self {
        case .quickAdd, .toggleAllNotesVisibility:
            .global
        case .newTask, .newList, .hideCurrentNote, .collapseCurrentNote, .searchTasks,
             .undo, .redo, .deleteCurrentNote, .renameCurrentList,
             .toggleCompletedTasks, .clearCompletedTasks:
            .notes
        case .selectPreviousTask, .selectNextTask, .completeSelectedTask,
             .editSelectedTask, .deleteSelectedTask, .moveSelectedTaskUp,
             .moveSelectedTaskDown, .moveTaskToPreviousList, .moveTaskToNextList:
            .tasks
        case .switchToList1, .switchToList2, .switchToList3, .switchToList4,
             .switchToList5, .switchToList6, .switchToList7, .switchToList8,
             .switchToList9:
            .listNavigation
        }
    }

    var isGlobal: Bool {
        section == .global
    }

    var title: String {
        switch self {
        case .quickAdd: "Quick Add"
        case .toggleAllNotesVisibility: "Show/Hide All Notes"
        case .newTask: "New Task"
        case .newList: "New List"
        case .hideCurrentNote: "Hide Current Note"
        case .collapseCurrentNote: "Collapse Current Note"
        case .searchTasks: "Search Tasks"
        case .undo: "Undo Last Action"
        case .redo: "Redo Last Action"
        case .deleteCurrentNote: "Delete Current Note"
        case .renameCurrentList: "Rename Current List"
        case .toggleCompletedTasks: "Toggle Completed Tasks"
        case .clearCompletedTasks: "Clear Completed Tasks"
        case .selectPreviousTask: "Select Previous Task"
        case .selectNextTask: "Select Next Task"
        case .completeSelectedTask: "Complete Selected Task"
        case .editSelectedTask: "Edit Selected Task"
        case .deleteSelectedTask: "Delete Selected Task"
        case .moveSelectedTaskUp: "Move Selected Task Up"
        case .moveSelectedTaskDown: "Move Selected Task Down"
        case .moveTaskToPreviousList: "Move Task to Previous List"
        case .moveTaskToNextList: "Move Task to Next List"
        case .switchToList1: "Switch to List 1"
        case .switchToList2: "Switch to List 2"
        case .switchToList3: "Switch to List 3"
        case .switchToList4: "Switch to List 4"
        case .switchToList5: "Switch to List 5"
        case .switchToList6: "Switch to List 6"
        case .switchToList7: "Switch to List 7"
        case .switchToList8: "Switch to List 8"
        case .switchToList9: "Switch to List 9"
        }
    }

    var detail: String {
        switch self {
        case .quickAdd: "Capture a task from any application."
        case .toggleAllNotesVisibility: "Reveal hidden notes or hide all visible notes."
        case .newTask: "Focus task entry in the active note."
        case .newList: "Create and immediately name a new note."
        case .hideCurrentNote: "Remove the active note from the desktop."
        case .collapseCurrentNote: "Roll the active note up to its header."
        case .searchTasks: "Filter tasks in the active note."
        case .undo: "Undo the last MakeTask data change."
        case .redo: "Reapply the last undone change."
        case .deleteCurrentNote: "Ask before deleting the active note."
        case .renameCurrentList: "Edit the active note's title."
        case .toggleCompletedTasks: "Collapse or expand completed tasks."
        case .clearCompletedTasks: "Ask before deleting completed tasks."
        case .selectPreviousTask: "Move the keyboard selection upward."
        case .selectNextTask: "Move the keyboard selection downward."
        case .completeSelectedTask: "Complete or reopen the selected task."
        case .editSelectedTask: "Open details for the selected task."
        case .deleteSelectedTask: "Delete the selected task."
        case .moveSelectedTaskUp: "Move the selected task one position up."
        case .moveSelectedTaskDown: "Move the selected task one position down."
        case .moveTaskToPreviousList: "Send the selected task to the previous note."
        case .moveTaskToNextList: "Send the selected task to the next note."
        case .switchToList1, .switchToList2, .switchToList3, .switchToList4,
             .switchToList5, .switchToList6, .switchToList7, .switchToList8,
             .switchToList9:
            "Activate this list position from the keyboard."
        }
    }

    var icon: String {
        switch self {
        case .quickAdd: "bolt.fill"
        case .toggleAllNotesVisibility: "eye"
        case .newTask: "plus.circle"
        case .newList: "plus.rectangle.on.rectangle"
        case .hideCurrentNote: "eye.slash"
        case .collapseCurrentNote: "rectangle.compress.vertical"
        case .searchTasks: "magnifyingglass"
        case .undo: "arrow.uturn.backward"
        case .redo: "arrow.uturn.forward"
        case .deleteCurrentNote, .deleteSelectedTask: "trash"
        case .renameCurrentList: "text.cursor"
        case .toggleCompletedTasks: "checkmark.circle.badge.questionmark"
        case .clearCompletedTasks: "trash.slash"
        case .selectPreviousTask: "arrow.up"
        case .selectNextTask: "arrow.down"
        case .completeSelectedTask: "checkmark.circle"
        case .editSelectedTask: "pencil"
        case .moveSelectedTaskUp: "arrow.up.to.line"
        case .moveSelectedTaskDown: "arrow.down.to.line"
        case .moveTaskToPreviousList: "arrow.left"
        case .moveTaskToNextList: "arrow.right"
        case .switchToList1, .switchToList2, .switchToList3, .switchToList4,
             .switchToList5, .switchToList6, .switchToList7, .switchToList8,
             .switchToList9:
            "square.stack"
        }
    }

    var defaultShortcut: AppShortcut {
        switch self {
        case .quickAdd:
            AppShortcut(keyCode: kVK_Space, modifiers: [.command, .shift])
        case .toggleAllNotesVisibility:
            AppShortcut(keyCode: kVK_ANSI_H, modifiers: [.command, .shift])
        case .newTask:
            AppShortcut(keyCode: kVK_ANSI_N, modifiers: [.command])
        case .newList:
            AppShortcut(keyCode: kVK_ANSI_N, modifiers: [.command, .shift])
        case .hideCurrentNote:
            AppShortcut(keyCode: kVK_ANSI_W, modifiers: [.command])
        case .collapseCurrentNote:
            AppShortcut(keyCode: kVK_ANSI_M, modifiers: [.command])
        case .searchTasks:
            AppShortcut(keyCode: kVK_ANSI_F, modifiers: [.command])
        case .undo:
            AppShortcut(keyCode: kVK_ANSI_Z, modifiers: [.command])
        case .redo:
            AppShortcut(keyCode: kVK_ANSI_Z, modifiers: [.command, .shift])
        case .deleteCurrentNote:
            AppShortcut(keyCode: kVK_Delete, modifiers: [.command])
        case .renameCurrentList:
            AppShortcut(keyCode: kVK_ANSI_L, modifiers: [.command])
        case .toggleCompletedTasks:
            AppShortcut(keyCode: kVK_ANSI_C, modifiers: [.command, .shift])
        case .clearCompletedTasks:
            AppShortcut(keyCode: kVK_Delete, modifiers: [.command, .option])
        case .selectPreviousTask:
            AppShortcut(keyCode: kVK_UpArrow)
        case .selectNextTask:
            AppShortcut(keyCode: kVK_DownArrow)
        case .completeSelectedTask:
            AppShortcut(keyCode: kVK_Space)
        case .editSelectedTask:
            AppShortcut(keyCode: kVK_Return)
        case .deleteSelectedTask:
            AppShortcut(keyCode: kVK_Delete)
        case .moveSelectedTaskUp:
            AppShortcut(keyCode: kVK_UpArrow, modifiers: [.option])
        case .moveSelectedTaskDown:
            AppShortcut(keyCode: kVK_DownArrow, modifiers: [.option])
        case .moveTaskToPreviousList:
            AppShortcut(keyCode: kVK_LeftArrow, modifiers: [.command, .control])
        case .moveTaskToNextList:
            AppShortcut(keyCode: kVK_RightArrow, modifiers: [.command, .control])
        case .switchToList1:
            AppShortcut(keyCode: kVK_ANSI_1, modifiers: [.command])
        case .switchToList2:
            AppShortcut(keyCode: kVK_ANSI_2, modifiers: [.command])
        case .switchToList3:
            AppShortcut(keyCode: kVK_ANSI_3, modifiers: [.command])
        case .switchToList4:
            AppShortcut(keyCode: kVK_ANSI_4, modifiers: [.command])
        case .switchToList5:
            AppShortcut(keyCode: kVK_ANSI_5, modifiers: [.command])
        case .switchToList6:
            AppShortcut(keyCode: kVK_ANSI_6, modifiers: [.command])
        case .switchToList7:
            AppShortcut(keyCode: kVK_ANSI_7, modifiers: [.command])
        case .switchToList8:
            AppShortcut(keyCode: kVK_ANSI_8, modifiers: [.command])
        case .switchToList9:
            AppShortcut(keyCode: kVK_ANSI_9, modifiers: [.command])
        }
    }

    var listIndex: Int? {
        Self.listSwitchActions.firstIndex(of: self)
    }

    static let listSwitchActions: [AppShortcutAction] = [
        .switchToList1, .switchToList2, .switchToList3,
        .switchToList4, .switchToList5, .switchToList6,
        .switchToList7, .switchToList8, .switchToList9
    ]
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
