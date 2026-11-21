import SwiftUI

struct SidebarView: View {
    @Binding var selection: SettingsSection
    /// 0 is a solid sidebar, 1 is fully glass.
    var glass: Double
    @State private var searchText = ""

    var body: some View {
        let matches = SettingsSection.matching(searchText)

        List(selection: $selection) {
            ForEach(SettingsSection.Group.allCases) { group in
                let sections = matches.filter { $0.group == group }
                if !sections.isEmpty {
                    Section {
                        ForEach(sections) { section in
                            Label {
                                Text(section.title)
                            } icon: {
                                SettingsIconTile(systemImage: section.symbolName, tint: section.tint, size: 20)
                            }
                            .tag(section)
                        }
                    } header: {
                        if let title = group.title {
                            Text(title)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background { SidebarGlassBackground(amount: glass) }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
        .overlay {
            if matches.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .onSubmit(of: .search) {
            if let match = matches.first { selection = match }
        }
        .accessibilityLabel("macMender sections")
    }
}
