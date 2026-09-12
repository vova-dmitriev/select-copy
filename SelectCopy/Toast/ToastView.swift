import SwiftUI

struct ToastView: View {
    let content: ToastContent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.55, green: 0.83, blue: 0.68))
                .frame(width: 16)
                .accessibilityHidden(true)
            if case let .text(text) = content {
                Text(text)
                    .lineLimit(1)
                    .foregroundStyle(Color.white.opacity(0.94))
            }
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, self.content == .iconOnly ? 10 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: self.content.alignment)
        .background(
            Color(red: 0.13, green: 0.15, blue: 0.17).opacity(0.9),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
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
