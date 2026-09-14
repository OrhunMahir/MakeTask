# MakeTask 1.0.0 (3) — pre-submission report

September 14, 2026. The release candidate includes the final-save protection, reliable settings migration and native-menu history fix. The signed package is prepared locally. It has not been uploaded, submitted for review or published.

## Completed fixes

- Quit retries the persistent save. If it fails or pending changes remain, a native alert defaults to **Cancel**; the user must explicitly choose **Quit Without Saving** to discard unsaved changes. Cancel leaves the app and tasks available for retry. Force Quit and power loss are outside this protection.
- Legacy desktop-window migration uses the injected settings store rather than `UserDefaults.standard`. Fetch/save failures leave the completion marker unset; a later successful attempt marks completion. An already migrated user's chosen desktop mode remains unchanged.
- Native **Note → Undo/Redo Last MakeTask Action** menus now observe history changes. A targeted UI regression confirmed that Undo previously stayed disabled after a real note was deleted; the fix makes it actionable and restores the tasks.
- Note deletion and clear-completed confirmations point to **Undo Last Action** in MakeTask's status menu, which is usable even when deleting the final note closes its window.
- Includes the previous snapshot refresh fix for notes/dates during repeated undo/redo, and rejection of backups above 25 MiB before writing. The backup size limit remains in place.

## Test evidence

**74 unit tests and 13 UI tests passed; one additional UI test was skipped for a verified physical display obstruction.** No application assertion failures remain in the accepted runs.

- Unit suite: all 74 passed in `build/Build3-Acceptance-Tests.xcresult`. That combined attempt is marked Failed because the UI runner could not initialize (`Timed out while enabling automation mode`), not because a unit test failed.
- UI rerun in a separate derived-data directory: `build/Build3-Acceptance-UI.xcresult` — Passed, 13 passed, 0 failed, 1 skipped. Machine summaries: `build/Build3-Acceptance-TestSummary.json` and `build/Build3-Acceptance-UI-Summary.json`.
- Passed native-panel scenarios: header deletion with Cancel/Confirm, keyboard deletion, clear-completed with unaffected pending tasks, native-menu Undo, and failed-save quit cancellation/explicit discard.
- Skipped: clicking the status-menu icon to undo the deletion of the final note. The icon center was inside this Mac's camera-housing area (between the safe top-left/top-right screen regions). Accessibility reported the icon, but physical clicks could not reach it. Verify that specific route with more menu-bar space or on a display without a notch during TestFlight acceptance.

Prior diagnostic results remain under `build/`; early native tests exposed Touch Bar duplicate selectors and the confirmed disabled-Undo defect. The status-menu test first targeted the application menu instead of the status item, then identified the physical display obstruction. The final test detects that obstruction explicitly instead of reporting a false application failure.

Tests use in-memory task data and isolated settings. Native safety tests instantiate the production borderless `FloatingNotePanel`, not `UITestHostView`.

## Signed upload package

- Version/build: **1.0.0 (3)**
- Package: `build/AppStore-pklsdh/Export/MakeTask.pkg`
- Archive: `build/AppStore-pklsdh/MakeTask.xcarchive`
- Inspected payload: `build/AppStore-pklsdh/VerifiedPayload/dev.orhun.MakeTask.pkg/Payload/MakeTask.app`
- SHA-256: `c0f9c02ab8e05cfef456a585ee03212466f21304a1fb4bae70cde84c17af5f29`

Universal arm64/x86_64 archive/export succeeded. Installer trust chain and strict application signatures passed. The profile, distribution certificate, Team ID and application identifier match. Bundle validation confirms sandbox, user-selected file access, no outgoing network/debug entitlement, privacy resources and the export-compliance declaration. The exported binary contains the new quit alert. No application/project input was modified after the archive. Current source/test/script hashes are in `build/AppStore-pklsdh/SourceManifest.json`.

## Next steps and limits

1. Review and commit/push these changes (including new source/test files), then check CI for that exact commit. No commit, push or merge was performed here; keep the user's `Design/` files outside this change.
2. Upload **build 3**, replacing the older local build 2 candidate. Confirm Apple processing and install build 3 through TestFlight. Build 1's previous acceptance does not establish build 3 acceptance.
3. Verify upgrade persistence, ordinary backup export/import, quit/relaunch and menu-bar Undo on the actual TestFlight installation.
4. Complete the account-specific decisions and store fields in `APP_STORE.md`, select build 3 and manual release, then submit to App Review. Review submission and public release are separate steps.

Physical Intel/macOS 14, restart/login, external-display unplugging and spoken VoiceOver checks remain unverified. Automated success does not imply Apple review approval.

The selected public support/privacy permalinks are in `APP_STORE.md`. The build 2 history remains in `QA/BUILD2_REPORT.md`; original data-loss findings remain in `QA_REPORT.md`. Independent-review instructions are in `CLAUDE_REVIEW_HANDOFF.md`.
