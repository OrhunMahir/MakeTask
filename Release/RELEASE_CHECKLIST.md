# MakeTask 1.0 release handoff

## Prepared in this repository

- Version 1.0.0, build 1, Productivity category, and macOS copyright.
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

No valid code-signing identity was available locally. Apple distribution signing, remote validation, and the installed-build checks below remain pending. These local results do not establish that a newly pushed GitHub Actions run has passed.

## Build and inspect

```sh
./scripts/archive-app-store.sh --unsigned
```

This performs local packaging checks without Apple credentials. It is not an App Store-ready signed build.

Once Xcode → Settings → Accounts has the correct Apple Developer account and signing assets:

```sh
./scripts/archive-app-store.sh --team YOUR_TEAM_ID --build 1
```

The script exports locally and never uploads. If Xcode needs a certificate or provisioning profile, configure the correct team in Xcode; do not replace the bundle ID merely to get past signing, because it controls the app's identity and local data container.

To check an App Store-signed app bundle explicitly, run `python3 scripts/verify-release.py /path/to/MakeTask.app --require-distribution`. This additionally requires a valid bundle signature, sandbox entitlements, a distribution authority, and an embedded provisioning profile.

## Before upload

1. Publish the policy and support documents at the URLs selected for App Store Connect. Check both while signed out.
2. Add the macOS app record with the exact bundle ID. Fill in the account decisions listed in `APP_STORE.md`.
3. Review screenshots for accurate content, legibility, approved Mac dimensions, and no alpha channel.
4. Open the signed archive in Xcode Organizer and run Validate App, then upload to App Store Connect.
5. Review Xcode's generated privacy report and any warnings from Apple. The local verifier is not a replacement for Apple's validation.

## Installed/TestFlight acceptance checks

Run these on the actual signed distribution build with disposable test data. Local automated test results do not establish that these device checks passed.

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

The App Store upload, remote validation, TestFlight installation, review submission, and public release remain unverified until performed in the Apple account.
