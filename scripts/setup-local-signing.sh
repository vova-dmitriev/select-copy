#!/bin/bash
set -euo pipefail
umask 077

task_script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
task_signing_dir="${SELECTCOPY_SIGNING_DIR:-$HOME/Library/Application Support/SelectCopy/Signing}"
task_keychain="$task_signing_dir/selectcopy-signing.keychain-db"
task_password_file="$task_signing_dir/keychain-password"
task_certificate="$task_signing_dir/certificate.pem"

ensure_trusted_identity() {
    task_certificate_fingerprint="$(/usr/bin/openssl x509 -in "$task_certificate" -noout -fingerprint -sha1 | sed 's/.*=//; s/://g')"
    if ! /usr/bin/security find-identity -v -p codesigning "$task_keychain" | /usr/bin/grep -Fq "$task_certificate_fingerprint"; then
        /usr/bin/security add-trusted-cert -r trustRoot -p codeSign -k "$task_keychain" "$task_certificate"
    fi
}

if [[ -f "$task_keychain" ]]; then
    [[ -f "$task_password_file" && -f "$task_certificate" ]] || {
        printf 'Signing state is incomplete; refusing to replace the existing identity.\n' >&2
        exit 1
    }
    ensure_trusted_identity
    exit 0
fi

mkdir -p "$task_signing_dir"
chmod 700 "$task_signing_dir"
if [[ -f "$task_certificate" && -f "$task_password_file" && -f "$task_signing_dir/private-key.pem" ]]; then
    printf 'Resuming setup with the existing certificate.\n'
elif [[ -e "$task_certificate" || -e "$task_password_file" ]]; then
    printf 'Partial signing setup exists; refusing to regenerate the identity.\n' >&2
    exit 1
else
/usr/bin/openssl rand -hex -out "$task_password_file" 32
/usr/bin/openssl req -new -x509 -newkey rsa:3072 -sha256 -days 3650 \
    -config "$task_script_dir/local-signing.cnf" \
    -keyout "$task_signing_dir/private-key.pem" \
    -out "$task_certificate" -passout "file:$task_password_file" 2>/dev/null
fi
task_signing_password="$(< "$task_password_file")"
SELECTCOPY_PKCS12_PASSWORD="$task_signing_password" /usr/bin/openssl pkcs12 -export \
    -inkey "$task_signing_dir/private-key.pem" -in "$task_certificate" \
    -name 'SelectCopy Local Development' -out "$task_signing_dir/identity.p12" \
    -passin "file:$task_password_file" -passout env:SELECTCOPY_PKCS12_PASSWORD
/usr/bin/security create-keychain -p "$task_signing_password" "$task_keychain"
/usr/bin/security unlock-keychain -p "$task_signing_password" "$task_keychain"
/usr/bin/security import "$task_signing_dir/identity.p12" -k "$task_keychain" \
    -P "$task_signing_password" -T /usr/bin/codesign
/usr/bin/security set-key-partition-list -S apple-tool:,codesign: -s \
    -k "$task_signing_password" "$task_keychain" >/dev/null
rm -f -- "$task_signing_dir/private-key.pem" "$task_signing_dir/identity.p12"
ensure_trusted_identity
printf 'Created persistent SelectCopy signing identity.\n'
