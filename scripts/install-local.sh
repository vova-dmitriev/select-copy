#!/bin/bash
set -euo pipefail

task_project_dir="$(cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$task_project_dir"
xcodegen generate
xcodebuild build -quiet -project SelectCopy.xcodeproj -scheme SelectCopy \
    -configuration Release -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$task_project_dir/build/local" CODE_SIGNING_ALLOWED=NO
task_built_app="$task_project_dir/build/local/Build/Products/Release/SelectCopy.app"
bash "$task_project_dir/scripts/sign-local.sh" "$task_built_app"
if [[ -d /Applications/SelectCopy.app ]]; then
    mkdir -p "$task_project_dir/build/previous-installed"
    ditto /Applications/SelectCopy.app "$task_project_dir/build/previous-installed/SelectCopy.app"
fi
pkill -TERM -f '^/Applications/SelectCopy.app/Contents/MacOS/SelectCopy$' || true
ditto "$task_built_app" /Applications/SelectCopy.app
codesign --verify --strict /Applications/SelectCopy.app
touch /Applications/SelectCopy.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f /Applications/SelectCopy.app
open /Applications/SelectCopy.app
