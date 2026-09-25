# MakeTask Developer Guide

[← Back to MakeTask](../README.md)

[![CI](https://github.com/OrhunMahir/MakeTask/actions/workflows/ci.yml/badge.svg)](https://github.com/OrhunMahir/MakeTask/actions/workflows/ci.yml)

## Requirements

- macOS 14 Sonoma or newer
- Xcode 16 or newer
- Swift 5 language mode

Run the commands below from the repository root.

## Build from source

MakeTask is written in Swift and SwiftUI, with a focused AppKit layer for desktop windows, window restoration, and Stickies-style roll-up behavior. It has no third-party dependencies.

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

### Global shortcut

`GlobalHotKeyService` uses Carbon's `RegisterEventHotKey`. This works across applications without an Accessibility permission prompt or a keyboard event tap. Quick Add and Show/Hide All remain global; every MakeTask action can be recorded directly in Settings. Internal duplicates are rejected immediately, and global registration conflicts are surfaced without replacing the last working shortcut.

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

More detail is available in [ARCHITECTURE.md](../ARCHITECTURE.md).

## Tests

Run the complete isolated suite without touching real MakeTask data:

```sh
maketask --test
```

Use `maketask --unit-test` for the fast model/service suite or `maketask --ui-test` for only the interactive macOS coverage. The UI suite briefly opens a dedicated test window; it never reads or writes the real MakeTask store.

The test hosts automatically use an in-memory SwiftData container, isolated preferences, and skip system-wide shortcut registration. Unit tests cover JSON round trips, corrupt and forward-version backup rejection, safe additive import, fresh identifiers, duplicate-name handling, window bounds, default-list recovery, cascade deletion, shortcut resolution, and drag reordering within and between lists—including no-op drops, completion state, undo/redo, immediate drag-state cleanup, and persistence. UI tests cover task creation/completion, collapse/expand, hide/reveal recovery, Quick Add, keyboard selection/editing, undo/redo, and inline list naming.

GitHub Actions also builds the Release app and runs the unit-test suite on every push and pull request. If a check fails, its Xcode result bundle is retained for seven days as a workflow artifact. Interactive UI tests remain local because they require a real macOS window session.

## Contributing

Issues and pull requests are welcome. Keep the dependency-free, local-first design unless a proposal demonstrates a clear user benefit that cannot be achieved with Apple frameworks.
