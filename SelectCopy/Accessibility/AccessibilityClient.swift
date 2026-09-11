import ApplicationServices

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
}

struct SystemAccessibilityQuery: AccessibilityQuerying {
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

    private func map(_ snapshot: AccessibilityElementSnapshot) -> SelectionReadResult {
        guard snapshot.subrole != "AXSecureTextField" else {
            return .secure
        }

        switch snapshot.selectedText {
        case let .value(text):
            return text.isEmpty ? .empty : .text(text)
        case .error(.noValue):
            return .empty
        case .error(.attributeUnsupported), .error(.notImplemented):
            return .unsupported(fallbackAllowed: Self.fallbackRoles.contains(snapshot.role ?? ""))
        case let .error(error):
            return .failure(error)
        }
    }
}
