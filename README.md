# MakeTask

**Apple Stickies for todos.** MakeTask is a lightweight, local-first macOS menu bar app that keeps independent todo notes on the desktop.

MakeTask is currently an MVP. It is written in Swift and SwiftUI, with a focused AppKit layer for desktop-level windows, window restoration, and Stickies-style roll-up behavior. It has no third-party dependencies.

## MVP features

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
- Choose from eight native completion sounds—including softer Purr, Bottle, Blow, and Ping options—adjust their volume, or disable sound in General settings
- Search, select, complete, edit, reorder, and undo tasks from the keyboard
- Drag tasks within and between note windows with an AppKit-powered lifted card that disappears immediately on release, a live placeholder gap, and midpoint-based insertion
- Drag a note only from the empty header area, so task dragging never moves the window
- Double-click the empty note header area to collapse it to its title bar
- Collapse and hide are separate, persisted states
- Three per-note modes: Stay on Desktop, Always on Top, and Normal Window
- Normal Window is the default for newly created notes
- Menu bar controls; no main window is required
- Menu bar command center with visible shortcut labels
- Built-in Guide interface for shortcuts, gestures, hide/collapse behavior, and quick actions
- Open Guide from the menu bar, Settings, or any note's ellipsis menu
- Global Quick Add, defaulting to `⌘⇧Space`
- Quick Add can reveal a hidden target note and automatically restores it after adding a task
- Hidden notes remain visible in the menu bar and `⌘⇧H` shows them again
- Configurable global Quick Add key and modifiers
- SwiftData persistence for tasks and note window state
- System, light, and dark appearance with native vibrancy and live 45–100% note-window opacity
- Launch at Login through `SMAppService`
- Fully offline; no account, analytics, telemetry, or network entitlement

## Requirements

- macOS 14 Sonoma or newer
- Xcode 16 or newer
- Swift 5 language mode

## Build and run

### One-command launcher

Install the `maketask` command and a local Release app once:

```sh
./scripts/install-maketask.sh
```

The installer copies the launcher to `~/.local/bin`, records the current repository path, builds MakeTask, and installs it at `~/Applications/MakeTask.app`. It does not require `sudo` or a shell alias. After that, MakeTask can be opened from any terminal directory:

```sh
maketask
```

Developer commands:

```sh
maketask --dev              # Build and open the latest Debug app
maketask --dev --no-open    # Build without opening the app
maketask --install-app      # Rebuild/update the local Release app
maketask --help
```

If `/Applications/MakeTask.app` exists, the launcher prefers it over the per-user installation. `MAKETASK_REPO`, `MAKETASK_APP`, and `MAKETASK_APP_DESTINATION` can override the detected paths.

Remove only the command and configuration:

```sh
./scripts/uninstall-maketask.sh
```

Add `--with-app` to also remove `~/Applications/MakeTask.app`.

### Xcode

1. Open `MakeTask.xcodeproj` in Xcode.
2. Select the **MakeTask** scheme and **My Mac** destination.
3. Set a development team or change the bundle identifier if signing requires it.
4. Run with `⌘R`.

Command-line build:

```sh
xcodebuild \
  -project MakeTask.xcodeproj \
  -scheme MakeTask \
  -configuration Debug \
  -derivedDataPath /tmp/MakeTaskDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

For Launch at Login testing, copy a signed build to `/Applications`; `SMAppService.mainApp` is intended for a normally installed application bundle.

## How it works

### SwiftUI

SwiftUI owns note content, task rows, the Quick Add form, the menu bar menu, and Settings. SwiftData queries update each surface without polling.

### AppKit

Each list gets one borderless `NSPanel`, managed by `NoteWindowController`. AppKit is responsible for:

- independent window identity and geometry;
- desktop, floating, and normal window levels;
- cross-Space behavior;
- key-window/focus behavior;
- roll-up frame animation;
- debounced move and resize persistence.

The Quick Add surface is another small borderless panel. It is created on demand and released after dismissal.

### Global shortcut

`GlobalHotKeyService` uses Carbon's `RegisterEventHotKey`. This works across applications without an Accessibility permission prompt or a keyboard event tap. The default registration is Command + Shift + Space. Settings can change the key and modifier combination.

### True roll-up

Collapse never calls `orderOut` and never closes the panel. The expanded height is persisted, while the window's top edge is treated as its anchor. Collapsing animates the bottom edge upward to a 46-point header; expanding reconstructs the previous frame from the saved top edge and expanded height.

Hide is deliberately different: it calls `orderOut`, marks the list hidden, and lets the menu bar show it again. Hidden notes are labeled explicitly in the menu, can be revealed from Quick Add, and `⌘⇧H` toggles all notes globally.

## Data model

`TodoList` stores:

- identity, title, color, and ordering;
- window X position and top edge;
- expanded width and height;
- collapsed and hidden flags;
- window behavior;
- a cascade relationship to its tasks.

`TodoTask` stores:

- identity, title, and ordering;
- completed state and completion date;
- optional notes and due date/time details;
- None, Low, Medium, or High priority;
- a cascade relationship to its subtasks;
- its parent list.

`TodoSubtask` stores its title, completion state and date, ordering, and parent task. Deleting a task or list cascades through its subtasks.

There is no seeded or undeletable list. If every list is deleted, the menu and Quick Add surface display **Create your first list**.

## Project structure

```text
MakeTask/
├── App/                 App entry point and delegate
├── Models/              SwiftData models and value types
├── Persistence/         ModelContainer construction
├── Services/            Preferences, global hotkey, login item
├── Windowing/           NSPanel controllers and coordination
├── Features/
│   ├── MenuBar/
│   ├── Note/
│   ├── QuickAdd/
│   └── Settings/
└── Shared/              Reusable SwiftUI/AppKit bridges
scripts/                 Terminal launcher, installer, and uninstaller
```

More detail is available in [ARCHITECTURE.md](ARCHITECTURE.md).

## Keyboard shortcuts

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

## Privacy

MakeTask makes no network requests and its app target has outgoing network access disabled. Data is stored locally by SwiftData in the app's sandbox container. Preferences are stored in `UserDefaults`.

## Next phases

- Broader shortcut recording
- Optional local export/import
- Automated UI coverage and accessibility refinements
- Optional cloud sync, only as an explicit opt-in feature

## Contributing

Issues and pull requests are welcome. Keep the dependency-free, local-first design unless a proposal demonstrates a clear user benefit that cannot be achieved with Apple frameworks.

## License

MakeTask is available under the MIT License. See [LICENSE](LICENSE).
