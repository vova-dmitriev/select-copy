#!/bin/bash
set -euo pipefail

task_script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
task_app="${1:?Usage: sign-local.sh /absolute/path/SelectCopy.app}"
[[ "$task_app" = /* && -d "$task_app" ]] || { printf 'App must be an existing absolute path.\n' >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$task_app/Contents/Info.plist")" = com.selectcopy.app ]] || {
    printf 'Refusing to sign a different application.\n' >&2; exit 1
}
bash "$task_script_dir/setup-local-signing.sh"
task_signing_dir="${SELECTCOPY_SIGNING_DIR:-$HOME/Library/Application Support/SelectCopy/Signing}"
task_keychain="$task_signing_dir/selectcopy-signing.keychain-db"
task_signing_password="$(< "$task_signing_dir/keychain-password")"
/usr/bin/security unlock-keychain -p "$task_signing_password" "$task_keychain"
task_original_keychains=()
while IFS= read -r task_existing_keychain; do
    task_original_keychains+=("$task_existing_keychain")
done < <(/usr/bin/security list-keychains -d user | sed 's/^[[:space:]]*"//; s/"[[:space:]]*$//')
trap '/usr/bin/security list-keychains -d user -s "${task_original_keychains[@]}"' EXIT
/usr/bin/security list-keychains -d user -s "${task_original_keychains[@]}" "$task_keychain"
task_fingerprint="$(/usr/bin/openssl x509 -in "$task_signing_dir/certificate.pem" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"
task_requirement="identifier \"com.selectcopy.app\" and certificate leaf = H\"$task_fingerprint\""
/usr/bin/codesign --force --sign 'SelectCopy Local Development' --keychain "$task_keychain" \
    --timestamp=none --options runtime --requirements "=designated => $task_requirement" "$task_app"
/usr/bin/codesign --verify --strict -R "=$task_requirement" "$task_app"
