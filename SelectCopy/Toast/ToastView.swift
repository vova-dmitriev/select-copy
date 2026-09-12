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
        .padding(.horizontal, self.content == .iconOnly ? 10 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: self.content.alignment)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(self.content == .iconOnly ? "Copied" : (self.content.textValue ?? "Copied"))
    }
}

extension ToastContent {
    var alignment: Alignment {
        self == .iconOnly ? .center : .leading
    }

    fileprivate var textValue: String? {
        if case let .text(text) = self {
            return text
        }
        return nil
    }
}
