#!/usr/bin/env python3
"""Check the built macOS bundle before distribution; never uploads anything."""
import argparse
import plistlib
import re
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--require-distribution", action="store_true")
    args = parser.parse_args()
    contents = args.app / "Contents"
    errors = []

    def check(condition, message):
        if not condition:
            errors.append(message)

    info = plistlib.loads((contents / "Info.plist").read_bytes())
    check(info.get("CFBundleIdentifier") == "dev.orhun.MakeTask", "Unexpected bundle identifier")
    check(re.fullmatch(r"\d+\.\d+(?:\.\d+)?", info.get("CFBundleShortVersionString", "")), "Invalid marketing version")
    check(bool(info.get("CFBundleVersion")), "Missing build number")
    check(bool(info.get("NSHumanReadableCopyright")), "Missing macOS copyright")
    check(info.get("LSApplicationCategoryType") == "public.app-category.productivity", "Missing Productivity category")
    check(info.get("LSUIElement") is True, "Menu-bar application flag is missing")
    check(info.get("ITSAppUsesNonExemptEncryption") is False, "Export-compliance declaration is missing or unexpected")
    check(bool(info.get("CFBundleIconFile") or info.get("CFBundleIconName")), "Missing app icon")

    resources = contents / "Resources"
    privacy_path = resources / "PrivacyInfo.xcprivacy"
    check(privacy_path.is_file(), "PrivacyInfo.xcprivacy was not bundled")
    if privacy_path.is_file():
        privacy = plistlib.loads(privacy_path.read_bytes())
        check(privacy.get("NSPrivacyTracking") is False, "Unexpected tracking declaration")
        check(privacy.get("NSPrivacyTrackingDomains") == [], "Unexpected tracking domains")
        check(privacy.get("NSPrivacyCollectedDataTypes") == [], "Unexpected collected data declaration")
        accessed = privacy.get("NSPrivacyAccessedAPITypes", [])
        check(any(item.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryUserDefaults"
                  and "CA92.1" in item.get("NSPrivacyAccessedAPITypeReasons", []) for item in accessed),
              "Missing app-only UserDefaults reason")
    policy = resources / "PrivacyPolicy.md"
    check(policy.is_file() and policy.stat().st_size > 500, "Bundled privacy policy is missing or incomplete")

    executable = contents / "MacOS" / info["CFBundleExecutable"]
    architectures = subprocess.check_output(["lipo", "-archs", str(executable)], text=True).split()
    check({"arm64", "x86_64"}.issubset(architectures), "Release must include Apple silicon and Intel architectures")

    signature = subprocess.run(["codesign", "-dv", "--verbose=4", str(args.app)], capture_output=True, text=True)
    signed_for_distribution = signature.returncode == 0 and any(
        marker in signature.stderr for marker in ("Authority=Apple Distribution:", "Authority=3rd Party Mac Developer Application:")
    )
    # arm64's linker can leave an ad-hoc executable signature even when the
    # enclosing universal app was built with CODE_SIGNING_ALLOWED=NO.
    bundle_is_signed = (contents / "_CodeSignature" / "CodeResources").is_file()
    if bundle_is_signed or args.require_distribution:
        verification = subprocess.run(
            ["codesign", "--verify", "--strict", "--all-architectures", str(args.app)],
            capture_output=True, text=True
        )
        check(verification.returncode == 0, "Bundle signature verification failed: " + verification.stderr.strip())
        entitlement_result = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(args.app)], capture_output=True)
        try:
            entitlements = plistlib.loads(entitlement_result.stdout)
        except plistlib.InvalidFileException:
            entitlements = {}
        check(entitlements.get("com.apple.security.app-sandbox") is True, "App Sandbox entitlement is missing")
        check(entitlements.get("com.apple.security.files.user-selected.read-write") is True, "Selected-file access entitlement is missing")
        check(not entitlements.get("com.apple.security.network.client", False), "Unexpected outgoing network entitlement")
        check(not entitlements.get("com.apple.security.get-task-allow", False), "Release allows debugger attachment")
    if args.require_distribution:
        check(signed_for_distribution, "An App Store distribution signature is required")
        check((contents / "embedded.provisionprofile").is_file(), "App Store provisioning profile is missing")

    print(f"MakeTask {info.get('CFBundleShortVersionString')} ({info.get('CFBundleVersion')}) — {' / '.join(architectures)}")
    print("Signing: App Store distribution" if signed_for_distribution and not errors else "Signing: not yet verified for App Store distribution")
    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        raise SystemExit(1)
    print("Bundle checks passed. Apple upload validation and device testing are separate steps.")


if __name__ == "__main__":
    main()
