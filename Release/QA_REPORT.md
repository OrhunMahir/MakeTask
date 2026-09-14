# MakeTask final release audit — September 13, 2026

> Current release candidate: build 3 (September 14). The historical defects below and the subsequent quit/migration/native-menu issues are fixed. Use [RELEASE_READY_REPORT.md](RELEASE_READY_REPORT.md) for the latest test evidence and upload package.

**Update:** The findings below concern build 1. They have now been fixed in build 2; all 78 current tests pass and a signed replacement package is prepared. See [RELEASE_READY_REPORT.md](RELEASE_READY_REPORT.md) for current status and remaining submission steps. The original findings are retained as evidence.

**Decision: hold release of build 1 until the data-safety findings below are resolved.** The existing automated suite passes, but supplemental regression tests reproduce two defects. This audit did not change application code, upload another build, submit to App Review, or publish the app.

## Tested version and environment

- Source: `0dd1ca4`, with the existing uncommitted signing-script/documentation changes. No application-source differences in the disposable regression copy.
- Installed application: `/Applications/MakeTask.app`, TestFlight **1.0.0 (1)**, bundle `dev.orhun.MakeTask`, team `9WB6D5BCY2`.
- Host: Apple silicon, macOS **26.5.2 (25F84)**; automated tests built with Xcode **26.1 (17B55)**.
- App Store Connect application record: **6811447937**. User-provided screens confirm successful Transporter delivery, completion of the encryption declaration, and build 1 in the internal group with status **Testing**.

## Results

| Check | Result | Evidence / scope |
| --- | --- | --- |
| Existing unit suite | PASS — 63 tests | `build/FinalQA-AllTests.xcresult`; includes persistence, backup validation/import rollback, ordering, keyboard routing, real panel geometry, display recovery, welcome and error handling. |
| Existing UI suite | PASS — 9 tests | `build/FinalQA-UISigned.xcresult`; welcome/privacy/first-list, task creation/completion, Quick Add, hide/reveal, collapse/expand, editing/undo/redo, deletion confirmation, keyboard routing and save-error feedback. |
| Supplemental data-safety regressions | FAIL — 3 tests, 5 assertions | Two undo/redo scenarios and one large-backup round trip; isolated in-memory data and temporary files. See `QA/regression-failures.txt` and `QA/ReleaseDataSafetyRegressionTests.swift.txt`. |
| Installed TestFlight signature | PASS | Strict codesign verification for all architectures, correct team and app identifier; Apple TestFlight Beta Distribution signature. |
| Exported package and profile | PASS | Installer certificate chain, SHA-256, App Store application signature, matching profile/team/app identifier. Export payload passes `verify-release.py --require-distribution`. |
| Package resources | PASS | Universal arm64/x86_64, macOS 14 minimum, sandbox/user-selected file access, no networking/debug entitlement, icon, copyright, privacy manifest and offline policy. |
| Store screenshots | PASS | Three 2560 × 1600 opaque PNGs, visually rechecked for legibility, clipping and private data. |
| Public policy/support URLs | FAIL | Both proposed `main` URLs return HTTP 404 when signed out. Documents are present on the feature branch. |
| Latest feature CI | PASS | `0dd1ca4`, run [34713577465](https://github.com/OrhunMahir/MakeTask/actions/runs/34713577465): Release build, bundle resources and unit tests. |

The first combined test run passed the unit suite, but the unsigned UI runner was killed before bootstrap. A retry against the same output directory encountered a linker output-write error. The clean, locally signed UI test run then completed all nine tests successfully. These runner failures are distinct from the application regression failures below.

The installed TestFlight app is re-signed by Apple and does not carry the original embedded provisioning profile. The verifier's `--require-distribution` authority/profile rules apply to the exported App Store payload; applying that flag to the installed TestFlight copy would produce a misleading failure. The installed copy passed normal resource checks and direct signature/entitlement checks.

## Release findings

### 1. Undo/redo loses task notes and due dates

Reproduced by two supplemental tests against unchanged application source:

1. Add a task, enter notes and a due date, invoke application Undo, then Redo. The restored task has empty notes and no due date.
2. Delete an existing task, Undo, edit its notes/date, Redo deletion, then Undo again. The task returns with its old notes and no new date.

`WindowCoordinator.addTask` (line 521) and `deleteTask` (line 563) capture a fixed snapshot. Notes and due-date edits save data without updating that snapshot or invalidating the old redo operation. Refreshing the snapshot immediately before history-driven deletion is the minimum data-preserving correction; list and bulk-deletion history should be assessed consistently. Changes need regression tests and a new build before release.

### 2. A successfully exported large backup cannot be imported

The supplemental test created 27 valid tasks with 1,000,000 ASCII characters in each task's notes. Encoding succeeded with **27,008,943 bytes**; decoding the same file failed with `fileTooLarge`.

`LocalBackupService.encode` does not enforce the **25 MiB** importer limit. It must not report a successful usable backup when its own importer will reject the file. At minimum, reject an oversized encoded backup before writing it, with an explicit error. The existing ordinary-sized round-trip and malformed-file tests pass.

### 3. Privacy and support links are not yet public on main

- [Proposed privacy URL](https://github.com/OrhunMahir/MakeTask/blob/main/MakeTask/Resources/PrivacyPolicy.md): HTTP 404.
- [Proposed support URL](https://github.com/OrhunMahir/MakeTask/blob/main/Release/SUPPORT.md): HTTP 404.

The remote feature branch points to `0dd1ca4`; `main` points to `8cfcfdc`. Publish the documents at the selected stable URLs, then verify them while signed out before submission.

### Additional source-review finding

Quick Add's delete confirmation says to press Command-Z immediately to undo (`QuickAddView.swift`, line 140), while `handleLocalKeyEvent` returns early for that window (`WindowCoordinator.swift`, lines 1219–1225). The menu's application Undo remains a recovery route. This is a source-review finding; it was not reproduced interactively during this audit.

## Installed-build coverage and limits

Earlier in this same release session, the actual TestFlight build passed creation of a disposable list and three tasks, editing, completion, mouse drag reordering, collapse/expand, full quit and relaunch from TestFlight, and preservation of edited content, completion and ordering. The disposable list was deleted afterward. The user also confirmed their existing tasks survived the TestFlight upgrade.

During this expanded audit the native control tool timed out repeatedly when reading the installed MakeTask UI. A process sample showed the app running in its event loop, with no new MakeTask crash report found. Therefore additional production-UI backup import/export, global shortcut, appearance and login-item checks are **not recorded as passed**. The regression defects above are confirmed by automated execution, not inferred from this tool timeout.

Physical Intel/macOS 14 execution, OS reboot/login, real external-monitor disconnect/resolution changes, and an actual VoiceOver session were not performed. Universal packaging and simulated geometry tests do not replace those device checks. No claim of exhaustive testing or Apple review approval is made.

## Remaining before submission

1. Resolve the confirmed data-safety defects, rerun the regressions and existing suites, increment the build number, and verify the replacement build in TestFlight.
2. Publish working support/privacy pages.
3. Complete App Store metadata, pricing/territories, privacy/age-rating answers and real review contact information; verify applicable account agreements and business information.
4. Review the outstanding installed-device checks above, attach the final build and screenshots, and choose manual release before submitting to App Review.

The supplemental regression tests were run in `/private/tmp/MakeTask-core-regression-tbnswf0i`, with results in `RegressionResults.xcresult`. Their archived `.swift.txt` source is evidence, outside the application's test target. Existing project tests and application code were left unchanged.
