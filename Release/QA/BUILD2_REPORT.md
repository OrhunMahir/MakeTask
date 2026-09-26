# MakeTask 1.0.0 (2) — pre-submission report

September 13, 2026. **The identified code defects are fixed and the replacement App Store package is ready for upload.** Build 2 has not yet been uploaded, tested through TestFlight, or submitted for review.

## Final recheck — September 14, 2026

**69 unit tests passed again, including all six data-safety regressions. Final UI verification remains open.** The full run and a UI-only retry both failed before UI test cases started: `The test runner failed to initialize for UI testing. (Underlying Error: Timed out while enabling automation mode.)`. This is a runner initialization failure, not a failing application assertion; its underlying cause has not been established. The earlier 78-test success below remains historical evidence, not the result of this latest run.

- Results: `build/FinalVerification-Tests.xcresult`, `build/FinalVerification-TestSummary.json`, and `build/FinalVerification-UI-Retry.xcresult`.
- Distribution bundle verification and installer certificate-chain verification passed again; the package SHA-256 is unchanged. No application/project input has a modification time later than the archive executable. Current source/test/script hashes are recorded in `build/FinalVerification-SourceManifest.json` for later comparisons.
- All three screenshots remain 2560 × 1600, RGB PNGs without an alpha channel. Project plist lint, archive-script syntax and `git diff --check` passed.
- No additional application defect was identified in this recheck. Corrected stale build-1 wording and completed setup steps in `RELEASE_CHECKLIST.md`; application code and the signed package were not changed.
- Independent review handoff: `CLAUDE_REVIEW_HANDOFF.md`. Give the reviewer this working copy, including untracked tests, rather than only the older GitHub commit.
- Before public release, complete a successful UI rerun and the actual build-2 TestFlight acceptance checks. No upload, submission, commit or push was performed during this recheck.

## Fixes completed

- Undo/redo now snapshots the current data immediately before deleting it. Task notes and due dates survive repeated history operations; the same protection covers list contents/window state, subtasks and clearing completed tasks.
- An export larger than the importer's 25 MiB limit now reports an error before writing. An existing backup at the destination remains untouched. The size limit remains in place.
- Quick Add's deletion confirmation now directs users to the working **Undo Last Action** menu command.
- Build number incremented to **2**. The app includes `ITSAppUsesNonExemptEncryption = false`, checked by the release verifier, matching the app's current lack of non-exempt encryption. [Apple guidance](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption)
- Replaced the submission copy's unavailable `main` policy/support links with published commit permalinks. Both returned **HTTP 200 without authentication** and their contents matched the current local documents byte for byte.

## Validation

- **78 tests passed; 0 failed; 0 skipped:** 69 unit tests (including six data-safety regressions) and nine UI tests.
- Test result: `build/ReleaseFixes-Tests.xcresult`; machine-readable summary: `build/ReleaseFixes-TestSummary.json`.
- Universal Release archive and App Store export succeeded with the approved team and cloud-managed Apple Distribution signing.
- Exported payload passes `scripts/verify-release.py --require-distribution`: version/resources, arm64/x86_64, export-compliance flag, sandbox, no outgoing network/debug entitlements and strict signature verification.
- Installer certificate chain, application/team identifier and provisioning-profile match verified. Package SHA-256:

```text
b01290d7056f9c06002410b8826a7d2f50e6f4f1d3e63b6c178b7b019dce654e
```

Upload **this replacement package**, not the earlier build 1:

```text
build/AppStore-SzBdNA/Export/MakeTask.pkg
```

Tests ran on Apple silicon/macOS 26.5.2 with Xcode 26.1. Physical Intel/macOS 14, OS reboot/login, external-display unplugging and a spoken VoiceOver session remain unverified. Automated UI tests use isolated data. Build 1's earlier TestFlight smoke checks do not establish acceptance of build 2.

## Verified store links

- [Privacy policy](https://github.com/OrhunMahir/MakeTask/blob/0dd1ca47df9c07044394733d9534ae0fcd91362d/MakeTask/Resources/PrivacyPolicy.md)
- [Support](https://github.com/OrhunMahir/MakeTask/blob/0dd1ca47df9c07044394733d9534ae0fcd91362d/Release/SUPPORT.md)

These URLs serve the unchanged current policy/support text. If either document changes, update the selected URL. The previous `main` URLs are still unsuitable until the relevant commits are merged.

## Remaining publication steps

1. Commit/push the reviewed fixes and confirm the new CI run. Current public CI evidence belongs to the older commit; this task did not commit or push.
2. Upload the build 2 package through Transporter, confirm Apple processing succeeds, add it to the existing internal TestFlight group and verify upgrade, task details after undo/redo, ordinary backup export/import, and relaunch.
3. In App Store Connect, complete the **1.0.0** version metadata using `APP_STORE.md`, upload the prepared screenshots and select **1.0.0 (2)**. Required metadata includes valid support/privacy links and review contact information. [Apple review checklist](https://developer.apple.com/app-store/review/)
4. Choose free/paid price and territories. The account holder must supply accurate review contact information, any required agreement/tax/banking details and the applicable trader declaration. Individual enrollment does not itself mean non-trader. [Apple DSA guidance](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)
5. Complete current privacy and age-rating questions. Do not claim accessibility features that have not been evaluated. [Apple submission requirements](https://developer.apple.com/app-store/submitting/)
6. Choose **Manually release this version**, then submit the completed version for App Review. Once approved, use the separate release action. [Apple release options](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option)

No public release or Apple review approval is implied by passing local checks. The earlier failures remain documented in `QA_REPORT.md` as historical evidence; their regressions are now included in the normal test target and pass.
