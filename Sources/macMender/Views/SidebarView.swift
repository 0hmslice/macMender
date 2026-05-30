import SwiftUI

struct SidebarView: View {
    @Binding var selection: SettingsSection
    @Namespace private var selectionNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    withAnimation(LiquidGlassMotion.quick) {
                        selection = section
                    }
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: section.symbolName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(selection == section ? .white : .secondary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(selection == section ? .white : .primary)
                                .lineLimit(1)
                            Text(section.subtitle)
                                .font(.caption)
                                .foregroundStyle(selection == section ? .white.opacity(0.78) : .secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        if selection == section {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.blue.gradient)
                                .matchedGeometryEffect(id: "sidebar-selection", in: selectionNamespace)
                                .shadow(color: .blue.opacity(0.24), radius: 10, y: 4)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(selection == section ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .liquidGlass(.sidebar)
    }
}
