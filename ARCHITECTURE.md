# MakeTask Architecture

## Design goals

MakeTask has no conventional document or main window. The application lifecycle is anchored by a menu bar extra, while user-created lists own their own small windows. The architecture keeps SwiftUI responsible for declarative content and restricts AppKit to behaviors SwiftUI's scene APIs do not model well.

## Application lifecycle

`MakeTaskApp` defines two scenes:

1. `MenuBarExtra` is the always-available control surface.
2. `Settings` creates a standard preferences window only when requested.

Settings includes General, Appearance, Shortcuts, and Guide tabs. The Guide is an in-app reference and quick-action surface; the menu bar can open it directly without introducing a permanent main window.

`MakeTaskAppDelegate` creates the shared SwiftData container, preferences, login-item service, and `WindowCoordinator`. On launch, the coordinator registers the global shortcut and restores each non-hidden list window.

The generated Info.plist sets `LSUIElement` so MakeTask does not require a Dock icon or a normal main window.

## State ownership

### SwiftData

SwiftData is the source of truth for durable product state:

```text
TodoList 1 ──────── * TodoTask
```

Deleting a list cascades to its tasks. There is intentionally no singleton Inbox, special-list identifier, or seed migration.

Window geometry lives with `TodoList` because each list maps one-to-one to a note window. The persisted geometry is `(x, top, expandedWidth, expandedHeight)`. Using `top` instead of AppKit's lower-left `y` keeps the visual header anchor stable across collapse and expand transitions.

Task ordering uses a persisted `Double`. Current operations normalize the affected list to contiguous values after drag and drop, avoiding gaps or unbounded fractional insertions.

### UserDefaults

`AppSettings` owns lightweight preferences:

- appearance and note opacity;
- completed-task visibility;
- default and last-used Quick Add lists;
- global shortcut key and modifiers.

### Ephemeral state

`WindowCoordinator` owns the live mapping from list UUID to `NoteWindowController`, the active list, focus requests, the current Quick Add controller, and the registered global hotkey.

## Window architecture

### Floating notes

`FloatingNotePanel` is an `NSPanel` subclass that can become key but not main. It has a borderless, resizable style and an `NSHostingView` containing `NoteView`.

Traffic-light controls are absent because the panel is borderless. The SwiftUI header exposes a compact ellipsis menu for rename, color, window level, collapse, hide, and delete actions. A small AppKit drag-area bridge confines window movement and the double-click roll-up gesture to otherwise empty header space; the task body never moves the panel.

Window modes map to AppKit as follows:

New notes default to Normal Window. Stay on Desktop and Always on Top are explicit per-note choices.

| MakeTask mode | NSWindow level | Collection behavior |
| --- | --- | --- |
| Stay on Desktop | Just above desktop icons, below normal apps | All Spaces, stationary, excluded from window cycle |
| Always on Top | Floating | All Spaces, full-screen auxiliary |
| Normal Window | Normal | Move to active Space |

Move and resize delegate events update the in-memory model immediately. Saves are debounced by 250 milliseconds, with a final synchronous model save when live resize ends. There is no timer or polling loop.

### Collapse and expand

The header double-click calls `WindowCoordinator.toggleCollapse`, which delegates to the owning `NoteWindowController`.

Collapse sequence:

1. Preserve current expanded width and height.
2. Set the durable `isCollapsed` flag.
3. Remove resize behavior while rolled up.
4. Keep `frame.maxY` fixed.
5. Animate the frame to the 46-point header height.

Expand performs the inverse and restores the last expanded height. The panel instance, SwiftUI hierarchy, and list identity remain alive during both transitions.

### Hide and show

Hide sets `isHidden`, calls `orderOut`, and keeps the list in SwiftData. Show clears the flag and reuses or recreates the panel controller. This path never modifies `isCollapsed`, so a hidden collapsed note returns still collapsed. The menu labels each list as visible or hidden, Quick Add offers a reveal action for its selected list, and a global visibility shortcut provides a recovery path even when every note is hidden.

### Quick Add

Quick Add is a short-lived borderless floating panel centered on the screen containing the mouse. It activates MakeTask, focuses the title field, uses the last Quick Capture list when possible, and supports Enter and Escape without a mouse. Its list picker can switch to an inline named-list form; when no lists exist, that form is the default state.

## Global shortcut

`GlobalHotKeyService` installs a Carbon application event handler and filters events by `EventHotKeyID`, allowing independent Quick Add and note-visibility registrations. Carbon hotkeys are native, efficient, global, and do not require an accessibility event tap. A local AppKit key monitor handles note-scoped commands such as hide and collapse when a note panel is active. Registration failures are surfaced by `WindowCoordinator.errorMessage` rather than silently ignored.

## Performance characteristics

- No polling, telemetry, network requests, or background sync.
- No third-party frameworks.
- Windows are created only for visible lists.
- Quick Add is released when dismissed.
- SwiftData and SwiftUI observation drive changes.
- Window persistence is event-driven and debounced.

## Extension points

The unused `notes`, `dueDate`, and `priority` fields in `TodoTask` let the next UI phase ship without a destructive schema redesign. Task editor, completion policy, and optional sync features should be added as focused feature modules rather than expanding `WindowCoordinator` into presentation logic.
