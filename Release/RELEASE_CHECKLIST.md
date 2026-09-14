# MakeTask 1.0 release handoff

## Latest audit — September 14, 2026

Build 3 adds final-save protection, reliable settings migration and the native Undo/Redo menu fix. Its signed universal package passed bundle, profile and signature checks. 74 unit tests and 13 UI tests passed; one status-icon click test was skipped because the icon is obscured by the display camera housing. Native-panel deletion, recovery and safe quit passed dedicated UI tests. See [RELEASE_READY_REPORT.md](RELEASE_READY_REPORT.md) for the final acceptance result and package. Upload, build-3 TestFlight acceptance and App Review remain pending.

## Prepared in this repository

- Version 1.0.0, build 3, Productivity category, and macOS copyright.
- App Sandbox, hardened runtime, and user-selected file access; no outgoing network entitlement.
- App-only UserDefaults privacy declaration and bundled offline privacy policy.
- Welcome flow for new installations; existing lists, including hidden lists, skip onboarding.
- About screen with version, privacy policy, and support contact.
- App Store description, keywords, review notes, support text, and privacy answers in `APP_STORE.md`.
- Universal archive/export command and a built-bundle verifier.
- Three 2560 × 1600 opaque PNG store screenshots with a repeatable native-view capture command in `Screenshots/`.

## Local verification — September 12, 2026

- All 63 unit tests passed.
- The existing eight UI tests passed; the new welcome/privacy/first-list test passed in a separate targeted run after fixing its accessibility queries and keyboard input fixture.
- The universal unsigned archive command completed successfully, including the bundled metadata, privacy policy, privacy manifest, and architecture checks.
- The verifier correctly rejected that unsigned archive when `--require-distribution` was requested.
- Three screenshot exports passed dimension/alpha checks and visual inspection. The welcome and privacy views were also inspected from UI-test attachments.

Apple Developer membership is confirmed as Individual. On September 13, App Store export succeeded using Xcode's cloud-managed distribution signing and the MakeTask App Store profile. The exported package's installer chain, application signature, architectures, bundled privacy resources, Team ID, app identifier, and profile/certificate match were verified. The user uploaded build 1 through Transporter, completed the export-compliance declaration, and enabled internal TestFlight testing. Basic installed-build checks passed; remaining coverage and findings are detailed in [QA_REPORT.md](QA_REPORT.md). See [SIGNING_STATUS.md](SIGNING_STATUS.md) for the package and signing details.

## Build and inspect

```sh
./scripts/archive-app-store.sh --unsigned
```

This performs local packaging checks without Apple credentials. It is not an App Store-ready signed build.

Once Xcode → Settings → Accounts has the correct Apple Developer account and signing assets:

```sh
./scripts/archive-app-store.sh --team YOUR_TEAM_ID --build 3
```

The script exports locally and never uploads. If Xcode needs a certificate or provisioning profile, configure the correct team in Xcode; do not replace the bundle ID merely to get past signing, because it controls the app's identity and local data container.

When you want Xcode to create or update the selected team's signing assets automatically, add `--allow-provisioning-updates`. This is an explicit opt-in to changes in the Apple Developer account and requires the account to be signed in to Xcode. The default command only uses available signing assets. This option does not upload the app.

To check an App Store-signed app bundle explicitly, run `python3 scripts/verify-release.py /path/to/MakeTask.app --require-distribution`. This additionally requires a valid bundle signature, sandbox entitlements, a distribution authority, and an embedded provisioning profile.

## Before upload

1. Use the published policy/support URLs selected in `APP_STORE.md`; both were checked while signed out.
2. Use the existing MakeTask app record (`6811447937`) with the exact bundle ID. Fill in the account decisions listed in `APP_STORE.md`.
3. Review screenshots for accurate content, legibility, approved Mac dimensions, and no alpha channel.
4. Upload the signed build 3 package identified in `RELEASE_READY_REPORT.md` through Transporter and check Apple's validation results.
5. Review Xcode's generated privacy report and any warnings from Apple. The local verifier is not a replacement for Apple's validation.

## Installed/TestFlight acceptance checks

Run these on the actual signed distribution build with disposable test data. Local automated test results do not establish that these device checks passed.

- Native notes: delete from the header menu and keyboard, cancel/confirm, clear completed, and restore through Undo. Confirm failed-save quit offers Cancel and explicit discard.
- Fresh installation: welcome, privacy policy, first-list creation, closing/reopening through the menu bar.
- Upgrade: previously saved visible and hidden lists retain content and window state.
- Quit/relaunch and macOS restart: list content, positions, collapsed state, and settings persist.
- Launch at Login: enabling and disabling match macOS Login Items behavior.
- Global shortcuts: Quick Add and show/hide work while another app is active; conflicts are visible.
- Backup: export/import through the sandbox file picker to local storage and a user-selected external folder.
- Displays: remove an external monitor, change display resolution, and reopen a collapsed note near an edge.
- Appearance/accessibility: light/dark mode, Reduce Motion, keyboard-only use, and VoiceOver for key controls.
- Compatibility: test macOS 14 and a current stable macOS version; test Apple silicon and Intel if distributing the universal build to both.
- Verify Settings → About shows the version/build that was uploaded.

## Publication

After TestFlight/device checks and Apple validation pass, attach the selected build and screenshots, provide review contact details, choose manual release, and submit for review. Recheck the selected version and price before the final submission. Apple account agreements must be completed by the account holder.

Build 1's Transporter delivery, TestFlight processing/installation and internal testing are confirmed. Build 3 still needs upload and TestFlight acceptance. App Review submission and public release have not been performed.
