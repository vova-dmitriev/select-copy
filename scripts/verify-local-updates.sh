#!/bin/bash
set -euo pipefail

task_script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
task_source_app="${1:?Usage: verify-local-updates.sh /absolute/path/SelectCopy.app}"
task_test_dir="$(mktemp -d -t selectcopy-signing-check)"
ditto "$task_source_app" "$task_test_dir/first.app"
bash "$task_script_dir/sign-local.sh" "$task_test_dir/first.app"
task_first_requirement="$(codesign -dr - "$task_test_dir/first.app" 2>&1 | sed -n 's/^designated => //p')"
task_first_hash="$(codesign -dv "$task_test_dir/first.app" 2>&1 | sed -n 's/^CDHash=//p')"
ditto "$task_source_app" "$task_test_dir/second.app"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 9999' "$task_test_dir/second.app/Contents/Info.plist"
bash "$task_script_dir/sign-local.sh" "$task_test_dir/second.app"
task_second_requirement="$(codesign -dr - "$task_test_dir/second.app" 2>&1 | sed -n 's/^designated => //p')"
task_second_hash="$(codesign -dv "$task_test_dir/second.app" 2>&1 | sed -n 's/^CDHash=//p')"
[[ -n "$task_first_requirement" && "$task_first_requirement" = "$task_second_requirement" ]]
[[ "$task_first_hash" != "$task_second_hash" ]]
codesign --verify --strict -R "=$task_first_requirement" "$task_test_dir/second.app"
ditto "$task_source_app" "$task_test_dir/unrelated.app"
codesign --force --sign - "$task_test_dir/unrelated.app"
if codesign --verify --strict -R "=$task_first_requirement" "$task_test_dir/unrelated.app" 2>/dev/null; then
    printf 'ERROR: unrelated signer incorrectly accepted.\n' >&2; exit 1
fi
printf 'PASS: changed version retains identity; unrelated signer rejected.\n'
printf 'Verification copies: %s\n' "$task_test_dir"
