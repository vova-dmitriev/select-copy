# SelectCopy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Создать open-source macOS menu bar utility, которая автоматически копирует явно выделенный текст, безопасно использует `Command+C` как fallback и показывает настраиваемый toast.

**Architecture:** Глобальный listen-only event tap преобразует низкоуровневые события в `SelectionGesture`; coordinator после debounce сначала читает `AXSelectedText`, затем при строго разрешённых условиях запускает clipboard-transaction с синтетическим `Command+C`. UI построен на SwiftUI, а нативные окна, pasteboard, toast panel, Accessibility и login item изолированы за небольшими протоколами для тестирования.

**Tech Stack:** Swift 6, SwiftUI, AppKit, ApplicationServices, CoreGraphics, ServiceManagement, XCTest, XcodeGen, SwiftFormat, SwiftLint, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-11-select-copy-design.md`

## Global Constraints

- Минимальная версия — macOS 13 Ventura.
- Release build — Universal Binary `arm64` + `x86_64`.
- App Sandbox отключён; Hardened Runtime включён.
- `LSUIElement = true`; приложение не появляется в Dock или application switcher.
- Runtime не содержит сторонних зависимостей и не выполняет сетевых запросов.
- Текст выделения и clipboard payload никогда не сохраняются и не логируются.
- Secure text fields, lock screen, обычный одиночный click и собственные синтетические события игнорируются.
- Основной путь — прямое чтение `AXSelectedText`; `Command+C` используется только как контролируемый fallback для текстоподобной роли.
- Toast по умолчанию включён, расположен top trailing и скрывается через 1,2 секунды.
- Языки первой версии — system, Russian и English; смена применяется без перезапуска.
- Не добавлять clipboard history, per-app rules, Sparkle, Mac App Store или нетекстовое копирование.
- Bundle identifier — `com.selectcopy.app`.
- Все изменения выполняются через TDD: failing test, подтверждённый failure, минимальная реализация, passing test.

---

## File Structure

```text
select-copy/
├── .github/workflows/
│   ├── ci.yml                         # Build, lint and tests for pull requests
│   └── release.yml                    # Signed, notarized GitHub releases
├── Config/
│   ├── Debug.xcconfig                 # Debug signing and build settings
│   └── Release.xcconfig               # Hardened release settings
├── Scripts/
│   ├── generate-icons.swift           # Deterministic PNG icon generation
│   ├── package-release.sh             # ZIP, DMG and SHA-256 artifacts
│   └── verify-release.sh              # codesign, spctl and stapler checks
├── SelectCopy/
│   ├── App/
│   │   ├── SelectCopyApp.swift        # SwiftUI entry point and MenuBarExtra
│   │   ├── AppContainer.swift         # Dependency composition and lifecycle
│   │   └── AppDelegate.swift          # Application launch and termination hooks
│   ├── Accessibility/
│   │   ├── AccessibilityClient.swift  # AX protocol, role model and live adapter
│   │   └── PermissionCoordinator.swift# Trust state and System Settings navigation
│   ├── Clipboard/
│   │   ├── PasteboardClient.swift     # NSPasteboard snapshot/read/write adapter
│   │   └── CopyFallbackService.swift  # Tagged Command+C transaction
│   ├── Coordinator/
│   │   └── SelectionCopyCoordinator.swift # Debounced AX/fallback workflow
│   ├── Localization/
│   │   ├── AppLanguage.swift          # system/ru/en resolution
│   │   ├── Localizer.swift            # Runtime string resolution
│   │   └── Localizable.xcstrings      # Russian and English strings
│   ├── MenuBar/
│   │   └── MenuBarContentView.swift   # Status, settings, test toast and quit
│   ├── Monitoring/
│   │   ├── InputEvent.swift           # Testable event value type
│   │   ├── SelectionGesture.swift     # Domain gesture value
│   │   ├── SelectionGestureClassifier.swift # Pure gesture state machine
│   │   └── SelectionMonitor.swift     # CoreGraphics event tap lifecycle
│   ├── Onboarding/
│   │   ├── OnboardingView.swift       # Permission explanation and CTA
│   │   └── OnboardingWindowController.swift # First-launch AppKit window
│   ├── Settings/
│   │   ├── AppSettings.swift          # Typed settings and defaults
│   │   ├── SettingsStore.swift         # UserDefaults persistence
│   │   ├── LoginItemService.swift      # SMAppService adapter
│   │   ├── SettingsView.swift          # User settings and live preview
│   │   └── SettingsWindowController.swift # Single reusable settings window
│   ├── Toast/
│   │   ├── ToastPosition.swift         # Six-position geometry
│   │   ├── ToastView.swift             # SwiftUI toast content
│   │   ├── ToastPanel.swift            # Nonactivating NSPanel subclass
│   │   └── ToastCoordinator.swift      # Screen selection and 1.2s lifecycle
│   ├── Support/
│   │   ├── AppLog.swift                # Privacy-safe os.Logger wrapper
│   │   └── DelayScheduler.swift        # Injectable cancellation-aware delays
│   ├── Resources/
│   │   └── Assets.xcassets/            # AppIcon and MenuBarIcon assets
│   └── Info.plist
├── SelectCopyTests/
│   ├── AccessibilityClientTests.swift
│   ├── AppLanguageTests.swift
│   ├── AppSettingsTests.swift
│   ├── AppContainerTests.swift
│   ├── CopyFallbackServiceTests.swift
│   ├── LoginItemServiceTests.swift
│   ├── PasteboardClientTests.swift
│   ├── PermissionCoordinatorTests.swift
│   ├── PrivacyLoggingTests.swift
│   ├── SelectionCopyCoordinatorTests.swift
│   ├── SelectionGestureClassifierTests.swift
│   ├── SelectionMonitorTests.swift
│   ├── SmokeTests.swift
│   ├── SettingsStoreTests.swift
│   ├── TestDoubles.swift
│   ├── ToastCoordinatorTests.swift
│   └── ToastPositionTests.swift
├── SelectCopyUITests/
│   ├── SettingsFlowUITests.swift
│   └── SmokeUITests.swift
├── .gitignore
├── .swiftformat
├── .swiftlint.yml
├── AGENTS.md
├── LICENSE
├── Makefile
├── PRIVACY.md
├── README.md
└── project.yml
```

Files are grouped by responsibility. Framework calls live only in adapters; gesture classification, decision-making, settings validation and geometry remain pure and independently testable.

---

### Task 1: Repository and buildable menu bar shell

**Files:**
- Create: `.gitignore`
- Create: `.swiftformat`
- Create: `.swiftlint.yml`
- Create: `Makefile`
- Create: `project.yml`
- Create: `Config/Debug.xcconfig`
- Create: `Config/Release.xcconfig`
- Create: `SelectCopy/Info.plist`
- Create: `SelectCopy/App/SelectCopyApp.swift`
- Create: `SelectCopy/App/AppDelegate.swift`
- Create: `SelectCopyTests/SmokeTests.swift`
- Create: `SelectCopyUITests/SmokeUITests.swift`

**Interfaces:**
- Consumes: macOS 13 SDK, XcodeGen, Xcode command-line tools.
- Produces: scheme `SelectCopy`, unit-test scheme inclusion, app bundle `com.selectcopy.app`, Swift 6 module `SelectCopy`.

- [ ] **Step 1: Initialize Git and add repository hygiene**

Run:

```bash
cd /Users/vladimir/projects/select-copy
git init -b codex/select-copy
```

Create `.gitignore` with:

```gitignore
.DS_Store
DerivedData/
build/
*.xcarchive
*.dSYM.zip
*.app.zip
release/
```

Do not ignore `SelectCopy.xcodeproj`; generated project changes must remain reviewable beside `project.yml`.

Create `.swiftformat` with:

```text
--swiftversion 6.0
--indent 4
--self insert
--stripunusedargs closure-only
```

Create `.swiftlint.yml` with:

```yaml
included:
  - SelectCopy
  - SelectCopyTests
  - SelectCopyUITests
opt_in_rules:
  - empty_count
  - first_where
  - force_unwrapping
  - sorted_imports
line_length:
  warning: 120
  error: 160
identifier_name:
  excluded: [id, x, y]
```

- [ ] **Step 2: Add the first failing smoke test**

Create `SelectCopyTests/SmokeTests.swift`:

```swift
import XCTest
@testable import SelectCopy

final class SmokeTests: XCTestCase {
    func testProductNameIsStable() {
        XCTAssertEqual(ProductIdentity.name, "SelectCopy")
        XCTAssertEqual(ProductIdentity.bundleIdentifier, "com.selectcopy.app")
    }
}
```

Create `SelectCopyUITests/SmokeUITests.swift` as a compile-only initial UI-test target:

```swift
import XCTest

final class SmokeUITests: XCTestCase {}
```

- [ ] **Step 3: Define the XcodeGen project and verify the test initially fails**

In `project.yml`, define one macOS application target and two test targets with:

```yaml
name: SelectCopy
options:
  minimumXcodeGenVersion: 2.42.0
configs: [Debug, Release]
settings:
  base:
    MACOSX_DEPLOYMENT_TARGET: 13.0
    SWIFT_VERSION: 6.0
    PRODUCT_BUNDLE_IDENTIFIER: com.selectcopy.app
    ARCHS: "arm64 x86_64"
targets:
  SelectCopy:
    type: application
    platform: macOS
    sources: [SelectCopy]
    info:
      path: SelectCopy/Info.plist
      properties:
        CFBundleDisplayName: SelectCopy
        LSUIElement: true
    configFiles:
      Debug: Config/Debug.xcconfig
      Release: Config/Release.xcconfig
  SelectCopyTests:
    type: bundle.unit-test
    platform: macOS
    sources: [SelectCopyTests]
    dependencies:
      - target: SelectCopy
  SelectCopyUITests:
    type: bundle.ui-testing
    platform: macOS
    sources: [SelectCopyUITests]
    dependencies:
      - target: SelectCopy
schemes:
  SelectCopy:
    build:
      targets:
        SelectCopy: all
        SelectCopyTests: [test]
        SelectCopyUITests: [test]
    test:
      targets: [SelectCopyTests, SelectCopyUITests]
```

Run:

```bash
xcodegen generate
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/SmokeTests
```

Expected: FAIL because `ProductIdentity` is undefined.

- [ ] **Step 4: Implement the minimal menu bar application**

Add to `SelectCopy/App/SelectCopyApp.swift`:

```swift
import SwiftUI

enum ProductIdentity {
    static let name = "SelectCopy"
    static let bundleIdentifier = "com.selectcopy.app"
}

@main
struct SelectCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(ProductIdentity.name, systemImage: "clipboard") {
            Text("SelectCopy")
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
```

Create an empty `NSObject, NSApplicationDelegate` implementation in `AppDelegate.swift`. XcodeGen writes the standard bundle keys plus `LSUIElement = true` and `CFBundleDisplayName = SelectCopy` to `Info.plist`.

- [ ] **Step 5: Configure builds and checks**

Set `ENABLE_HARDENED_RUNTIME = NO` and `CODE_SIGNING_ALLOWED = NO` in `Debug.xcconfig`. Set `ENABLE_HARDENED_RUNTIME = YES`, `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = YES`, and `DEAD_CODE_STRIPPING = YES` in `Release.xcconfig`.

Create `Makefile` targets:

```make
project:
	xcodegen generate

test: project
	xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS'

build: project
	xcodebuild build -project SelectCopy.xcodeproj -scheme SelectCopy -configuration Debug -destination 'platform=macOS'

format:
	swiftformat SelectCopy SelectCopyTests SelectCopyUITests

lint:
	swiftlint lint --strict
```

- [ ] **Step 6: Run the focused test and build**

Run:

```bash
make project
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/SmokeTests
make build
```

Expected: smoke test PASS and Debug build SUCCEEDED.

- [ ] **Step 7: Commit the shell**

```bash
git add .gitignore .swiftformat .swiftlint.yml Makefile project.yml Config SelectCopy SelectCopyTests/SmokeTests.swift SelectCopyUITests/SmokeUITests.swift
git commit -m "chore: scaffold SelectCopy macOS app"
```

---

### Task 2: Pure gesture classification

**Files:**
- Create: `SelectCopy/Monitoring/InputEvent.swift`
- Create: `SelectCopy/Monitoring/SelectionGesture.swift`
- Create: `SelectCopy/Monitoring/SelectionGestureClassifier.swift`
- Create: `SelectCopyTests/SelectionGestureClassifierTests.swift`

**Interfaces:**
- Consumes: normalized mouse/key events with no framework object ownership.
- Produces: `SelectionGestureClassifier.consume(_:) -> SelectionGesture?`; `SelectionGesture.Kind` values `drag`, `multiClick`, `keyboard`, `selectAll`.

- [ ] **Step 1: Write failing classifier tests**

Cover these cases in table-driven XCTest methods:

```swift
func testMouseGestures() {
    let cases: [(CGPoint, CGPoint, Int64, SelectionGesture.Kind?)] = [
        (.zero, CGPoint(x: 2, y: 0), 1, nil),
        (.zero, CGPoint(x: 3, y: 0), 1, .drag),
        (.zero, .zero, 2, .multiClick),
        (.zero, .zero, 3, .multiClick),
    ]
    for (down, up, clicks, expected) in cases {
        var classifier = SelectionGestureClassifier(dragThreshold: 3)
        _ = classifier.consume(.mouseDown(location: down, clickCount: clicks))
        XCTAssertEqual(classifier.consume(.mouseUp(location: up, clickCount: clicks))?.kind, expected)
    }
}

func testKeyboardSelectionGestures() {
    let cases: [(CGKeyCode, CGEventFlags, SelectionGesture.Kind?)] = [
        (123, [.maskShift], .keyboard),
        (124, [.maskShift, .maskAlternate], .keyboard),
        (126, [.maskShift, .maskCommand], .keyboard),
        (0, [.maskCommand], .selectAll),
        (0, [], nil),
        (51, [.maskShift], nil),
    ]
    for (keyCode, flags, expected) in cases {
        var classifier = SelectionGestureClassifier()
        XCTAssertEqual(classifier.consume(.keyUp(keyCode: keyCode, flags: flags))?.kind, expected)
    }
}
```

Also test Home `115`, End `119`, Page Up `116`, Page Down `121`, and synthetic events carrying `InputEvent.syntheticSourceMarker`.

- [ ] **Step 2: Run tests and confirm failure**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/SelectionGestureClassifierTests
```

Expected: FAIL because gesture types and classifier do not exist.

- [ ] **Step 3: Implement normalized events and state machine**

Use value types with these signatures:

```swift
struct InputEvent: Equatable, Sendable {
    static let syntheticSourceMarker: Int64 = 0x5343_4F50_59
    enum Kind: Equatable, Sendable { case mouseDown, mouseUp, keyUp }
    let kind: Kind
    var location: CGPoint = .zero
    var clickCount: Int64 = 0
    var keyCode: CGKeyCode = 0
    var flags: CGEventFlags = []
    var sourceUserData: Int64 = 0
}

struct SelectionGesture: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case drag, multiClick, keyboard, selectAll }
    let kind: Kind
    let screenPoint: CGPoint?
}
```

`SelectionGestureClassifier` stores only the last mouse-down location. Use Euclidean distance and `>= dragThreshold`. Recognize key codes `{123, 124, 125, 126, 115, 119, 116, 121}` only when Shift is present; recognize key code `0` only when Command is present. Reject `sourceUserData == InputEvent.syntheticSourceMarker` before changing state.

- [ ] **Step 4: Run classifier tests**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/SelectionGestureClassifierTests
```

Expected: all classifier tests PASS.

- [ ] **Step 5: Commit gesture classification**

```bash
git add SelectCopy/Monitoring SelectCopyTests/SelectionGestureClassifierTests.swift
git commit -m "feat: classify explicit text selection gestures"
```

---

### Task 3: Accessibility permission and global event monitor

**Files:**
- Create: `SelectCopy/Accessibility/PermissionCoordinator.swift`
- Create: `SelectCopy/Monitoring/SelectionMonitor.swift`
- Create: `SelectCopy/Support/AppLog.swift`
- Modify: `SelectCopy/App/AppDelegate.swift`
- Create: `SelectCopyTests/PermissionCoordinatorTests.swift`
- Create: `SelectCopyTests/SelectionMonitorTests.swift`
- Create: `SelectCopyTests/TestDoubles.swift`

**Interfaces:**
- Consumes: `SelectionGestureClassifier`, CoreGraphics event tap, Accessibility trust API.
- Produces: `PermissionCoordinating.isTrusted`, `requestAccess()`, `openSystemSettings()`; `SelectionMonitoring.start(onGesture:)`, `stop()`.

- [ ] **Step 1: Write failing permission tests**

Define an injected trust adapter and test state transitions:

```swift
@MainActor
func testRefreshPublishesRevokedPermission() {
    let trust = AccessibilityTrustSpy(values: [true, false])
    let coordinator = PermissionCoordinator(trustClient: trust)
    coordinator.refresh()
    XCTAssertTrue(coordinator.isTrusted)
    coordinator.refresh()
    XCTAssertFalse(coordinator.isTrusted)
}

func testRequestUsesPromptOption() {
    let trust = AccessibilityTrustSpy(values: [false])
    let coordinator = PermissionCoordinator(trustClient: trust)
    coordinator.requestAccess()
    XCTAssertEqual(trust.promptValues, [true])
}
```

- [ ] **Step 2: Write failing monitor lifecycle tests**

Test that start is idempotent, stop invalidates the run-loop source, disabled callbacks call `enable`, and failed re-enable recreates the tap. The fake event-tap client must expose counts instead of creating OS resources.

- [ ] **Step 3: Run focused tests and confirm failure**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' \
  -only-testing:SelectCopyTests/PermissionCoordinatorTests \
  -only-testing:SelectCopyTests/SelectionMonitorTests
```

Expected: FAIL because coordinators and protocols are undefined.

- [ ] **Step 4: Implement permission coordination**

Use:

```swift
protocol AccessibilityTrustClient {
    func isTrusted(prompt: Bool) -> Bool
    func openPrivacySettings()
}

@MainActor
final class PermissionCoordinator: ObservableObject {
    @Published private(set) var isTrusted: Bool
    func refresh()
    func requestAccess()
    func openSystemSettings()
}
```

The live adapter calls `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt`, and opens:

```swift
URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
```

via `NSWorkspace.shared.open`. `AppLog` must use `Logger` with public metadata only; do not accept selection text parameters.

- [ ] **Step 5: Implement the listen-only event tap**

Create a `.cgSessionEventTap` at `.tailAppendEventTap` with `.listenOnly`. Subscribe to left mouse down/up, key up, and tap-disabled pseudo-events. Normalize `CGEvent` immediately into `InputEvent`; dispatch produced gestures to `@MainActor` without retaining `CGEvent`.

Expose:

```swift
protocol SelectionMonitoring: AnyObject {
    func start(onGesture: @escaping @MainActor (SelectionGesture) -> Void) throws
    func stop()
}

final class SelectionMonitor: SelectionMonitoring {
    static let syntheticEventMarker = InputEvent.syntheticSourceMarker
}
```

Return events unchanged from the callback. On `tapDisabledByTimeout` or `tapDisabledByUserInput`, attempt `CGEvent.tapEnable`; recreate the tap only when it remains disabled.

- [ ] **Step 6: Handle sleep and wake lifecycle**

In `AppDelegate`, observe `NSWorkspace.willSleepNotification` and `didWakeNotification`. Stop the monitor before sleep. On wake, refresh permission and restart only when trusted. Remove observers during termination.

- [ ] **Step 7: Run focused tests and a manual permission smoke check**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' \
  -only-testing:SelectCopyTests/PermissionCoordinatorTests \
  -only-testing:SelectCopyTests/SelectionMonitorTests
make build
```

Expected: tests PASS; launching Debug app displays the system Accessibility prompt only after `requestAccess()`.

- [ ] **Step 8: Commit monitoring and permission support**

```bash
git add SelectCopy/Accessibility SelectCopy/Monitoring/SelectionMonitor.swift SelectCopy/Support SelectCopy/App/AppDelegate.swift SelectCopyTests
git commit -m "feat: monitor global selection gestures"
```

---

### Task 4: Accessibility selection reader

**Files:**
- Create: `SelectCopy/Accessibility/AccessibilityClient.swift`
- Create: `SelectCopyTests/AccessibilityClientTests.swift`
- Modify: `SelectCopyTests/TestDoubles.swift`

**Interfaces:**
- Consumes: focused AX element attributes `role`, `subrole`, `selectedText`.
- Produces: `SelectionReading.readSelection() -> SelectionReadResult` with explicit fallback eligibility.

- [ ] **Step 1: Write failing behavior tests**

Use a fake AX attribute client and cover:

```swift
func testReturnsSelectedText() {
    let reader = makeReader(role: kAXTextAreaRole, selectedText: "hello")
    XCTAssertEqual(reader.readSelection(), .text("hello"))
}

func testEmptySelectionDoesNotAllowFallback() {
    let reader = makeReader(role: kAXTextAreaRole, selectedText: "")
    XCTAssertEqual(reader.readSelection(), .empty)
}

func testSecureFieldIsAlwaysRejected() {
    let reader = makeReader(role: kAXTextFieldRole, subrole: kAXSecureTextFieldSubrole)
    XCTAssertEqual(reader.readSelection(), .secure)
}

func testUnsupportedTextRoleAllowsFallback() {
    let reader = makeReader(role: kAXTextAreaRole, selectedTextError: .attributeUnsupported)
    XCTAssertEqual(reader.readSelection(), .unsupported(fallbackAllowed: true))
}

func testUnsupportedButtonDoesNotAllowFallback() {
    let reader = makeReader(role: kAXButtonRole, selectedTextError: .attributeUnsupported)
    XCTAssertEqual(reader.readSelection(), .unsupported(fallbackAllowed: false))
}
```

Also cover `kAXErrorNoValue`, `kAXErrorNotImplemented`, invalid focused element, whitespace-only text, and `kAXWebAreaRole`.

- [ ] **Step 2: Run tests and confirm failure**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/AccessibilityClientTests
```

Expected: FAIL because `SelectionReadResult` and reader are missing.

- [ ] **Step 3: Implement the typed AX boundary**

Define:

```swift
enum SelectionReadResult: Equatable, Sendable {
    case text(String)
    case empty
    case secure
    case unsupported(fallbackAllowed: Bool)
    case failure(AXError)
}

protocol SelectionReading: Sendable {
    func readSelection() -> SelectionReadResult
}
```

The live client obtains `kAXFocusedUIElementAttribute` from `AXUIElementCreateSystemWide()`, then reads role and subrole. Treat text field, text area, static text, web area and document roles as fallback-eligible. Check secure subrole before reading selected text. Preserve whitespace exactly; only `text.isEmpty` maps to `.empty`.

- [ ] **Step 4: Run focused tests**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/AccessibilityClientTests
```

Expected: all Accessibility reader tests PASS.

- [ ] **Step 5: Commit the reader**

```bash
git add SelectCopy/Accessibility/AccessibilityClient.swift SelectCopyTests/AccessibilityClientTests.swift SelectCopyTests/TestDoubles.swift
git commit -m "feat: read selected text through accessibility"
```

---

### Task 5: Pasteboard transactions and Command+C fallback

**Files:**
- Create: `SelectCopy/Clipboard/PasteboardClient.swift`
- Create: `SelectCopy/Clipboard/CopyFallbackService.swift`
- Create: `SelectCopy/Support/DelayScheduler.swift`
- Create: `SelectCopyTests/PasteboardClientTests.swift`
- Create: `SelectCopyTests/CopyFallbackServiceTests.swift`
- Modify: `SelectCopyTests/TestDoubles.swift`

**Interfaces:**
- Consumes: `NSPasteboard.general`, a tagged `CGEventSource`, injected async delay.
- Produces: `PasteboardServicing.writeText`, `snapshot`, `restore`; `FallbackCopying.copySelection() async -> FallbackCopyResult`.

- [ ] **Step 1: Write failing pasteboard tests**

Use `NSPasteboard.withUniqueName()` to avoid touching the user's clipboard:

```swift
func testWritesPlainText() {
    let board = NSPasteboard.withUniqueName()
    let client = PasteboardClient(pasteboard: board)
    XCTAssertTrue(client.writeText("hello"))
    XCTAssertEqual(board.string(forType: .string), "hello")
}

func testRestoresMultipleItemsAndTypes() throws {
    let board = NSPasteboard.withUniqueName()
    let first = NSPasteboardItem()
    first.setString("before", forType: .string)
    first.setData(Data([1, 2]), forType: .init("com.selectcopy.test"))
    board.writeObjects([first])
    let client = PasteboardClient(pasteboard: board)
    let snapshot = client.snapshot()
    _ = client.writeText("changed")
    XCTAssertTrue(client.restore(snapshot))
    XCTAssertEqual(board.pasteboardItems?.first?.string(forType: .string), "before")
    XCTAssertEqual(board.pasteboardItems?.first?.data(forType: .init("com.selectcopy.test")), Data([1, 2]))
}
```

- [ ] **Step 2: Write failing fallback tests**

Test these exact outcomes:

- no `changeCount` change before 250 ms -> `.noChange` and no restore;
- changed board with nonempty `.string` -> `.copied(text)`;
- changed board with no `.string` -> restore snapshot and `.rejectedNonText`;
- posting service tags both key-down and key-up events with `SelectionMonitor.syntheticEventMarker`;
- cancellation exits without a toast-worthy success.

- [ ] **Step 3: Run focused tests and confirm failure**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' \
  -only-testing:SelectCopyTests/PasteboardClientTests \
  -only-testing:SelectCopyTests/CopyFallbackServiceTests
```

Expected: FAIL because pasteboard and fallback services are undefined.

- [ ] **Step 4: Implement pasteboard snapshotting**

Use immutable data snapshots:

```swift
struct PasteboardSnapshot: Equatable, Sendable {
    let items: [[String: Data]]
}

@MainActor
protocol PasteboardServicing {
    var changeCount: Int { get }
    func writeText(_ text: String) -> Bool
    func readText() -> String?
    func snapshot() -> PasteboardSnapshot
    func restore(_ snapshot: PasteboardSnapshot) -> Bool
}
```

Snapshot each available `NSPasteboardItem` type whose `data(forType:)` is readable. Restore by clearing and writing newly created `NSPasteboardItem` values. Never log type data or string values.

- [ ] **Step 5: Implement tagged key posting and async polling**

Define:

```swift
enum FallbackCopyResult: Equatable, Sendable {
    case copied(String)
    case noChange
    case rejectedNonText
    case failed
}

protocol FallbackCopying: Sendable {
    func copySelection() async -> FallbackCopyResult
}
```

Before posting, capture snapshot and `changeCount`. Post virtual key code `8` (`C`) down and up with `.maskCommand`; set `.eventSourceUserData` to `SelectionMonitor.syntheticEventMarker`. Poll every 25 ms for at most ten iterations through `DelayScheduling`. Accept only a nonempty string after `changeCount` changes. Restore changed nontext content.

- [ ] **Step 6: Run focused tests**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' \
  -only-testing:SelectCopyTests/PasteboardClientTests \
  -only-testing:SelectCopyTests/CopyFallbackServiceTests
```

Expected: all pasteboard and fallback tests PASS without changing `NSPasteboard.general`.

- [ ] **Step 7: Commit clipboard support**

```bash
git add SelectCopy/Clipboard SelectCopy/Support/DelayScheduler.swift SelectCopyTests
git commit -m "feat: add safe clipboard copy fallback"
```

---

### Task 6: Debounced copy coordinator

**Files:**
- Create: `SelectCopy/Coordinator/SelectionCopyCoordinator.swift`
- Create: `SelectCopyTests/SelectionCopyCoordinatorTests.swift`
- Modify: `SelectCopyTests/TestDoubles.swift`

**Interfaces:**
- Consumes: `SelectionReading`, `PasteboardServicing`, `FallbackCopying`, `DelayScheduling`, `CopyConfirmationPresenting`.
- Produces: `SelectionCopyCoordinating.handle(_:)`, `cancelPendingCopy()`.

- [ ] **Step 1: Write failing decision tests**

Create spies and verify:

```swift
@MainActor
func testAXTextWritesDirectlyAndShowsConfirmation() async {
    let fixture = CoordinatorFixture(readResult: .text("hello"))
    fixture.coordinator.handle(.init(kind: .drag, screenPoint: CGPoint(x: 50, y: 60)))
    await fixture.delay.resumeNext()
    await fixture.tasks.flush()
    XCTAssertEqual(fixture.pasteboard.writtenTexts, ["hello"])
    XCTAssertEqual(fixture.fallback.callCount, 0)
    XCTAssertEqual(fixture.presenter.points, [CGPoint(x: 50, y: 60)])
}

@MainActor
func testUnsupportedTextRoleUsesFallback() async {
    let fixture = CoordinatorFixture(
        readResult: .unsupported(fallbackAllowed: true),
        fallbackResult: .copied("fallback")
    )
    fixture.coordinator.handle(.init(kind: .keyboard, screenPoint: nil))
    await fixture.delay.resumeNext()
    await fixture.tasks.flush()
    XCTAssertEqual(fixture.fallback.callCount, 1)
    XCTAssertEqual(fixture.presenter.points.count, 1)
}
```

Also assert no write/fallback/toast for `.empty`, `.secure`, `.failure`, and `.unsupported(fallbackAllowed: false)`; direct write failure does not invoke fallback; a second gesture cancels the first pending debounce; identical selected strings from two separate gestures produce two writes and two confirmations.

- [ ] **Step 2: Run tests and confirm failure**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/SelectionCopyCoordinatorTests
```

Expected: FAIL because coordinator and presenter protocol are undefined.

- [ ] **Step 3: Implement the coordinator**

Expose:

```swift
@MainActor
protocol CopyConfirmationPresenting: AnyObject {
    func showCopyConfirmation(at screenPoint: CGPoint?)
}

@MainActor
final class SelectionCopyCoordinator {
    func handle(_ gesture: SelectionGesture)
    func cancelPendingCopy()
}
```

Keep exactly one `Task<Void, Never>?`. Every gesture cancels and replaces it, waits 100 ms, then switches exhaustively over `SelectionReadResult`. Show confirmation only after `writeText` returns true or fallback returns `.copied`. Do not compare the selected string with previous values.

- [ ] **Step 4: Run coordinator tests**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/SelectionCopyCoordinatorTests
```

Expected: all coordinator tests PASS.

- [ ] **Step 5: Commit the orchestration**

```bash
git add SelectCopy/Coordinator SelectCopyTests/SelectionCopyCoordinatorTests.swift SelectCopyTests/TestDoubles.swift
git commit -m "feat: coordinate automatic text copying"
```

---

### Task 7: Settings model, persistence and login item

**Files:**
- Create: `SelectCopy/Settings/AppSettings.swift`
- Create: `SelectCopy/Settings/SettingsStore.swift`
- Create: `SelectCopy/Settings/LoginItemService.swift`
- Create: `SelectCopy/Localization/AppLanguage.swift`
- Create: `SelectCopy/Toast/ToastPosition.swift`
- Create: `SelectCopyTests/AppSettingsTests.swift`
- Create: `SelectCopyTests/SettingsStoreTests.swift`
- Create: `SelectCopyTests/LoginItemServiceTests.swift`
- Create: `SelectCopyTests/ToastPositionTests.swift`
- Modify: `SelectCopyTests/TestDoubles.swift`

**Interfaces:**
- Consumes: `UserDefaults`, `SMAppService.mainApp`, `NSScreen.visibleFrame` values.
- Produces: `AppSettings`, `SettingsStore`, `LoginItemServicing`, and `ToastPosition.frame(for:toastSize:inset:)`.

- [ ] **Step 1: Write failing settings validation tests**

Test defaults and custom-text truncation:

```swift
func testDefaultsMatchSpecification() {
    XCTAssertEqual(AppSettings.default.toastEnabled, true)
    XCTAssertEqual(AppSettings.default.toastPosition, .topTrailing)
    XCTAssertEqual(AppSettings.default.toastContentMode, .localizedText)
    XCTAssertEqual(AppSettings.default.customToastText, "")
    XCTAssertEqual(AppSettings.default.language, .system)
    XCTAssertEqual(AppSettings.default.launchAtLogin, false)
}

func testCustomTextIsLimitedToSixtyCharacters() {
    var settings = AppSettings.default
    settings.setCustomToastText(String(repeating: "🟢", count: 61))
    XCTAssertEqual(settings.customToastText.count, 60)
}
```

- [ ] **Step 2: Write failing persistence tests**

Use an isolated suite `UserDefaults(suiteName: UUID().uuidString)!`. Verify round-trip of every field, fallback for unknown enum raw values, and that the store publishes only validated `AppSettings`.

- [ ] **Step 3: Write failing toast geometry tests**

For visible frame `(x: 100, y: 200, width: 1000, height: 800)`, toast size `200x40`, inset `20`, assert exact origins:

```swift
let expected: [ToastPosition: CGPoint] = [
    .topLeading: CGPoint(x: 120, y: 940),
    .topCenter: CGPoint(x: 500, y: 940),
    .topTrailing: CGPoint(x: 880, y: 940),
    .bottomLeading: CGPoint(x: 120, y: 220),
    .bottomCenter: CGPoint(x: 500, y: 220),
    .bottomTrailing: CGPoint(x: 880, y: 220),
]
```

Add failing `LoginItemServiceTests` with a fake `SMAppService` adapter. Verify `.enabled`, `.notRegistered`, `.requiresApproval` and `.notFound` mappings; verify enabling calls `register()` exactly once, disabling calls `unregister()` exactly once, failures surface as `.unavailable(message)`, and state is reread after every mutation.

- [ ] **Step 4: Run tests and confirm failure**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' \
  -only-testing:SelectCopyTests/AppSettingsTests \
  -only-testing:SelectCopyTests/SettingsStoreTests \
  -only-testing:SelectCopyTests/LoginItemServiceTests \
  -only-testing:SelectCopyTests/ToastPositionTests
```

Expected: FAIL because settings and geometry types are missing.

- [ ] **Step 5: Implement the typed model and persistence**

Use string-backed enums:

```swift
enum ToastPosition: String, CaseIterable, Codable, Sendable {
    case topLeading, topCenter, topTrailing
    case bottomLeading, bottomCenter, bottomTrailing
}

enum ToastContentMode: String, CaseIterable, Codable, Sendable {
    case localizedText, customText, iconOnly
}

struct AppSettings: Equatable, Codable, Sendable {
    var launchAtLogin: Bool
    var toastEnabled: Bool
    var toastPosition: ToastPosition
    var toastContentMode: ToastContentMode
    var customToastText: String
    var language: AppLanguage
}
```

Place `AppLanguage` in `SelectCopy/Localization/AppLanguage.swift` with the same `String`, `CaseIterable`, `Codable` and `Sendable` conformances; Task 8 adds locale-resolution behavior to this type.

Persist one versioned Codable blob under `settings.v1`. On decode failure, use `.default`. `setCustomToastText` uses `String(value.prefix(60))`, which counts extended grapheme clusters.

- [ ] **Step 6: Implement exact toast geometry**

Return an `NSRect` whose origin uses visible-frame min/mid/max values and clamps within the frame. Center positions use `frame.midX - toastWidth / 2`. Top positions use `frame.maxY - inset - toastHeight`; bottom positions use `frame.minY + inset`.

- [ ] **Step 7: Implement login item adapter**

Expose:

```swift
enum LoginItemState: Equatable { case enabled, disabled, requiresApproval, unavailable(String) }

@MainActor
protocol LoginItemServicing {
    var state: LoginItemState { get }
    func setEnabled(_ enabled: Bool) throws
    func openSystemSettings()
}
```

Map `SMAppService.mainApp.status` exhaustively. Call `register()` or `unregister()`, then refresh state from the service; never assume the requested value became active. Use `SMAppService.openSystemSettingsLoginItems()` for approval.

- [ ] **Step 8: Run focused tests**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' \
  -only-testing:SelectCopyTests/AppSettingsTests \
  -only-testing:SelectCopyTests/SettingsStoreTests \
  -only-testing:SelectCopyTests/LoginItemServiceTests \
  -only-testing:SelectCopyTests/ToastPositionTests
```

Expected: all model, persistence and geometry tests PASS.

- [ ] **Step 9: Commit settings infrastructure**

```bash
git add SelectCopy/Settings SelectCopy/Toast/ToastPosition.swift SelectCopyTests
git commit -m "feat: persist SelectCopy preferences"
```

---

### Task 8: Runtime localization

**Files:**
- Modify: `SelectCopy/Localization/AppLanguage.swift`
- Create: `SelectCopy/Localization/Localizer.swift`
- Create: `SelectCopy/Localization/Localizable.xcstrings`
- Create: `SelectCopyTests/AppLanguageTests.swift`

**Interfaces:**
- Consumes: `AppSettings.language`, `Locale.current`, compiled String Catalog.
- Produces: `Localizer.text(_:)`, `Localizer.locale`, localized keys for every visible string.

- [ ] **Step 1: Write failing locale resolution tests**

```swift
func testExplicitLanguagesResolveImmediately() {
    XCTAssertEqual(AppLanguage.russian.localeIdentifier(system: "de-DE"), "ru")
    XCTAssertEqual(AppLanguage.english.localeIdentifier(system: "de-DE"), "en")
}

func testSystemLanguagePreservesCurrentIdentifier() {
    XCTAssertEqual(AppLanguage.system.localeIdentifier(system: "de-DE"), "de-DE")
}

func testUnsupportedSystemLanguageFallsBackToEnglishBundle() {
    let localizer = Localizer(language: .system, systemLocaleIdentifier: "de-DE")
    XCTAssertEqual(localizer.text("toast.copied"), "Copied")
}
```

- [ ] **Step 2: Run test and confirm failure**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/AppLanguageTests
```

Expected: FAIL because locale resolution and catalog are missing.

- [ ] **Step 3: Add complete English and Russian catalog entries**

Add keys for: app status, permission missing, open System Settings, Settings, show test toast, Quit, onboarding title/body/actions, launch at login, show toast, toast position and six values, content mode and three values, custom text, language and three values, version, GitHub, copied confirmation, login-item error, Accessibility error.

Use English as source/fallback language. Russian translations must use concise native UI copy, including `toast.copied = Скопировано` and `menu.status.active = Работает`.

- [ ] **Step 4: Implement runtime bundle selection**

`Localizer` is `@MainActor ObservableObject` with published `language` and `locale`. Resolve explicit `ru.lproj`/`en.lproj`; for system mode use Russian when the system language begins with `ru`, otherwise English. Resolve through `bundle.localizedString(forKey:value:table:)`; return the key only when both localized and English fallback lookup fail.

- [ ] **Step 5: Run localization tests**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/AppLanguageTests
```

Expected: locale and fallback tests PASS.

- [ ] **Step 6: Commit localization**

```bash
git add SelectCopy/Localization SelectCopyTests/AppLanguageTests.swift
git commit -m "feat: add runtime Russian and English localization"
```

---

### Task 9: Toast panel, view and lifecycle

**Files:**
- Create: `SelectCopy/Toast/ToastView.swift`
- Create: `SelectCopy/Toast/ToastPanel.swift`
- Create: `SelectCopy/Toast/ToastCoordinator.swift`
- Create: `SelectCopyTests/ToastCoordinatorTests.swift`
- Modify: `SelectCopyTests/TestDoubles.swift`

**Interfaces:**
- Consumes: `SettingsStore`, `Localizer`, pointer screen point, `NSScreen` adapter, delay scheduler.
- Produces: `CopyConfirmationPresenting.showCopyConfirmation(at:)` and `showPreview()`.

- [ ] **Step 1: Write failing toast lifecycle tests**

Test with fake screens, panel and scheduler:

```swift
@MainActor
func testUsesScreenContainingSelectionPointAndConfiguredPosition() {
    let fixture = ToastFixture(position: .bottomCenter, screens: [.left, .right])
    fixture.coordinator.showCopyConfirmation(at: fixture.right.frame.center)
    XCTAssertEqual(fixture.panel.lastFrame, .bottomCenter.frame(
        for: fixture.panel.contentSize,
        in: fixture.right.visibleFrame,
        inset: 20
    ))
}

@MainActor
func testSecondCopyReusesPanelAndRestartsDismissal() async {
    let fixture = ToastFixture()
    fixture.coordinator.showCopyConfirmation(at: nil)
    fixture.coordinator.showCopyConfirmation(at: nil)
    XCTAssertEqual(fixture.panel.showCount, 2)
    XCTAssertEqual(fixture.scheduler.cancellationCount, 1)
}
```

Also test toast-disabled no-op, localized/custom/icon-only content, empty custom text rendering as icon-only, main-screen fallback, sleep hiding, and 1,200 ms dismissal.

- [ ] **Step 2: Run tests and confirm failure**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/ToastCoordinatorTests
```

Expected: FAIL because toast coordinator and panel adapter are undefined.

- [ ] **Step 3: Implement `ToastView`**

Render one of:

```swift
enum ToastContent: Equatable {
    case text(String)
    case iconOnly
}
```

Use `Image(systemName: "checkmark.circle.fill")`, one-line text, `.ultraThinMaterial`, a restrained 12-point corner radius, system shadow, and no fixed foreground colors. Use opacity plus a short scale transition unless `accessibilityReduceMotion` is enabled. The view must expose a localized accessibility label even in icon-only mode.

- [ ] **Step 4: Implement nonactivating panel**

Subclass `NSPanel` and override `canBecomeKey` and `canBecomeMain` to `false`. Configure `.borderless` and `.nonactivatingPanel`, `isOpaque = false`, clear background, `hasShadow = true`, `ignoresMouseEvents = true`, `hidesOnDeactivate = false`, level `.floating`, and collection behavior `[.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]`.

- [ ] **Step 5: Implement coordinator screen selection and timer**

Keep one panel instance and one dismissal task. Select the screen whose `frame.contains(point)`; otherwise use main screen. Rebuild the `NSHostingView` root content, call `sizeToFit`, calculate frame through `ToastPosition`, order front without activation, and dismiss after exactly 1,200 ms. Post an accessibility announcement without exposing selected text.

- [ ] **Step 6: Run focused tests and visually inspect all states**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/ToastCoordinatorTests
make build
```

Manually show localized text, 60-character custom text and icon-only toast in all six positions, light/dark mode and reduced motion. Expected: no clipping, no focus change, no mouse interception.

- [ ] **Step 7: Commit toast UI**

```bash
git add SelectCopy/Toast SelectCopyTests/ToastCoordinatorTests.swift SelectCopyTests/TestDoubles.swift
git commit -m "feat: show configurable copy confirmation toast"
```

---

### Task 10: Settings, onboarding and menu bar UI

**Files:**
- Create: `SelectCopy/Settings/SettingsView.swift`
- Create: `SelectCopy/Settings/SettingsWindowController.swift`
- Create: `SelectCopy/Onboarding/OnboardingView.swift`
- Create: `SelectCopy/Onboarding/OnboardingWindowController.swift`
- Create: `SelectCopy/MenuBar/MenuBarContentView.swift`
- Create: `SelectCopyUITests/SettingsFlowUITests.swift`
- Modify: `SelectCopy/App/SelectCopyApp.swift`
- Modify: `SelectCopy/App/AppDelegate.swift`

**Interfaces:**
- Consumes: settings store, login item service, permission coordinator, localizer, toast preview.
- Produces: one reusable Settings window, one first-run Onboarding window, actionable menu bar status.

- [ ] **Step 1: Add failing UI tests with launch arguments**

Add app-only debug launch arguments `-ui-testing`, `-reset-settings`, `-permission-state trusted|denied` and write:

```swift
func testChangingLanguageAndToastSettingsPersists() {
    let app = launchResetApp(permission: "trusted")
    app.statusItems.firstMatch.click()
    app.menuItems["Settings"].click()
    app.popUpButtons["Language"].click()
    app.menuItems["Русский"].click()
    XCTAssertTrue(app.checkBoxes["Показывать уведомление о копировании"].exists)
    app.checkBoxes["Показывать уведомление о копировании"].click()
    app.terminate()
    app.launch()
    XCTAssertEqual(app.checkBoxes["Показывать уведомление о копировании"].value as? Int, 0)
}
```

Add tests for denied permission CTA, six position choices, three content modes, custom field disabled state, 60-character enforcement and test-toast action.

- [ ] **Step 2: Run UI tests and confirm failure**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyUITests/SettingsFlowUITests
```

Expected: FAIL because settings and onboarding windows do not exist.

- [ ] **Step 3: Implement the UI-test launch adapter**

Before constructing live services, add a `#if DEBUG` launch-argument adapter used only by UI tests. `-reset-settings` clears the dedicated `com.selectcopy.app.ui-tests` defaults suite, `-permission-state trusted` injects a trusted fake, and `-permission-state denied` injects an untrusted fake. Production builds must not contain a path that overrides real Accessibility trust.

- [ ] **Step 4: Implement a single Settings window**

`SettingsWindowController` owns one `NSWindow` with `NSHostingController(rootView: SettingsView(...))`; repeated opens bring the same window forward. `SettingsView` binds every control directly to `SettingsStore.settings`, routes launch-at-login changes through `LoginItemService`, exposes permission state, and uses `ToastCoordinator.showPreview()`.

Use native Form, Toggle, Picker and TextField controls. Give the custom text field `lineLimit(1)` and disable it unless mode is `.customText`. Show the same `ToastView` used by the real panel as live preview.

- [ ] **Step 5: Implement onboarding**

Show onboarding automatically only when Accessibility permission is absent and `onboarding.hasBeenShown` is false. Explain automatic copying, no history, and the Accessibility requirement. The primary action calls `requestAccess()`. A secondary action opens System Settings. Permission polling runs only while the onboarding window is visible and stops immediately after trust becomes true or the window closes.

- [ ] **Step 6: Implement menu bar content**

The menu contains status, permission repair action when needed, Settings, Show test toast and Quit. Replace the temporary system-image label with `Image("MenuBarIcon")`. Disable test toast only when toast presentation itself is unavailable; it remains usable when automatic toast is disabled so settings can be previewed.

- [ ] **Step 7: Run UI tests and inspect keyboard/VoiceOver behavior**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyUITests/SettingsFlowUITests
```

Expected: UI tests PASS in English and Russian; all controls are reachable by keyboard and have meaningful accessibility labels.

- [ ] **Step 8: Commit application UI**

```bash
git add SelectCopy/App SelectCopy/MenuBar SelectCopy/Onboarding SelectCopy/Settings SelectCopyUITests
git commit -m "feat: add onboarding and settings interface"
```

---

### Task 11: Dependency composition and end-to-end runtime

**Files:**
- Create: `SelectCopy/App/AppContainer.swift`
- Modify: `SelectCopy/App/SelectCopyApp.swift`
- Modify: `SelectCopy/App/AppDelegate.swift`
- Modify: `SelectCopy/MenuBar/MenuBarContentView.swift`
- Modify: `SelectCopy/Settings/SettingsView.swift`
- Create: `SelectCopyTests/AppContainerTests.swift`

**Interfaces:**
- Consumes: all services from Tasks 2–10.
- Produces: one application lifecycle that starts monitoring only when permission is trusted and remains synchronized with settings, wake events and permission changes.

- [ ] **Step 1: Write failing lifecycle tests**

Test:

```swift
@MainActor
func testTrustedLaunchStartsMonitorOnce() {
    let fixture = AppContainerFixture(trusted: true)
    fixture.container.start()
    fixture.container.start()
    XCTAssertEqual(fixture.monitor.startCount, 1)
}

@MainActor
func testPermissionRevocationStopsMonitorAndCancelsCopy() {
    let fixture = AppContainerFixture(trusted: true)
    fixture.container.start()
    fixture.permission.setTrusted(false)
    XCTAssertEqual(fixture.monitor.stopCount, 1)
    XCTAssertEqual(fixture.copyCoordinator.cancelCount, 1)
}
```

Also cover wake with trusted/untrusted states, monitor start failure, settings language propagation, and termination cleanup.

- [ ] **Step 2: Run test and confirm failure**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/AppContainerTests
```

Expected: FAIL because `AppContainer` does not exist.

- [ ] **Step 3: Compose live dependencies in one place**

`AppContainer` is `@MainActor ObservableObject`. Construct one instance each of SettingsStore, Localizer, PermissionCoordinator, PasteboardClient, CopyFallbackService, AccessibilitySelectionReader, ToastCoordinator, SelectionCopyCoordinator and SelectionMonitor. No feature file constructs another feature's concrete dependency.

Observe only published permission/settings state. On trusted state start monitor; on revoked state stop monitor and cancel pending copy. On language changes update Localizer. On toast settings changes update the shared live-preview model.

- [ ] **Step 4: Wire application lifecycle**

Create `AppContainer` once in `AppDelegate.applicationDidFinishLaunching`, expose it to `SelectCopyApp`, and call `shutdown()` from termination. Route monitor gestures directly to `SelectionCopyCoordinator.handle`. Route sleep/wake through `AppContainer.prepareForSleep()` and `resumeAfterWake()`.

- [ ] **Step 5: Run all automated tests**

```bash
make test
```

Expected: all unit and UI tests PASS; no test writes to `NSPasteboard.general` or requires real Accessibility permission.

- [ ] **Step 6: Perform first end-to-end manual run**

Launch the Debug app outside Xcode's test runner, grant Accessibility permission, and verify TextEdit:

1. Single click leaves clipboard unchanged.
2. Drag selection copies exact text and shows toast.
3. Double-click copies the word.
4. Shift+Arrow copies updated selection.
5. Command+A copies all text.
6. Selecting the same text twice produces two confirmations.
7. A secure field never changes clipboard.

- [ ] **Step 7: Commit runtime composition**

```bash
git add SelectCopy/App SelectCopy/MenuBar SelectCopy/Settings SelectCopyTests/AppContainerTests.swift
git commit -m "feat: connect SelectCopy runtime services"
```

---

### Task 12: Original clipboard-check icon assets

**Files:**
- Create: `Scripts/generate-icons.swift`
- Create: `SelectCopy/Resources/Assets.xcassets/Contents.json`
- Create: `SelectCopy/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `SelectCopy/Resources/Assets.xcassets/MenuBarIcon.imageset/Contents.json`
- Generate: `SelectCopy/Resources/Assets.xcassets/AppIcon.appiconset/*.png`
- Generate: `SelectCopy/Resources/Assets.xcassets/MenuBarIcon.imageset/*.pdf`
- Modify: `SelectCopy/Info.plist`

**Interfaces:**
- Consumes: approved visual direction A, CoreGraphics drawing primitives.
- Produces: deterministic app icon sizes and monochrome template menu bar icon.

- [ ] **Step 1: Add an asset validation script that fails on missing files**

At the end of `Scripts/generate-icons.swift`, validate the required macOS sizes `[16, 32, 64, 128, 256, 512, 1024]`, assert every PNG exists and can be decoded by `NSImage`, and exit nonzero when validation fails. Run before generation:

```bash
swift Scripts/generate-icons.swift --validate-only
```

Expected: nonzero exit because assets do not exist.

- [ ] **Step 2: Draw the app icon deterministically**

In the generator, draw at 1024×1024 then render required downscaled variants:

- rounded-square background using system-inspired blue-to-teal gradient;
- centered original clipboard silhouette occupying roughly 54% of the canvas;
- large check mark occupying the lower-right clipboard area;
- no letters, SF Symbols, copied Apple paths or tiny decoration;
- optical padding preserved at 16 px output.

Use `CGPath` with explicit normalized points kept in the script, `CGGradient`, antialiasing and `NSBitmapImageRep` PNG export. The same source drawing must generate every committed size.

- [ ] **Step 3: Generate a dedicated template menu bar vector**

Draw a monochrome 18×18 clipboard and check with 1.5-point rounded strokes, transparent background and no enclosing square. Export a vector PDF at 1× and mark the asset as template-rendering in `Contents.json`. Do not shrink the colorful app icon for the menu bar.

- [ ] **Step 4: Generate and validate assets**

```bash
swift Scripts/generate-icons.swift
swift Scripts/generate-icons.swift --validate-only
make project
make build
```

Expected: generator validation succeeds and Xcode build reports no missing app-icon slots.

- [ ] **Step 5: Visually inspect icon sizes**

Inspect 16, 32, 128 and 1024 px AppIcon outputs on light and dark desktop backgrounds, and the template icon in both menu-bar appearances. Expected: clipboard and check remain distinguishable; no clipped edges or unreadable micro-detail.

- [ ] **Step 6: Commit source and generated assets**

```bash
git add Scripts/generate-icons.swift SelectCopy/Resources SelectCopy/Info.plist
git commit -m "design: add SelectCopy clipboard icon"
```

---

### Task 13: Privacy-safe diagnostics and compatibility QA

**Files:**
- Modify: `SelectCopy/Support/AppLog.swift`
- Create: `PRIVACY.md`
- Create: `docs/compatibility.md`
- Create: `docs/manual-test-checklist.md`
- Modify: `SelectCopyTests/AccessibilityClientTests.swift`
- Modify: `SelectCopyTests/CopyFallbackServiceTests.swift`
- Create: `SelectCopyTests/PrivacyLoggingTests.swift`

**Interfaces:**
- Consumes: operation results and public application bundle identifiers only.
- Produces: privacy policy, reproducible manual matrix, logs safe for public bug reports.

- [ ] **Step 1: Add privacy boundary regression tests**

Inject a recording `LogSink` below `AppLog`. Exercise failed AX reads and rejected clipboard fallback with sentinel selected text, then assert that every recorded metadata value is limited to `SelectionGesture.Kind`, AX error numeric value, outcome enum and bundle identifier and that the sentinel never appears.

- [ ] **Step 2: Run the privacy test and confirm failure if unsafe APIs remain**

```bash
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS' -only-testing:SelectCopyTests/PrivacyLoggingTests
```

Expected: FAIL until every unsafe log signature is removed; otherwise PASS confirms existing implementation is already compliant.

- [ ] **Step 3: Finalize structured logging**

Use categories `monitor`, `accessibility`, `clipboard`, `toast`, `settings`. Log only lifecycle changes, error codes and outcome names. Mark bundle identifier public; never interpolate strings returned from AX or NSPasteboard.

- [ ] **Step 4: Write privacy and compatibility documentation**

`PRIVACY.md` states: all processing is local, there is no network activity, no clipboard history, no analytics, and no selected-text logging. `docs/compatibility.md` records results for Safari, Chrome, Firefox, TextEdit, Notes, Mail, VS Code, Terminal, iTerm2, Preview and Finder, distinguishing direct AX, fallback and unsupported behavior.

- [ ] **Step 5: Execute the manual matrix**

Follow `docs/manual-test-checklist.md` on at least one macOS 13 machine and the current macOS version. For every app test drag, double click, keyboard selection, Command+A, single-click negative behavior and secure-field behavior where available. Record OS/app version and result; never record copied text.

- [ ] **Step 6: Run formatting, lint, tests and build**

```bash
make format
make lint
make test
make build
git diff --check
```

Expected: every command exits 0 and no formatting diff remains.

- [ ] **Step 7: Commit QA and privacy documentation**

```bash
git add SelectCopy/Support PRIVACY.md docs SelectCopyTests
git commit -m "docs: document privacy and compatibility"
```

---

### Task 14: README and contributor documentation

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `AGENTS.md`
- Modify: `Makefile`

**Interfaces:**
- Consumes: finished behavior, permission flow and known compatibility results.
- Produces: install/build/test/troubleshooting instructions sufficient for a new contributor.

- [ ] **Step 1: Write README acceptance checks**

Create a shell check in the Makefile target `check-docs` that verifies README contains these literal headings: `Installation`, `Accessibility permission`, `Settings`, `Compatibility`, `Privacy`, `Build from source`, `Release verification`, `Known limitations`. Run it before the README exists.

```bash
make check-docs
```

Expected: nonzero exit listing missing sections.

- [ ] **Step 2: Write the README**

Include:

- one-sentence explanation; add a short demo GIF only after a real recording exists;
- installation from GitHub Release DMG/ZIP;
- exact Accessibility permission steps for macOS 13+;
- settings and six toast positions;
- system/Russian/English behavior;
- privacy guarantees;
- compatibility table linked to `docs/compatibility.md`;
- honest limitation that some apps expose neither AX selection nor usable synthetic copy;
- Homebrew prerequisites `xcodegen`, `swiftformat`, `swiftlint`;
- commands `make project`, `make test`, `make build`;
- SHA-256, `codesign`, `spctl` and `stapler` verification commands.

Do not include an absent screenshot or fake compatibility claims.

- [ ] **Step 3: Add MIT license and contributor rules**

Use the standard MIT License with copyright year 2026 and project owner `SelectCopy contributors`. In `AGENTS.md`, require TDD, privacy-safe logs, no clipboard history, no App Sandbox, macOS 13 floor, localized user-facing strings and no commits of signing secrets.

- [ ] **Step 4: Run docs check**

```bash
make check-docs
```

Expected: exit 0 with every required README section found.

- [ ] **Step 5: Commit documentation**

```bash
git add README.md LICENSE AGENTS.md Makefile
git commit -m "docs: add SelectCopy contributor guide"
```

---

### Task 15: Continuous integration

**Files:**
- Create: `.github/workflows/ci.yml`
- Modify: `Makefile`

**Interfaces:**
- Consumes: clean checkout on GitHub-hosted macOS runner.
- Produces: mandatory format, lint, unit/UI test and unsigned build checks.

- [ ] **Step 1: Add CI workflow syntax validation locally**

Install and run `actionlint`:

```bash
brew install actionlint
actionlint .github/workflows/ci.yml
```

Expected before file creation: nonzero exit because workflow is absent.

- [ ] **Step 2: Create the CI workflow**

Trigger on pull requests and pushes to `main`. Use a GitHub-hosted `macos-15` runner, `actions/checkout`, install `xcodegen swiftformat swiftlint`, select the runner's Xcode 16 installation, cache no DerivedData, and execute:

```bash
swiftformat --lint SelectCopy SelectCopyTests SelectCopyUITests
swiftlint lint --strict
make project
xcodebuild test -project SelectCopy.xcodeproj -scheme SelectCopy -destination 'platform=macOS'
xcodebuild build -project SelectCopy.xcodeproj -scheme SelectCopy -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Set job timeout to 20 minutes and cancel superseded pull-request runs through a concurrency group.

- [ ] **Step 3: Validate and reproduce CI locally**

```bash
actionlint .github/workflows/ci.yml
swiftformat --lint SelectCopy SelectCopyTests SelectCopyUITests
swiftlint lint --strict
make test
xcodebuild build -project SelectCopy.xcodeproj -scheme SelectCopy -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: all commands exit 0.

- [ ] **Step 4: Commit CI**

```bash
git add .github/workflows/ci.yml Makefile
git commit -m "ci: verify SelectCopy changes"
```

---

### Task 16: Signed, notarized GitHub release pipeline

**Files:**
- Create: `Scripts/package-release.sh`
- Create: `Scripts/verify-release.sh`
- Create: `.github/workflows/release.yml`
- Modify: `README.md`

**Interfaces:**
- Consumes: tag `v*`, Developer ID certificate and App Store Connect credentials from GitHub Secrets.
- Produces: notarized `SelectCopy.dmg`, `SelectCopy.zip`, `SHA256SUMS`, and a GitHub Release.

- [ ] **Step 1: Write package script validation first**

`package-release.sh` must reject missing `.app`, missing version, and non-Universal Binary input before creating artifacts. Verify failing behavior:

```bash
Scripts/package-release.sh /nonexistent/SelectCopy.app 1.0.0
```

Expected: nonzero exit and `Application not found`.

- [ ] **Step 2: Implement deterministic packaging**

The script must:

1. Validate both architectures using `lipo -archs`.
2. Create `release/SelectCopy-${VERSION}.zip` with `ditto -c -k --keepParent`.
3. Stage the app and an `Applications` symlink in a temporary directory made by `mktemp -d`.
4. Create a compressed read-only DMG with `hdiutil create`.
5. Write SHA-256 lines for ZIP and DMG to `release/SHA256SUMS` using `shasum -a 256`.
6. Remove only its explicit temporary directory through a trap.

- [ ] **Step 3: Implement release verification**

`verify-release.sh` accepts an app path and runs:

```bash
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"
xcrun stapler validate "$APP_PATH"
lipo -archs "$APP_PATH/Contents/MacOS/SelectCopy"
```

It fails unless the architecture output includes both `arm64` and `x86_64`.

- [ ] **Step 4: Create release workflow**

Trigger only on tags matching `v*`. The workflow must:

1. Check out the exact tag.
2. Install XcodeGen and generate the project.
3. Import base64-encoded Developer ID `.p12` into a temporary keychain.
4. Build an archive with `xcodebuild archive` for generic macOS destination.
5. Export the Developer ID app with an explicit ExportOptions plist generated inside the runner.
6. Submit the ZIP to `xcrun notarytool submit --wait` using App Store Connect key ID and issuer ID.
7. Staple the ticket to the `.app`.
8. Run `Scripts/verify-release.sh`.
9. Run `Scripts/package-release.sh`.
10. Publish artifacts through `gh release create` using generated release notes.
11. Delete the temporary keychain in an `always()` cleanup step.

Use exact secret names:

```text
DEVELOPER_ID_APPLICATION_P12_BASE64
DEVELOPER_ID_APPLICATION_P12_PASSWORD
APPLE_TEAM_ID
APP_STORE_CONNECT_KEY_ID
APP_STORE_CONNECT_ISSUER_ID
APP_STORE_CONNECT_PRIVATE_KEY
```

- [ ] **Step 5: Validate scripts and workflow without secrets**

```bash
bash -n Scripts/package-release.sh Scripts/verify-release.sh
shellcheck Scripts/package-release.sh Scripts/verify-release.sh
actionlint .github/workflows/release.yml
```

Expected: all static checks exit 0.

- [ ] **Step 6: Produce an unsigned local release-shaped artifact**

```bash
xcodebuild archive -project SelectCopy.xcodeproj -scheme SelectCopy -configuration Release \
  -destination 'generic/platform=macOS' -archivePath build/SelectCopy.xcarchive CODE_SIGNING_ALLOWED=NO
```

Confirm the archived executable is Universal. Skip `spctl` and notarization locally because the build is intentionally unsigned.

- [ ] **Step 7: Document release setup and first-release procedure**

Add to README: Apple Developer Program requirement, secret names, tag format, local signature verification and Gatekeeper verification. State clearly that source builds can be unsigned but public binaries must pass signing and notarization.

- [ ] **Step 8: Commit release automation**

```bash
git add Scripts .github/workflows/release.yml README.md
git commit -m "ci: automate signed macOS releases"
```

---

### Task 17: Final verification and v1.0.0 release candidate

**Files:**
- Modify: `docs/compatibility.md`
- Modify: `docs/manual-test-checklist.md`
- Modify: `README.md`
- Modify: `project.yml`

**Interfaces:**
- Consumes: complete application and all automated/manual checks.
- Produces: evidence-backed release candidate with version `1.0.0`.

- [ ] **Step 1: Set release version**

Set `MARKETING_VERSION: 1.0.0` and `CURRENT_PROJECT_VERSION: 1` in `project.yml`, regenerate the project, and confirm the built app reports `1.0.0 (1)` in Settings.

- [ ] **Step 2: Run the complete automated gate**

```bash
make project
swiftformat --lint SelectCopy SelectCopyTests SelectCopyUITests
swiftlint lint --strict
make test
xcodebuild build -project SelectCopy.xcodeproj -scheme SelectCopy -configuration Release -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
bash -n Scripts/package-release.sh Scripts/verify-release.sh
shellcheck Scripts/package-release.sh Scripts/verify-release.sh
actionlint .github/workflows/*.yml
git diff --check
```

Expected: every command exits 0.

- [ ] **Step 3: Run the final manual behavior gate**

Complete every unchecked row in `docs/manual-test-checklist.md`, including two displays, six toast positions, light/dark, reduced motion, increased contrast, VoiceOver, sleep/wake, revoked permission, login item and the full app compatibility matrix. Record failures as GitHub issues; do not mark the release ready while a privacy, secure-field, clipboard-corruption or focus-stealing defect remains.

- [ ] **Step 4: Test a signed release candidate before tagging**

Run the release workflow through a temporary prerelease tag `v1.0.0-rc.1`. Download artifacts on a clean macOS user account, verify SHA-256, mount the DMG, drag the app to Applications, grant Accessibility permission, and repeat the TextEdit smoke scenario. Confirm `spctl`, `codesign` and `stapler` validation pass.

- [ ] **Step 5: Update documentation with observed results**

Replace assumptions in compatibility documentation with measured results and attach real screenshots or a short demo only after capture. Keep unsupported applications explicit.

- [ ] **Step 6: Commit release-candidate metadata**

```bash
git add project.yml SelectCopy.xcodeproj README.md docs
git commit -m "chore: prepare SelectCopy 1.0.0"
```

- [ ] **Step 7: Create the final tag only after approval**

```bash
git tag -a v1.0.0 -m "SelectCopy 1.0.0"
git push origin main v1.0.0
```

Expected: GitHub release workflow publishes signed, notarized DMG/ZIP and SHA-256 checksums; release verification succeeds on a clean Mac.
