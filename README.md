# MakeTask

[![CI](https://github.com/OrhunMahir/MakeTask/actions/workflows/ci.yml/badge.svg)](https://github.com/OrhunMahir/MakeTask/actions/workflows/ci.yml)

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
- First-launch welcome with first-list creation and offline privacy policy
- About screen with version and support access
- Built-in Guide interface for shortcuts, gestures, hide/collapse behavior, and quick actions
- Open Guide from the menu bar, Settings, or any note's ellipsis menu
- Global Quick Add, defaulting to `⌘⇧Space`
- Quick Add can reveal a hidden target note and automatically restores it after adding a task
- Hidden notes remain visible in the menu bar and `⌘⇧H` shows them again
- Direct shortcut recording for every MakeTask action, with persistence, conflict detection, per-action reset, and Reset All
- Versioned local JSON backup with native Export and Import panels; imports add new lists without overwriting existing data
- SwiftData persistence for tasks and note window state
- Recover offscreen notes when displays are disconnected or their usable area changes
- System, light, and dark appearance with native vibrancy and live 45–100% note-window opacity
- Respects macOS Reduce Motion for note roll-up, task transitions, subtasks, and drag reordering
- In-memory XCTest coverage for backup validation, safe import, persistence, ordering, and cascade deletion
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
maketask --test             # Run all unit and UI tests
maketask --unit-test        # Run only the fast unit tests
maketask --ui-test          # Run only the interactive UI tests
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

Notes are fitted entirely within a display's usable area, excluding the Dock and menu bar, when restored, shown, or display parameters change. MakeTask keeps the display with the largest overlap, or uses the nearest remaining display after disconnection, and shrinks oversized notes as needed. Hidden notes stay hidden. Collapsed notes keep their 34-point header and fit their expanded size when reopened; display changes during roll-up are applied and saved after the animation finishes.

### Global shortcut

`GlobalHotKeyService` uses Carbon's `RegisterEventHotKey`. This works across applications without an Accessibility permission prompt or a keyboard event tap. Quick Add and Show/Hide All remain global; every MakeTask action can be recorded directly in Settings. Internal duplicates are rejected immediately, and global registration conflicts are surfaced without replacing the last working shortcut.

### True roll-up

Collapse never calls `orderOut` and never closes the panel. The expanded height is persisted, while the window's top edge is treated as its anchor. Collapsing animates the bottom edge upward to a 34-point header while preserving the expanded width. A separate presentation phase keeps the title in a fixed 34-point layer; the expanded body and 46-point minimum window height return only after expansion finishes. One native animation clock controls the frame, intermediate resize notifications do not write to SwiftData, and rapid toggles queue the latest requested state. Reduce Motion completes the transition synchronously.

When an active note is hidden or deleted, MakeTask chooses the first remaining visible list in list order. Hiding every note clears the active selection. Deleting a list from Quick Add keeps keyboard focus in Quick Add.

Save failures and global shortcut failures appear through a warning icon in the menu bar, note header, and Quick Add. The warning offers retry actions and shortcut settings. Save warnings remain until a save succeeds; retrying shortcuts does not clear them. Global shortcut labels only show successfully registered bindings. No notification permission is needed.


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
├── Services/            Preferences, backup, global hotkey, login item
├── Windowing/           NSPanel controllers and coordination
├── Features/
│   ├── MenuBar/
│   ├── Note/
│   ├── QuickAdd/
│   └── Settings/
└── Shared/              Reusable SwiftUI/AppKit bridges
MakeTaskTests/            Isolated XCTest model and service coverage
MakeTaskUITests/          Critical macOS window and keyboard flows
scripts/                  Terminal launcher, installer, and uninstaller
```

More detail is available in [ARCHITECTURE.md](ARCHITECTURE.md).

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

## Privacy

MakeTask makes no network requests and its app target has outgoing network access disabled. Data is stored locally by SwiftData in the app's sandbox container. Preferences are stored in `UserDefaults`.

Use **Settings → Backup** to export a readable, versioned JSON file. Import validates the file before writing, assigns fresh identifiers, and adds its contents as new lists; it never deletes or overwrites current lists. MakeTask only accesses a backup location explicitly selected in the native macOS file panel. No account or internet connection is involved.

## Tests

Run the complete isolated suite without touching real MakeTask data:

```sh
maketask --test
```

Use `maketask --unit-test` for the fast model/service suite or `maketask --ui-test` for only the interactive macOS coverage. The UI suite briefly opens a dedicated test window; it never reads or writes the real MakeTask store.

The test hosts automatically use an in-memory SwiftData container, isolated preferences, and skip system-wide shortcut registration. Sixty-three unit tests cover JSON round trips, corrupt and forward-version backup rejection, safe additive import, fresh identifiers, duplicate-name handling, window bounds, default-list recovery, cascade deletion, shortcut resolution, and drag reordering within and between lists—including no-op drops, completion state, undo/redo, immediate drag-state cleanup, and persistence. Nine UI tests cover first-launch privacy and list creation, task creation/completion, collapse/expand, hide/reveal recovery, Quick Add, keyboard selection/editing, undo/redo, inline list naming, Quick Add list deletion, task detail keyboard routing, and save-failure feedback without opening Settings. Eight unit tests exercise keyboard routing with real AppKit controls and SwiftUI focus, including remapped window shortcuts, sheets, and returning focus to the note canvas. Five of the unit tests instantiate the real `NoteWindowController` and `FloatingNotePanel`, measure the actual SwiftUI title bounds in screen coordinates, and cover start/mid/end geometry, a real animation clock, rapid toggles, and the nonanimated/Reduce Motion path. Seven tests cover active-note replacement and focus handoff; five cover persistent save failures, shortcut registration failures, and retry/recovery. Eleven tests cover display geometry and recovery, including six with real note panels and simulated display layouts: offscreen restoration, display-change notifications, hidden-note recovery, collapsed expansion, queued animations, and saved bounds. Three tests cover welcome visibility, upgrade behavior with hidden lists, and first-list persistence. The separate UI host is not evidence of native panel animation correctness. The unit target runs serially because native keyboard focus is shared by the macOS session.

GitHub Actions also builds the universal Release app, verifies its bundled privacy resources and metadata, and runs the unit-test suite on every push and pull request. If a check fails, its Xcode result bundle is retained for seven days as a workflow artifact. Interactive UI tests remain local because they require a real macOS window session.

## App Store release

See [the release checklist](Release/RELEASE_CHECKLIST.md) for signing, validation, and device checks, [submission copy](Release/APP_STORE.md) for App Store Connect fields, and [screenshots](Release/Screenshots/README.md) for the three exportable Mac images and their generator.

```sh
./scripts/archive-app-store.sh --unsigned
./scripts/capture-store-screenshots.sh
```

The unsigned command checks the local bundle. Distribution requires the correct Apple Developer team and signing assets, public support/privacy URLs, account details, Apple validation, and installed/TestFlight checks. See the checklist before uploading.

The [privacy policy](MakeTask/Resources/PrivacyPolicy.md) is also bundled and readable offline in **Settings → About** and the welcome window. [Support](Release/SUPPORT.md) explains menu-bar discovery, shortcuts, and backups.

## Next phases

- Complete Apple account signing, TestFlight/device checks, and App Store submission
- Optional cloud sync, only as an explicit opt-in feature

## Contributing

Issues and pull requests are welcome. Keep the dependency-free, local-first design unless a proposal demonstrates a clear user benefit that cannot be achieved with Apple frameworks.

## License

MakeTask is available under the MIT License. See [LICENSE](LICENSE).
