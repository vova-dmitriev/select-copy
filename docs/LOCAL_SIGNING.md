# Persistent local signing

Run `make install-local` to build, sign and update `/Applications/SelectCopy.app`.
This command reuses one local certificate and one certificate-pinned designated
requirement. It never substitutes an ad-hoc signature if signing fails.

The certificate and its private key live outside the repository in a dedicated
keychain under `~/Library/Application Support/SelectCopy/Signing`. Preserve this
directory: deleting or replacing the certificate changes the application's
identity. Only the signing tool is allowed to use the key without prompting.
Setup adds user-domain trust for this certificate's code-signing policy only.
It does not trust the certificate for TLS or change system-wide certificate trust.
The signing keychain is temporarily added to the user's search list for signing;
the original list is restored afterwards.

On the initial transition from an ad-hoc build, macOS requires permission for the
new identity once. Later builds signed with this certificate retain that identity.

To verify update continuity:

```sh
bash scripts/verify-local-updates.sh /Applications/SelectCopy.app
```

The check signs two different versions, verifies they have different code hashes
but identical designated requirements, and confirms an unrelated signer fails
that requirement. It does not automatically grant or edit macOS TCC permissions.

This identity is for this Mac's local development. GitHub distribution needs a
Developer ID Application identity and notarization; do not distribute the local
private key or replace the release identity between versions.
