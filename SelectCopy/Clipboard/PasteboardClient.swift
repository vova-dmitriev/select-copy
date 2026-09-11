import AppKit

struct PasteboardSnapshot: Equatable, Sendable {
    let items: [[String: Data]]
}

@MainActor
protocol PasteboardServicing: AnyObject {
    var changeCount: Int { get }
    func writeText(_ text: String) -> Bool
    func readText() -> String?
    func snapshot() -> PasteboardSnapshot
    func restore(_ snapshot: PasteboardSnapshot) -> Bool
}

@MainActor
final class PasteboardClient: PasteboardServicing {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        self.pasteboard.changeCount
    }

    func writeText(_ text: String) -> Bool {
        self.pasteboard.clearContents()
        return self.pasteboard.setString(text, forType: .string)
    }

    func readText() -> String? {
        self.pasteboard.string(forType: .string)
    }

    func snapshot() -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.reduce(into: [String: Data]()) { values, type in
                if let data = item.data(forType: type) {
                    values[type.rawValue] = data
                }
            }
        }
        return PasteboardSnapshot(items: items)
    }

    func restore(_ snapshot: PasteboardSnapshot) -> Bool {
        self.pasteboard.clearContents()
        guard !snapshot.items.isEmpty else {
            return true
        }

        let items = snapshot.items.map { values in
            let item = NSPasteboardItem()
            for (rawType, data) in values {
                item.setData(data, forType: NSPasteboard.PasteboardType(rawType))
            }
            return item
        }
        return self.pasteboard.writeObjects(items)
    }
}
