import AppKit

@MainActor
enum NoteKeyboardRouting {
    /// Only the note canvas owns task shortcuts. A focused control (including a
    /// SwiftUI focus responder) gets the event before any selected-task action.
    static func controlHasFocus(in window: NSWindow) -> Bool {
        guard let responder = window.firstResponder else { return false }
        if responder is TaskDragSourceNSView { return false }
        if responder is NSControl || responder is NSText { return true }
        return responder !== window && responder !== window.contentView
    }

    static func allows(_ action: AppShortcutAction, event: NSEvent, in window: NSWindow) -> Bool {
        guard window.attachedSheet == nil, NSApp.modalWindow == nil else { return false }
        guard controlHasFocus(in: window) else { return true }

        // Keep explicit window commands available while editing, but don't let
        // a remapped Space/Return/arrow/Escape close or collapse the note.
        switch action {
        case .hideCurrentNote, .collapseCurrentNote, .searchTasks:
            return event.modifierFlags.contains(.command)
        default:
            return false
        }
    }
}
