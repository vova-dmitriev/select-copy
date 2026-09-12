import ApplicationServices

enum AccessibilitySelectionResolver {
    private static let textRoles: Set<String> = [
        "AXDocument", "AXStaticText", "AXTextArea", "AXTextField", "AXWebArea",
    ]

    static func resolve(_ snapshots: [AccessibilityElementSnapshot]) -> AccessibilitySnapshotResult {
        if let secure = snapshots.first(where: { $0.subrole == "AXSecureTextField" }) {
            return .value(secure)
        }
        var textCandidate: AccessibilityElementSnapshot?
        for snapshot in snapshots where textRoles.contains(snapshot.role ?? "") {
            if case let .value(text) = snapshot.selectedText, !text.isEmpty { return .value(snapshot) }
            textCandidate = textCandidate ?? snapshot
        }
        let containerCandidate = snapshots.first {
            ["AXScrollArea", "AXGroup"].contains($0.role ?? "")
        }
        guard let result = textCandidate ?? containerCandidate ?? snapshots.first else { return .error(.noValue) }
        return .value(result)
    }
}
