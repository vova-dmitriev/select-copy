import ApplicationServices
import OSLog

enum AXStringValue: Equatable {
    case value(String)
    case error(AXError)
}

struct AccessibilityElementSnapshot: Equatable {
    let role: String?
    let subrole: String?
    let selectedText: AXStringValue
}

enum AccessibilitySnapshotResult: Equatable {
    case value(AccessibilityElementSnapshot)
    case error(AXError)
}

protocol AccessibilityQuerying {
    func focusedElementSnapshot() -> AccessibilitySnapshotResult
    func selectionElementSnapshot(at point: CGPoint) -> AccessibilitySnapshotResult
}

extension AccessibilityQuerying {
    func selectionElementSnapshot(at point: CGPoint) -> AccessibilitySnapshotResult {
        focusedElementSnapshot()
    }
}

struct SystemAccessibilityQuery: AccessibilityQuerying {
    private let logger = Logger(subsystem: "com.selectcopy.app", category: "selection")
    func selectionElementSnapshot(at point: CGPoint) -> AccessibilitySnapshotResult {
        let system = AXUIElementCreateSystemWide()
        var hit: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &hit)
        guard error == .success, let initialElement = hit else { return .error(error) }
        var element = initialElement
        var snapshots: [AccessibilityElementSnapshot] = []
        for _ in 0..<16 {
            snapshots.append(snapshot(element: element))
            var parentValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, "AXParent" as CFString, &parentValue) == .success,
                  let parentValue, CFGetTypeID(parentValue) == AXUIElementGetTypeID() else { break }
            element = unsafeDowncast(parentValue, to: AXUIElement.self)
        }
        let result = AccessibilitySelectionResolver.resolve(snapshots)
        let roles = snapshots.compactMap(\.role).joined(separator: "/")
        logger.notice("Mouse selection role chain: \(roles, privacy: .public)")
        return result
    }

    private func snapshot(element: AXUIElement) -> AccessibilityElementSnapshot {
        AccessibilityElementSnapshot(
            role: optionalString(attribute: "AXRole", element: element),
            subrole: optionalString(attribute: "AXSubrole", element: element),
            selectedText: stringValue(attribute: "AXSelectedText", element: element)
        )
    }

    func focusedElementSnapshot() -> AccessibilitySnapshotResult {
        let systemElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let focusedError = AXUIElementCopyAttributeValue(
            systemElement,
            "AXFocusedUIElement" as CFString,
            &focusedValue
        )

        guard focusedError == .success else {
            return .error(focusedError)
        }
        guard let focusedValue, CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return .error(.noValue)
        }

        let focusedElement = unsafeDowncast(focusedValue, to: AXUIElement.self)
        return .value(
            AccessibilityElementSnapshot(
                role: self.optionalString(attribute: "AXRole", element: focusedElement),
                subrole: self.optionalString(attribute: "AXSubrole", element: focusedElement),
                selectedText: self.stringValue(attribute: "AXSelectedText", element: focusedElement)
            )
        )
    }

    private func optionalString(attribute: String, element: AXUIElement) -> String? {
        guard case let .value(value) = stringValue(attribute: attribute, element: element) else {
            return nil
        }
        return value
    }

    private func stringValue(attribute: String, element: AXUIElement) -> AXStringValue {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else {
            return .error(error)
        }
        guard let string = value as? String else {
            return .error(.cannotComplete)
        }
        return .value(string)
    }
}

enum SelectionReadResult: Equatable {
    case text(String)
    case empty
    case secure
    case unsupported(fallbackAllowed: Bool)
    case failure(AXError)
}

protocol SelectionReading {
    func readSelection() -> SelectionReadResult
    func readSelection(at point: CGPoint?) -> SelectionReadResult
}

extension SelectionReading {
    func readSelection(at point: CGPoint?) -> SelectionReadResult { readSelection() }
}

struct AccessibilitySelectionReader: SelectionReading {
    private static let fallbackRoles: Set<String> = [
        "AXDocument",
        "AXStaticText",
        "AXTextArea",
        "AXTextField",
        "AXWebArea",
    ]

    private let query: AccessibilityQuerying

    init(query: AccessibilityQuerying = SystemAccessibilityQuery()) {
        self.query = query
    }

    func readSelection() -> SelectionReadResult {
        switch self.query.focusedElementSnapshot() {
        case let .error(error):
            .failure(error)
        case let .value(snapshot):
            self.map(snapshot)
        }
    }

    func readSelection(at point: CGPoint?) -> SelectionReadResult {
        guard let point else { return readSelection() }
        switch query.selectionElementSnapshot(at: point) {
        case let .error(error): return .failure(error)
        case let .value(snapshot): return map(snapshot, allowEmptyFallback: true)
        }
    }

    private func map(
        _ snapshot: AccessibilityElementSnapshot,
        allowEmptyFallback: Bool = false
    ) -> SelectionReadResult {
        guard snapshot.subrole != "AXSecureTextField" else {
            return .secure
        }
        let canFallback = Self.fallbackRoles.contains(snapshot.role ?? "")
            || (allowEmptyFallback && ["AXScrollArea", "AXGroup"].contains(snapshot.role ?? ""))

        switch snapshot.selectedText {
        case let .value(text):
            if text.isEmpty, allowEmptyFallback, canFallback {
                return .unsupported(fallbackAllowed: true)
            }
            return text.isEmpty ? .empty : .text(text)
        case .error(.noValue):
            if allowEmptyFallback, canFallback {
                return .unsupported(fallbackAllowed: true)
            }
            return .empty
        case .error(.attributeUnsupported), .error(.notImplemented):
            return .unsupported(fallbackAllowed: canFallback)
        case let .error(error):
            return .failure(error)
        }
    }
}
