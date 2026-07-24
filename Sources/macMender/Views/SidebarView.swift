import SwiftUI

struct SidebarView: View {
    @Binding var selection: SettingsSection

    var body: some View {
        List(selection: $selection) {
            ForEach(SettingsSection.allCases) { section in
                Label(section.title, systemImage: section.symbolName)
                    .tag(section)
                    .help(section.subtitle)
            }
        }
        .listStyle(.sidebar)
        .accessibilityLabel("macMender sections")
    }
}
