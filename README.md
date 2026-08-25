# MakeTask

**Apple Stickies for todos.** MakeTask is a lightweight, local-first macOS menu bar app that keeps independent todo notes on the desktop.

MakeTask is currently an MVP. It is written in Swift and SwiftUI, with a focused AppKit layer for desktop-level windows, window restoration, and Stickies-style roll-up behavior. It has no third-party dependencies.

## MVP features

- Multiple independent floating todo notes
- No forced Inbox or other system list
- Create, rename, hide, show, and delete lists
- Create, complete, uncomplete, delete, and reorder tasks
- Drag tasks between note windows
- Double-click a note header to collapse it to its title bar
- Collapse and hide are separate, persisted states
- Three per-note modes: Stay on Desktop, Always on Top, and Normal Window
- Menu bar controls; no main window is required
- Global Quick Add, defaulting to `⌘⇧Space`
- Configurable global Quick Add key and modifiers
- SwiftData persistence for tasks and note window state
- System, light, and dark appearance with native vibrancy
- Launch at Login through `SMAppService`
- Fully offline; no account, analytics, telemetry, or network entitlement

## Requirements

- macOS 14 Sonoma or newer
- Xcode 16 or newer
- Swift 5 language mode

## Build and run

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

Hide is deliberately different: it calls `orderOut`, marks the list hidden, and lets the menu bar show it again.

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
- notes, due date, and priority fields reserved for the next UI phase;
- its parent list.

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
| Cancel Quick Add or task entry | `Escape` |

## Privacy

MakeTask makes no network requests and its app target has outgoing network access disabled. Data is stored locally by SwiftData in the app's sandbox container. Preferences are stored in `UserDefaults`.

## Next phases

- Task title and notes editor
- Due dates, priorities, and subtasks
- Configurable completed-task delay
- Broader shortcut recording
- Optional local export/import
- Automated UI coverage and accessibility refinements
- Optional cloud sync, only as an explicit opt-in feature

## Contributing

Issues and pull requests are welcome. Keep the dependency-free, local-first design unless a proposal demonstrates a clear user benefit that cannot be achieved with Apple frameworks.

## License

MakeTask is available under the MIT License. See [LICENSE](LICENSE).
