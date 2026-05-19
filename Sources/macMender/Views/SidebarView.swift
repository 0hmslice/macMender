import SwiftUI

struct SidebarView: View {
    @Binding var selection: SettingsSection

    var body: some View {
        List(SettingsSection.allCases, selection: $selection) { section in
            HStack(spacing: 10) {
                Image(systemName: section.symbolName)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(section.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .contentShape(.rect)
            .onTapGesture {
                selection = section
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(selection == section ? [.isSelected] : [])
            .tag(section)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        }
        .listStyle(.sidebar)
    }
}
