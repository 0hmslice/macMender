import SwiftUI

struct SidebarView: View {
    @Binding var selection: SettingsSection
    @State private var searchText = ""

    var body: some View {
        List(selection: $selection) {
            ForEach(SettingsSection.matching(searchText)) { section in
                Label(section.title, systemImage: section.symbolName)
                    .tag(section)
                    .help(section.subtitle)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search settings")
        .overlay {
            if SettingsSection.matching(searchText).isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .onSubmit(of: .search) {
            if let match = SettingsSection.matching(searchText).first { selection = match }
        }
        .accessibilityLabel("macMender sections")
    }
}
