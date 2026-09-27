# Notification Center widgets

This feature is in development after the App Store 1.0.1 release. It requires a new signed app build with its embedded widget extension; updating the README or the existing App Store app cannot enable it.

## Use

1. Open the new MakeTask build once and create a list if you have none.
2. Open Notification Center by clicking the date/time, choose **Edit Widgets**, search for **MakeTask**, and add a small, medium, or large widget.
3. Edit the widget to choose its list and whether to show completed tasks. Add more widgets for other lists.

Click a task's circle to complete or uncomplete it. Completion also participates in MakeTask's Undo/Redo history. Click **New task** to open Quick Add with the widget's list selected. Click a task title to open its details, or the list title / **more** link to open the full note. Deleting a configured list leaves an explicit unavailable state rather than silently selecting another list.

WidgetKit supports buttons and toggles, but not inline text entry, scrolling lists, or the app's drag-and-drop editor. Those actions open the corresponding MakeTask window. Widget refresh timing is controlled by macOS; the app requests a refresh after successful saves and the provider also requests a periodic refresh.

## Build

The `MakeTask` scheme builds and embeds `MakeTaskWidgets.appex`. Both targets require the same development team. The macOS App Group identifier is `$(DEVELOPMENT_TEAM).dev.orhun.MakeTask.shared`, declared in both entitlements and Info.plists. A team-prefixed macOS App Group does not require registering an iOS-style `group.` identifier.

For a signed local build, pass `DEVELOPMENT_TEAM=YOUR_TEAM_ID` to `xcodebuild`, or select the same team for both targets in Xcode. Unsigned CI builds can verify compilation, packaging, and isolated tests, but cannot validate the widget gallery or shared-container access.

An isolated manual test build can override all three settings:

```sh
xcodebuild -project MakeTask.xcodeproj -scheme MakeTask \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/MakeTaskWidgetPreview \
  DEVELOPMENT_TEAM=YOUR_TEAM_ID \
  MAKETASK_BUNDLE_IDENTIFIER=dev.orhun.MakeTask.WidgetPreview \
  MAKETASK_WIDGET_GROUP=YOUR_TEAM_ID.dev.orhun.MakeTask.widget-preview \
  MAKETASK_URL_SCHEME=maketask-widget-preview build
```

Use this separate bundle, URL scheme, and shared container when testing alongside an installed App Store copy. Do not launch an unsigned development build against the real user's store.

## Data and execution

- The existing SwiftData store stays in the app sandbox. `groupContainer: .none` is explicit so adding the App Group entitlement cannot silently select an empty group database on upgrade.
- The widget reads `widget-snapshot.json` from the shared container. The app writes it atomically after successful saves, skips identical snapshots, and requests a timeline reload. Notes and subtask details are excluded.
- `SetWidgetTaskCompletion` is compiled into both targets. App-only `ForegroundContinuableIntent` conformance routes execution into the app process, with `openAppWhenRun = false`. The extension implementation fails explicitly if incorrectly invoked; it never writes the task database.
- Completion sets a requested Boolean value, making repeated intent delivery idempotent. Save errors revert that completion and do not publish success. Deleted task IDs cannot recreate data.
- `maketask://add/<list UUID>`, `maketask://list/<list UUID>`, and `maketask://task/<task UUID>` open existing app UI. URL routes never mutate or delete tasks directly.
- Unit/UI tests use memory-only stores and temporary snapshot files. They never publish real widget data.

## Validation status

Development checks on September 26, 2026:

- All 85 unit tests passed, including 11 widget integration tests for completion, undo/redo, failed saves, deleted data, snapshots, and URL routing.
- Four targeted UI tests passed: keyboard editing/undo, long-title layout, opening a hidden completed task's details, and adding a task to the widget's selected hidden list.
- Small, medium, and large widget views rendered in a native hosting window. The universal Intel/Apple Silicon Release build passed `scripts/verify-release.py`.
- A separately signed preview app was installed and its widget extension registered. Its bundle, URL scheme, and shared container are separate from the App Store copy.

On September 27, the user tested the separately signed preview in Notification Center and reported successful completion after quitting with Command-Q. Screenshots show gallery discovery, the selected Widget Test list, completed-task display, and a newly added task matching the desktop note. The user reported the other tested actions appeared to work. This verifies the core live preview flow; it is not acceptance of the final App Store-signed package. Deleted-list behavior and upgrade data retention on that package remain installation checks.

Development builds with different bundle identifiers can appear as separate MakeTask entries in the widget gallery. The extra entry observed during this test belonged to the automated UI-test app; it is not a second widget shipped in the production app. Remove obsolete development extension registrations after local tests.

## Apple references

- [Widget extension capabilities and limitations](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- [Interactive widgets](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
- [App Intent execution](https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents)
- [macOS App Group containers](https://developer.apple.com/documentation/xcode/accessing-app-group-containers)
