import SwiftUI

struct MenuBarManagementView: View {
    @ObservedObject var appModel: AppModel
    @State private var searchText = ""

    var body: some View {
        PreferencesScrollView {
            SectionCard(
                title: "Menu Bar Hiding",
                subtitle: "Choose which status icons stay visible, hide until hover, or remain tucked away.",
                symbolName: "menubar.rectangle"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        CapabilityBadge(
                            title: appModel.menuBarScanner.lastScanDescription,
                            systemImage: "scope",
                            tone: appModel.menuBarScanner.detectedItems.isEmpty ? .warning : .active
                        )
                        CapabilityBadge(
                            title: hiddenStatusTitle,
                            systemImage: appModel.hiddenMenuBarItemCount == 0 ? "eye" : "eye.slash",
                            tone: appModel.hiddenMenuBarItemCount == 0 ? .neutral : .active
                        )
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Toggle("Enable menu bar hiding", isOn: Binding(
                            get: { appModel.store.config.featureToggles.menuBarManagement },
                            set: { value in
                                appModel.store.config.featureToggles.menuBarManagement = value
                                appModel.store.save()
                                appModel.updateRuntime()
                            }
                        ))

                        Spacer()

                        Button {
                            appModel.menuBarScanner.refresh(force: true)
                        } label: {
                            Label("Scan Now", systemImage: "arrow.clockwise")
                        }
                    }

                    Text("Hidden icons reveal when the pointer moves over Mendy or empty menu-bar space. You can also click empty menu-bar space or swipe/scroll in the menu bar. macMender automatically rehides them when the pointer leaves.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            SectionCard(
                title: "Arrange Icons",
                subtitle: "Drag icons between sections or use the segmented control on each row.",
                symbolName: "square.grid.3x1.below.line.grid.1x2"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search menu bar icons", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if appModel.menuBarScanner.detectedItems.isEmpty {
                        EmptyMenuBarItemsView()
                    } else if filteredHideCandidateItems.isEmpty {
                        EmptySearchView()
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(MenuBarSection.allCases) { section in
                                MenuBarSectionColumn(
                                    section: section,
                                    items: items(in: section),
                                    allItems: hideCandidateItems,
                                    appModel: appModel
                                )
                            }
                        }
                    }

                    if !systemManagedItems.isEmpty {
                        Divider()
                        Text("Managed by macOS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 8) {
                            ForEach(systemManagedItems) { item in
                                SystemManagedMenuBarRow(item: item)
                            }
                        }
                    }

                    if !hiddenSelectionsMissingFromScan.isEmpty {
                        Divider()
                        Text("Stored hidden selections")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 8) {
                            ForEach(hiddenSelectionsMissingFromScan) { item in
                                StoredHiddenMenuBarRow(item: item) {
                                    appModel.setStoredMenuBarItemVisible(item)
                                }
                            }
                        }
                    }
                }
            }

            SectionCard(
                title: "Reveal Behavior",
                subtitle: "These controls mirror the menu-bar behavior so it is obvious what macMender is doing.",
                symbolName: "cursorarrow.motionlines"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Automatically rehide icons", isOn: Binding(
                        get: { appModel.store.config.menuBarLayout.autoRehideEnabled },
                        set: { value in
                            appModel.updateMenuBarLayout { $0.autoRehideEnabled = value }
                        }
                    ))

                    HStack {
                        Text("Rehide delay")
                        Slider(value: Binding(
                            get: { appModel.store.config.menuBarLayout.autoRehideDelay },
                            set: { value in
                                appModel.updateMenuBarLayout { $0.autoRehideDelay = value }
                            }
                        ), in: 0.4...4.0, step: 0.1)
                        Text(appModel.store.config.menuBarLayout.autoRehideDelay.formatted(.number.precision(.fractionLength(1))) + "s")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }

                    Toggle("Show section divider ticks", isOn: Binding(
                        get: { appModel.store.config.menuBarLayout.showSectionDividers },
                        set: { value in
                            appModel.updateMenuBarLayout { $0.showSectionDividers = value }
                        }
                    ))

                    HStack {
                        Text("Item spacing")
                        Slider(value: Binding(
                            get: { Double(appModel.store.config.menuBarLayout.itemSpacingOffset) },
                            set: { value in
                                appModel.updateMenuBarLayout { $0.itemSpacingOffset = Int(value.rounded()) }
                            }
                        ), in: -10...16, step: 1)
                        Text("\(appModel.store.config.menuBarLayout.itemSpacingOffset)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .trailing)
                        Button(appModel.menuBarScanner.isApplyingSpacing ? "Applying..." : "Apply") {
                            appModel.applyMenuBarSpacing()
                        }
                        .disabled(appModel.menuBarScanner.isApplyingSpacing)
                    }

                    Text(appModel.menuBarScanner.spacingStatusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            appModel.menuBarScanner.refresh()
        }
    }

    private var hiddenStatusTitle: String {
        let count = appModel.hiddenMenuBarItemCount
        if count == 0 { return "Nothing hidden" }
        return count == 1 ? "1 managed icon" : "\(count) managed icons"
    }

    private var hiddenSelectionsMissingFromScan: [MenuBarItemModel] {
        let detectedKeys = Set(appModel.menuBarScanner.detectedItems.map(\.sectionKey))
        return appModel.hiddenMenuBarSelections.filter { !detectedKeys.contains($0.bundleIdentifier) }
    }

    private var hideCandidateItems: [DetectedMenuBarItem] {
        appModel.menuBarScanner.detectedItems.filter(\.isHideCandidate)
    }

    private var filteredHideCandidateItems: [DetectedMenuBarItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return hideCandidateItems }
        return hideCandidateItems.filter { item in
            item.displayTitle.lowercased().contains(query) ||
                item.ownerName.lowercased().contains(query) ||
                (item.sourceBundleIdentifier ?? "").lowercased().contains(query)
        }
    }

    private func items(in section: MenuBarSection) -> [DetectedMenuBarItem] {
        filteredHideCandidateItems.filter { appModel.menuBarSection(for: $0) == section }
    }

    private var systemManagedItems: [DetectedMenuBarItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let items = appModel.menuBarScanner.detectedItems.filter { !$0.isHideCandidate }
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.displayTitle.lowercased().contains(query) ||
                $0.ownerName.lowercased().contains(query) ||
                ($0.sourceBundleIdentifier ?? "").lowercased().contains(query)
        }
    }
}

private struct MenuBarSectionColumn: View {
    var section: MenuBarSection
    var items: [DetectedMenuBarItem]
    var allItems: [DetectedMenuBarItem]
    @ObservedObject var appModel: AppModel
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(section.title)
                    .font(.callout.weight(.semibold))
                Spacer()
                Text("\(items.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: Capsule())
            }

            Text(section.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 38, alignment: .topLeading)

            VStack(spacing: 8) {
                if items.isEmpty {
                    Text("Drop icons here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 74)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    ForEach(items) { item in
                        MenuBarItemSectionRow(item: item, section: Binding(
                            get: { appModel.menuBarSection(for: item) },
                            set: { appModel.setMenuBarSection(item, section: $0) }
                        ))
                        .draggable(item.id)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .top)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(dropTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(dropTargeted ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: 1)
        }
        .dropDestination(for: String.self) { values, _ in
            guard let id = values.first,
                  let item = allItems.first(where: { $0.id == id }) else {
                return false
            }
            appModel.setMenuBarSection(item, section: section)
            return true
        } isTargeted: { targeted in
            dropTargeted = targeted
        }
    }
}

private struct MenuBarItemSectionRow: View {
    var item: DetectedMenuBarItem
    @Binding var section: MenuBarSection

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Circle()
                    .fill(section == .pinned ? Color.secondary.opacity(0.16) : Color.orange.opacity(0.2))
                    .overlay {
                        Text(String(item.displayTitle.prefix(1)).uppercased())
                            .font(.caption.bold())
                    }
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(sourceSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            Picker("Section", selection: $section) {
                ForEach(MenuBarSection.allCases) { section in
                    Text(section.shortTitle).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(section == .pinned ? Color.primary.opacity(0.08) : Color.orange.opacity(0.26), lineWidth: 1)
        }
        .help(item.controllabilityDescription)
    }

    private var sourceSubtitle: String {
        let display = item.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let owner = item.ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bundle = item.sourceBundleIdentifier, !bundle.isEmpty, owner == display {
            return bundle
        }
        if !owner.isEmpty, owner != display {
            return owner
        }
        return item.controllabilityDescription
    }
}

private struct SystemManagedMenuBarRow: View {
    var item: DetectedMenuBarItem

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.secondary.opacity(0.16))
                .overlay {
                    Image(systemName: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(item.controllabilityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Visible")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: Capsule())
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct StoredHiddenMenuBarRow: View {
    var item: MenuBarItemModel
    var showAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.18))
                .overlay {
                    Image(systemName: item.section == .hidden ? "eye.trianglebadge.exclamationmark" : "eye.slash")
                        .font(.caption)
                }
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(item.section.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Show") {
                showAction()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.orange.opacity(0.24), lineWidth: 1)
        }
    }
}

private struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("No matching hideable icons")
                .font(.callout.weight(.medium))
            Text("System-managed icons may still appear below when they match your search.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct EmptyMenuBarItemsView: View {
    var body: some View {
        VStack(spacing: 10) {
            MendyAvatarView(mood: .empty, size: 54)
            Text("No menu-bar icons detected")
                .font(.callout.weight(.medium))
            Text("Grant Accessibility, then press Scan Now after the apps you want to manage are running.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }
}
