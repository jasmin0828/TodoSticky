import SwiftUI

struct SettingsColorControl: View {
    let selectedColor: StickyColor
    let onSelect: (StickyColor) -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 8) {
            ForEach(StickyColor.allCases) { color in
                Button {
                    onSelect(color)
                } label: {
                    ZStack {
                        Circle()
                            .fill(color.color)
                            .overlay {
                                Circle()
                                    .stroke(.primary.opacity(0.18), lineWidth: 1)
                            }

                        if color == selectedColor {
                            Image(systemName: "checkmark")
                                .font(.body.bold())
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .overlay {
                        if color == selectedColor {
                            Circle()
                                .stroke(.primary, lineWidth: 2)
                                .padding(-3)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(color.title(locale: locale)))
                .accessibilityValue(
                    Text(
                        LocalizedStringKey(
                            color == selectedColor
                                ? "settings.color.selected"
                                : "settings.color.notSelected"
                        )
                    )
                )
                .accessibilityAddTraits(color == selectedColor ? .isSelected : [])
                .help(Text(color.title(locale: locale)))
            }
        }
    }
}
