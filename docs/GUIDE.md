# MakeTask Feature and Shortcut Reference

[← Back to MakeTask](../README.md)

## Features

- Multiple independent floating todo notes
- No forced Inbox or other system list
- Create, rename, hide, show, and delete lists
- Click a list title to rename it inline; new lists start in rename mode
- Create a named list directly inside Quick Add without leaving the keyboard flow
- Create, complete, uncomplete, delete, and reorder tasks
- Click a task title to open its notes, optional date/time, priority, and subtasks; only the circular checkbox changes completion
- Assign None, Low, Medium, or High priority and see its colored flag directly on the task row
- Add, complete, rename, and delete persistent subtasks with live completion progress
- Show a red **Missed due date** warning on incomplete overdue tasks
- Collapse or expand the Completed section independently; its state is persisted per list
- Choose from eight native completion sounds—including softer Purr, Bottle, Blow, and Ping options—adjust their volume, or disable sound in General settings; subtasks use the selected sound at a softer volume
- Search, select, complete, edit, reorder, and undo tasks from the keyboard
- Drag tasks within and between note windows with an AppKit-powered lifted card that disappears immediately on release, a live placeholder gap, and midpoint-based insertion
- Drag a note only from the empty header area, so task dragging never moves the window
- Double-click the empty note header area to collapse it to its title bar
- Collapse and hide are separate, persisted states
- Choose from ten note colors: Yellow, Orange, Red, Pink, Purple, Indigo, Blue, Teal, Green, and Graphite
- Three per-note modes: Stay on Desktop, Always on Top, and Normal Window
- Normal Window is the default for newly created notes
- Menu bar controls; no main window is required
- Menu bar command center with visible shortcut labels
- Built-in Guide interface for shortcuts, gestures, hide/collapse behavior, and quick actions
- Open Guide from the menu bar, Settings, or any note's ellipsis menu
- Global Quick Add, defaulting to `⌘⇧Space`
- Quick Add can reveal a hidden target note and automatically restores it after adding a task
- Hidden notes remain visible in the menu bar and `⌘⇧H` shows them again
- Direct shortcut recording for every MakeTask action, with persistence, conflict detection, per-action reset, and Reset All
- Versioned local JSON backup with native Export and Import panels; imports add new lists without overwriting existing data
- SwiftData persistence for tasks and note window state
- System, light, and dark appearance with native vibrancy and live 45–100% note-window opacity
- Respects macOS Reduce Motion for note roll-up, task transitions, subtasks, and drag reordering
- Launch at Login through `SMAppService`
- Fully offline; no account, analytics, telemetry, or network entitlement

## Keyboard shortcuts

These are the defaults. Open **Settings → Shortcuts**, click any shortcut badge, and press a new combination to change it. Each action can be reset independently, or the entire map can be restored with **Reset All to Defaults**. MakeTask rejects duplicates and common reserved macOS combinations; the standard Settings (`⌘,`), Quit (`⌘Q`), and text-cancellation (`Escape`) commands remain native and fixed.

| Action | Default |
| --- | --- |
| Global Quick Add | `⌘⇧Space` |
| New task in active note | `⌘N` |
| New list | `⌘⇧N` |
| Hide active note | `⌘W` |
| Collapse/expand active note | `⌘M` |
| Show/hide all notes | `⌘⇧H` |
| Search tasks in active note | `⌘F` |
| Undo last MakeTask action | `⌘Z` |
| Redo last undone action | `⌘⇧Z` |
| Delete active note (with confirmation) | `⌘Delete` |
| Select previous/next task | `↑` / `↓` |
| Complete selected task | `Space` |
| Edit selected task | `Return` |
| Delete selected task | `Delete` |
| Reorder selected task | `⌥↑` / `⌥↓` |
| Move selected task to previous/next list | `⌃⌘←` / `⌃⌘→` |
| Rename current list | `⌘L` |
| Collapse/expand completed tasks | `⌘⇧C` |
| Clear completed tasks (with confirmation) | `⌥⌘Delete` |
| Switch to list 1–9 | `⌘1`…`⌘9` |
| Cancel Quick Add or task entry | `Escape` |
