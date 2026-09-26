#!/bin/bash
set -euo pipefail

usage() {
    cat <<'HELP'
Usage: scripts/archive-app-store.sh [--unsigned | --team TEAM_ID] [--build NUMBER]
       [--allow-provisioning-updates]

Creates a universal Release archive in build/. With --team, also exports an
App Store Connect package using the signing assets already configured in Xcode.
--unsigned prepares and checks an archive without Apple account access.
--allow-provisioning-updates lets Xcode create/update signing assets in the
selected Apple Developer account using the account already signed in to Xcode.
This command never uploads or submits the app.
HELP
}

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
team_id="${MAKETASK_TEAM_ID:-}"
unsigned=false
build_number=""
allow_provisioning_updates=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --unsigned) unsigned=true; shift ;;
        --allow-provisioning-updates) allow_provisioning_updates=true; shift ;;
        --team|--build)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            if [[ "$1" == --team ]]; then team_id="$2"; else build_number="$2"; fi
            shift 2 ;;
        *) usage >&2; exit 2 ;;
    esac
done
if [[ "$unsigned" == true && "$allow_provisioning_updates" == true ]]; then
    echo "Provisioning updates require a signed archive; remove --unsigned." >&2
    exit 2
fi
if [[ "$unsigned" == false && ! "$team_id" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "Provide your Apple Developer Team ID with --team, or use --unsigned." >&2
    exit 2
fi
if [[ -n "$build_number" && ! "$build_number" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "Build number must contain one to three numeric components." >&2
    exit 2
fi

mkdir -p "$repo_dir/build"
output_dir="$(mktemp -d "$repo_dir/build/AppStore-XXXXXX")"
archive_path="$output_dir/MakeTask.xcarchive"
arguments=(
    -project "$repo_dir/MakeTask.xcodeproj" -scheme MakeTask -configuration Release
    -destination 'generic/platform=macOS' -derivedDataPath "$output_dir/DerivedData"
    -archivePath "$archive_path" 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO
)
if [[ "$allow_provisioning_updates" == true ]]; then
    arguments+=(-allowProvisioningUpdates)
fi
if [[ -n "$build_number" ]]; then arguments+=("CURRENT_PROJECT_VERSION=$build_number"); fi
if [[ "$unsigned" == true ]]; then
    arguments+=(CODE_SIGNING_ALLOWED=NO)
else
    arguments+=("DEVELOPMENT_TEAM=$team_id" CODE_SIGN_STYLE=Automatic)
fi
echo "Preparing archive. Log: $output_dir/archive.log"
xcodebuild "${arguments[@]}" archive > "$output_dir/archive.log" 2>&1 || {
    tail -n 60 "$output_dir/archive.log" >&2
    exit 1
}
python3 "$repo_dir/scripts/verify-release.py" "$archive_path/Products/Applications/MakeTask.app"
if [[ "$unsigned" == true ]]; then
    echo "Unsigned archive: $archive_path"
    echo "Signing, App Store validation, and TestFlight upload are still required."
    exit 0
fi

python3 - "$output_dir/ExportOptions.plist" "$team_id" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as file:
    plistlib.dump({
        'method': 'app-store-connect', 'destination': 'export',
        'teamID': sys.argv[2], 'signingStyle': 'automatic',
        'manageAppVersionAndBuildNumber': False, 'uploadSymbols': True,
        'generateAppStoreInformation': True
    }, file)
PY
export_arguments=(
    -exportArchive -archivePath "$archive_path"
    -exportOptionsPlist "$output_dir/ExportOptions.plist"
    -exportPath "$output_dir/Export"
)
if [[ "$allow_provisioning_updates" == true ]]; then
    export_arguments+=(-allowProvisioningUpdates)
fi
xcodebuild "${export_arguments[@]}" > "$output_dir/export.log" 2>&1 || {
    tail -n 60 "$output_dir/export.log" >&2
    exit 1
}
echo "App Store package: $output_dir/Export"
echo "Use Xcode Organizer or Transporter to validate and upload it. No upload was performed."
