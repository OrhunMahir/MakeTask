# MakeTask signing summary

Verified September 14, 2026. Build **1.0.0 (3)** fixes the release-audit defects and has been exported and checked locally. It has not yet been uploaded. Build **1.0.0 (1)** was previously uploaded by the user through Transporter and tested in App Store Connect record `6811447937`. Neither version has been submitted for App Review. See [RELEASE_READY_REPORT.md](RELEASE_READY_REPORT.md) for the final test results and next steps.

| Item | Verified value |
| --- | --- |
| Membership | Apple Developer Program — Individual |
| Team ID | `9WB6D5BCY2` |
| Bundle ID | `dev.orhun.MakeTask` |
| Application identifier | `9WB6D5BCY2.dev.orhun.MakeTask` |
| Version / build | `1.0.0` / `3` |
| Architectures | Apple silicon (`arm64`) and Intel (`x86_64`) |
| Application signing | Cloud Managed Apple Distribution |
| Installer signing | 3rd Party Mac Developer Installer, issued for team `9WB6D5BCY2` |
| Provisioning profile | Mac Team Store Provisioning Profile: dev.orhun.MakeTask |
| Profile UUID | `aba19456-3cde-460c-9a55-f445c08df5a6` |
| Profile expiration | September 12, 2027, 20:50:34 UTC |
| Installer certificate expiration | September 12, 2027, 20:50:30 UTC |

## Where signing keys are managed

Xcode selected Apple's cloud-managed distribution signing. The export summary identifies the application certificate as Cloud Managed Apple Distribution, and the export log records remote installer signing. No new local distribution private keys were added to this Mac's keychain by this export. The existing local Apple Development identity remains available for development builds.

This differs from the initially proposed local-certificate approach. The finished package uses App Store distribution signatures; its signing keys are managed through Apple's signing service.

## Local artifacts

These paths are relative to the repository root, under ignored `build/`:

- Upload package: `build/AppStore-pklsdh/Export/MakeTask.pkg`
- Xcode export details: `build/AppStore-pklsdh/Export/DistributionSummary.plist`
- Archive: `build/AppStore-pklsdh/MakeTask.xcarchive`
- Inspected exported app: `build/AppStore-pklsdh/VerifiedPayload/dev.orhun.MakeTask.pkg/Payload/MakeTask.app`

The archive contains the original development-signed app; Xcode applied the App Store distribution signature during export. Use the exported package for upload.

Package SHA-256:

```text
c0f9c02ab8e05cfef456a585ee03212466f21304a1fb4bae70cde84c17af5f29
```

## Checks completed

- `xcodebuild -exportArchive -allowProvisioningUpdates` completed with `EXPORT SUCCEEDED`.
- `pkgutil --check-signature` verified the installer signature through Apple Worldwide Developer Relations Certification Authority to Apple Root CA.
- The exported app passed `scripts/verify-release.py --require-distribution`, including strict signature validation for both architectures and sandbox entitlements.
- The embedded profile's Team ID and explicit application identifier match MakeTask. It has no device list or all-devices provision.
- The distribution certificate fingerprint matches a certificate authorized by the profile.
- The bundle contains its icon, copyright, privacy manifest, and offline privacy policy.

## Next steps

Upload build 3, confirm Apple processing and run the replacement TestFlight acceptance checks in [RELEASE_READY_REPORT.md](RELEASE_READY_REPORT.md). Store pricing, review contact details and account-specific declarations still need to be finalized. Working published support/privacy URLs are selected in `APP_STORE.md`. Successful TestFlight delivery does not establish App Review approval.

For future exports using the signed-in Xcode account:

```sh
./scripts/archive-app-store.sh --team 9WB6D5BCY2 --build 3 --allow-provisioning-updates
```

Increment the build number again for subsequent uploads once build 3 has been uploaded. The script exports locally and does not upload or publish the app.
