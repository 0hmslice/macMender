import SwiftUI

struct SidebarView: View {
    @Binding var selection: SettingsSection
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
        .background { SidebarBackdrop().ignoresSafeArea() }
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

/// Frosted glass that shows what is behind the window.
///
/// The system's sidebar glass picks up almost nothing of what is behind the window: over a pure
/// red backdrop it measured a neutral dark grey. This blends with what is behind the window
/// instead, using the popover material, which lets about half of it through while keeping the
/// sidebar's text readable. It stays active so the sidebar does not turn solid when the window
/// loses focus.
private struct SidebarBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
