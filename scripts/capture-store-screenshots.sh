#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
temporary_test="$repo_dir/MakeTaskTests/StoreScreenshotCaptureTests.swift"
if [[ -e "$temporary_test" ]]; then
    echo "Capture test already exists; inspect it before retrying: $temporary_test" >&2
    exit 1
fi
mkdir -p "$repo_dir/build" "$repo_dir/Release/Screenshots"
output_dir="$(mktemp -d "$repo_dir/build/StoreScreenshots-XXXXXX")"
cp "$repo_dir/Release/Tools/CaptureStoreScreenshots.swift" "$temporary_test"
trap 'rm -f "$temporary_test"' EXIT
echo "Rendering production views with isolated sample data. Log: $output_dir/capture.log"
xcodebuild -project "$repo_dir/MakeTask.xcodeproj" -scheme MakeTask \
    -configuration Debug -derivedDataPath "$output_dir/DerivedData" \
    -only-testing:MakeTaskTests/StoreScreenshotCaptureTests test > "$output_dir/capture.log" 2>&1 || {
    tail -n 60 "$output_dir/capture.log" >&2
    exit 1
}
python3 - "$output_dir/capture.log" "$repo_dir/Release/Screenshots" <<'PY'
from pathlib import Path
import shutil, sys
lines = Path(sys.argv[1]).read_text().splitlines()
paths = [line.split('MAKETASK_STORE_SCREENSHOTS=', 1)[1] for line in lines if line.startswith('MAKETASK_STORE_SCREENSHOTS=')]
if len(paths) != 1:
    raise SystemExit('Capture output path was not found in the test log')
for name in ['01-desktop-notes.png', '02-dark-appearance.png', '03-quick-add.png']:
    shutil.copy2(Path(paths[0]) / name, Path(sys.argv[2]) / name)
print('Screenshots: ' + sys.argv[2])
PY
