import SwiftUI

struct SidebarView: View {
    @Binding var selection: SettingsSection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    let isSelected = selection == section
                    HStack(spacing: 11) {
                        Image(systemName: section.symbolName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(isSelected ? .primary : .primary)
                                .lineLimit(1)
                            Text(section.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.thinMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.075))
                                }
                                .overlay(alignment: .topLeading) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(.white.opacity(0.22), lineWidth: 1)
                                }
                                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
                        }
                    }
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.11), value: isSelected)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(selection == section ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
