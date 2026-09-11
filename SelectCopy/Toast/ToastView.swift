import SwiftUI

struct ToastView: View {
    let content: ToastContent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .accessibilityHidden(true)
            if case let .text(text) = content {
                Text(text)
                    .lineLimit(1)
            }
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, content == .iconOnly ? 10 : 12)
        .frame(minHeight: 34)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .shadow(radius: 12, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content == .iconOnly ? "Copied" : (content.textValue ?? "Copied"))
    }
}

private extension ToastContent {
    var textValue: String? {
        if case let .text(text) = self { return text }
        return nil
    }
}
