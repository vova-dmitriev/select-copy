# SelectCopy

SelectCopy is a small macOS menu-bar utility that copies text immediately after you select it with the mouse. It supports Accessibility API reads with a safe Cmd-C fallback, a configurable confirmation toast, launch-at-login, six toast positions, custom text/icon-only mode, and English/Russian/system language.

## Requirements

- macOS 13 Ventura or newer
- Accessibility permission in System Settings → Privacy & Security → Accessibility
- Xcode 15 or newer (XcodeGen is used to generate the project)

## Build

```sh
brew install xcodegen
xcodegen generate
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS'
```

SelectCopy never keeps a copy history. Clipboard contents are restored when the fallback copy path encounters non-text data or fails.

## License

MIT. See [LICENSE](LICENSE).
