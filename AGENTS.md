# SelectCopy development

- Install and update the local app only with `make install-local`.
- Do not install ad-hoc or unsigned Xcode build products into `/Applications`.
- Preserve the existing signing identity in `~/Library/Application Support/SelectCopy/Signing`.
- Never regenerate that certificate for an app update or commit/export its private key or password.
- Keep `com.selectcopy.app`, the installation path and the certificate-pinned designated requirement stable.
- Use a consistent Developer ID Application identity for public releases; the local certificate is not a distribution identity.
- Follow `docs/LOCAL_SIGNING.md` and verify signing changes with `scripts/verify-local-updates.sh`.
