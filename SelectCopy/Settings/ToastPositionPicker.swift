import SwiftUI

struct ToastPositionPicker: View {
    @Binding var selection: ToastPosition
    @ObservedObject var localizer: Localizer
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 10) {
                ToastPositionThumbnail(position: selection)
                    .frame(width: 64, height: 42)
                Text(title(selection))
                Spacer()
                Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(width: 245)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizer.text("settings.toastPosition"))
        .accessibilityValue(title(selection))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text(localizer.text("settings.choosePosition")).font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(104)), count: 3), spacing: 12) {
                    ForEach(ToastPosition.allCases) { position in
                        Button {
                            selection = position
                            isPresented = false
                        } label: {
                            VStack(spacing: 7) {
                                ToastPositionThumbnail(position: position)
                                    .frame(width: 90, height: 60)
                                Text(title(position)).font(.caption).lineLimit(2)
                                    .frame(height: 28)
                            }
                            .padding(6)
                            .background(
                                selection == position ? Color.accentColor.opacity(0.12) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 9)
                            )
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(
                                selection == position ? Color.accentColor : Color.clear, lineWidth: 2
                            ))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(title(position))
                        .accessibilityAddTraits(selection == position ? .isSelected : [])
                    }
                }
            }
            .padding(16)
        }
    }

    private func title(_ position: ToastPosition) -> String {
        localizer.text("toast.position.\(position.rawValue)")
    }
}

struct ToastPositionThumbnail: View {
    let position: ToastPosition

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let toastSize = CGSize(width: size.width * 0.37, height: size.height * 0.22)
            let toastFrame = position.frame(
                for: toastSize,
                in: CGRect(origin: .zero, size: size),
                inset: size.width * 0.07
            )
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.18)))
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(Color.secondary.opacity(0.5)).frame(width: 3, height: 3)
                    }
                    Spacer()
                }
                .padding(5)
                Capsule()
                    .fill(Color.accentColor)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                    )
                    .frame(width: toastSize.width, height: toastSize.height)
                    .position(x: toastFrame.midX, y: size.height - toastFrame.midY)
            }
        }
        .accessibilityHidden(true)
    }
}
