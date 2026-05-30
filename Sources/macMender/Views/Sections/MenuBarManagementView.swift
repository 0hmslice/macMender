import AppKit
import ScreenCaptureKit
import SwiftUI

private let mendyStatusItemDragID = "macmender.status-item.mendy"
private let menuBarLayoutDragCoordinateSpace = "macmender.menuBarLayout.drag"

private enum MenuBarLayoutMotion {
    static func lane(reduceMotion: Bool) -> Animation? {
        reduceMotion ? .easeInOut(duration: 0.08) : .interactiveSpring(response: 0.24, dampingFraction: 0.82)
    }

    static func drop(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.08) : .spring(response: 0.28, dampingFraction: 0.84)
    }

    static func hover(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.14)
    }
}

private struct MenuBarDragPreviewState: Equatable {
    var id: String
    var item: DetectedMenuBarItem?
    var isMendy: Bool
    var location: CGPoint
    var targetSection: MenuBarSection

    var chipWidth: CGFloat {
        if isMendy { return 52 }
        if let item {
            return MenuBarChipMetrics(item: item, isHovered: true).chipWidth
        }
        return MenuBarChipMetrics.defaultCompactWidth
    }
}

private struct PendingMenuBarDisplayMove: Equatable {
    var section: MenuBarSection
    var beforeItemID: String?
    var expiresAt: Date
}

private struct MenuBarLaneFramePreferenceKey: PreferenceKey {
    static let defaultValue: [MenuBarSection: CGRect] = [:]

    static func reduce(value: inout [MenuBarSection: CGRect], nextValue: () -> [MenuBarSection: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct MenuBarManagementView: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searchText = ""
    @State private var showingResetLayoutConfirmation = false
    @State private var activeDraggedItemID: String?
    @State private var activeDropSection: MenuBarSection?
    @State private var activeInsertionSection: MenuBarSection?
    @State private var activeInsertionIndex: Int?
    @State private var dragPreview: MenuBarDragPreviewState?
    @State private var laneFrames: [MenuBarSection: CGRect] = [:]
    @State private var pendingDisplayMoves: [String: PendingMenuBarDisplayMove] = [:]
    @Namespace private var chipNamespace

    var body: some View {
        PreferencesScrollView {
            SectionCard(
                title: "Menu Bar Layout",
                subtitle: appModel.menuBarScanner.physicalMovementEnabled ? "Drag icons into Visible, Hidden, or Always Hidden. Mendy keeps the bar tidy until you need something." : "Discovery is available. Physical hide, reveal, and reorder controls are disabled until the real Thaw runtime is transplanted.",
                symbolName: "menubar.rectangle"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        MendyAvatarView(mood: .thinking, size: MendyAvatarSize.panel)

                        VStack(alignment: .leading, spacing: 7) {
                            Text(appModel.menuBarScanner.physicalMovementEnabled ? "Arrange your menu-bar icons into calm, predictable lanes." : "Review detected menu-bar icons without moving them.")
                                .font(.title3.weight(.semibold))
                            Text(appModel.menuBarScanner.physicalMovementEnabled ? "Visible icons stay in the menu bar. Hidden icons reveal from the zone around Mendy. Always Hidden waits until you explicitly ask for it." : appModel.menuBarScanner.physicalMovementStatusDescription)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    }

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
                        CapabilityBadge(
                            title: appModel.permissions.screenRecording == .granted ? "Live order sync" : "Live order limited",
                            systemImage: appModel.permissions.screenRecording == .granted ? "dot.viewfinder" : "lock",
                            tone: appModel.permissions.screenRecording == .granted ? .active : .warning
                        )
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Toggle("Let Mendy manage menu-bar icons", isOn: Binding(
                            get: { appModel.store.config.featureToggles.menuBarManagement },
                            set: { value in
                                appModel.store.config.featureToggles.menuBarManagement = value
                                appModel.store.save()
                                appModel.updateRuntime()
                            }
                        ))

                        Spacer()

                        Button {
                            appModel.scanMenuBarItems()
                        } label: {
                            Label("Scan Now", systemImage: "arrow.clockwise")
                        }
                    }

                    Text("Hidden icons reveal from the zone around Mendy using the triggers below. macMender keeps macOS-fixed icons read-only and only offers icons backed by real movable status items.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if !appModel.menuBarScanner.physicalMovementEnabled {
                        MenuBarMovementDisabledBanner()
                    }
                }
            }

            SectionCard(
                title: "Layout Lanes",
                subtitle: "Drop icons exactly where you want them. Existing order stays put unless you drag.",
                symbolName: "square.grid.3x1.below.line.grid.1x2"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    MenuBarSearchField(searchText: $searchText)

                    if appModel.permissions.screenRecording != .granted {
                        LiveOrderingPermissionBanner(
                            requestAction: { appModel.permissions.requestScreenRecording() },
                            settingsAction: { appModel.permissions.openScreenRecordingSettings() }
                        )
                    }

                    if appModel.menuBarScanner.detectedItems.isEmpty {
                        EmptyMenuBarItemsView()
                    } else if filteredHideCandidateItems.isEmpty {
                        EmptySearchView()
                    } else {
                        VStack(spacing: 18) {
                            ForEach(MenuBarSection.allCases) { section in
                                MenuBarLayoutLane(
                                    section: section,
                                    items: items(in: section),
                                    allItems: hideCandidateItems,
                                    mendyInsertionIndex: section == .pinned ? mendyInsertionIndex(in: items(in: section)) : nil,
                                    appModel: appModel,
                                    movementEnabled: appModel.menuBarScanner.physicalMovementEnabled,
                                    reduceMotion: reduceMotion,
                                    chipNamespace: chipNamespace,
                                    activeDraggedItemID: $activeDraggedItemID,
                                    activeDropSection: $activeDropSection,
                                    activeInsertionSection: $activeInsertionSection,
                                    activeInsertionIndex: $activeInsertionIndex,
                                    dragPreview: $dragPreview,
                                    pendingDisplayMoves: $pendingDisplayMoves,
                                    laneFrames: laneFrames
                                )
                            }
                        }
                        .animation(layoutAnimation, value: laneAnimationKey)
                    }

                    MenuBarResetLayoutCard {
                        showingResetLayoutConfirmation = true
                    }

                    if !systemManagedItems.isEmpty {
                        Divider()
                        Text("Fixed by macOS")
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
                title: "Reveal and Spacing",
                subtitle: appModel.menuBarScanner.physicalMovementEnabled ? "Choose how Hidden icons come back when you need them." : "Reveal settings are disabled because physical menu-bar hiding is disabled.",
                symbolName: "cursorarrow.motionlines"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Tuck icons away automatically", isOn: Binding(
                        get: { appModel.store.config.menuBarLayout.autoRehideEnabled },
                        set: { value in
                            appModel.updateMenuBarLayout { $0.autoRehideEnabled = value }
                        }
                    ))
                    .help("Hidden icons return to their tucked-away state after a short delay.")
                    .disabled(!appModel.menuBarScanner.physicalMovementEnabled)

                    Toggle("Show Hidden icons when I hover near Mendy", isOn: Binding(
                        get: { appModel.store.config.menuBarLayout.revealOnHover },
                        set: { value in
                            appModel.updateMenuBarLayout { $0.revealOnHover = value }
                        }
                    ))
                    .help("Hover over Mendy or the small zone beside it to reveal Hidden icons.")
                    .disabled(!appModel.menuBarScanner.physicalMovementEnabled)

                    Toggle("Show Hidden icons when I click empty space near Mendy", isOn: Binding(
                        get: { appModel.store.config.menuBarLayout.revealOnEmptyMenuBarClick },
                        set: { value in
                            appModel.updateMenuBarLayout { $0.revealOnEmptyMenuBarClick = value }
                        }
                    ))
                    .help("Only empty menu-bar space inside Mendy's reveal zone triggers this.")
                    .disabled(!appModel.menuBarScanner.physicalMovementEnabled)

                    Toggle("Show or tuck icons with a swipe near Mendy", isOn: Binding(
                        get: { appModel.store.config.menuBarLayout.revealOnScroll },
                        set: { value in
                            appModel.updateMenuBarLayout { $0.revealOnScroll = value }
                        }
                    ))
                    .help("Scroll or swipe while the pointer is in Mendy's reveal zone.")
                    .disabled(!appModel.menuBarScanner.physicalMovementEnabled)

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

                    Toggle("Make room when app menus overlap", isOn: Binding(
                        get: { appModel.store.config.menuBarLayout.hideApplicationMenusOnOverlap },
                        set: { value in
                            appModel.updateMenuBarLayout { $0.hideApplicationMenusOnOverlap = value }
                        }
                    ))

                    Toggle("Use a separate macMender bar for Hidden icons", isOn: Binding(
                        get: { appModel.store.config.menuBarLayout.showHiddenItemsInSecondaryBar },
                        set: { value in
                            appModel.updateMenuBarLayout { $0.showHiddenItemsInSecondaryBar = value }
                        }
                    ))
                    .disabled(!appModel.menuBarScanner.physicalMovementEnabled)

                    HStack {
                        Text("Item spacing")
                        Slider(value: Binding(
                            get: { Double(appModel.store.config.menuBarLayout.itemSpacingOffset) },
                            set: { value in
                                appModel.updateMenuBarLayout { $0.itemSpacingOffset = Int(value.rounded()) }
                            }
                        ), in: -16...16, step: 1)
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
            appModel.scanMenuBarItems()
        }
        .task {
            while !Task.isCancelled {
                appModel.syncMenuBarLayoutLive()
                let interval = appModel.permissions.screenRecording == .granted ? 1_500 : 2_500
                try? await Task.sleep(for: .milliseconds(interval))
            }
        }
        .coordinateSpace(name: menuBarLayoutDragCoordinateSpace)
        .onPreferenceChange(MenuBarLaneFramePreferenceKey.self) { frames in
            laneFrames = frames
        }
        .onChange(of: laneAnimationKey) { _, _ in
            reconcilePendingDisplayMoves()
        }
        .overlay(alignment: .topLeading) {
            if let dragPreview {
                MenuBarFloatingDragPreview(
                    preview: dragPreview,
                    reduceMotion: reduceMotion
                )
                .position(dragPreview.location)
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .animation(MenuBarLayoutMotion.lane(reduceMotion: reduceMotion), value: dragPreview.location)
                .zIndex(1000)
            }
        }
        .onDisappear {
            resetDragFeedback()
        }
        .confirmationDialog(
            "Reset Menu Bar Layout?",
            isPresented: $showingResetLayoutConfirmation
        ) {
            Button("Reset Layout", role: .destructive) {
                appModel.resetMenuBarLayout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mendy will move managed icons back to Visible and clear the saved layout.")
        }
    }

    private var hiddenStatusTitle: String {
        let count = appModel.hiddenMenuBarItemCount
        if count == 0 { return "Nothing hidden" }
        return count == 1 ? "1 managed icon" : "\(count) managed icons"
    }

    private var layoutAnimation: Animation? {
        MenuBarLayoutMotion.lane(reduceMotion: reduceMotion)
    }

    private var laneAnimationKey: String {
        appModel.menuBarScanner.detectedItems
            .filter(\.isHideCandidate)
            .map { "\($0.sectionKey)=\($0.actualSection.rawValue)=\(Int($0.frame.minX.rounded()))" }
            .joined(separator: "|")
    }

    private var hiddenSelectionsMissingFromScan: [MenuBarItemModel] {
        let detectedKeys = Set(appModel.menuBarScanner.detectedItems.map(\.sectionKey))
        return appModel.hiddenMenuBarSelections.filter { !detectedKeys.contains($0.bundleIdentifier) }
    }

    private var hideCandidateItems: [DetectedMenuBarItem] {
        deduplicated(appModel.menuBarScanner.detectedItems.filter(\.isHideCandidate))
    }

    private var filteredHideCandidateItems: [DetectedMenuBarItem] {
        let query = normalizedSearchText(searchText)
        guard !query.isEmpty else { return hideCandidateItems }
        return hideCandidateItems.filter { item in
            searchableText(for: item).contains(query)
        }
    }

    private func items(in section: MenuBarSection) -> [DetectedMenuBarItem] {
        let sectionItems = filteredHideCandidateItems.filter { item in
            displaySection(for: item) == section
        }
        return orderedForDisplay(sectionItems, in: section)
    }

    private var systemManagedItems: [DetectedMenuBarItem] {
        let query = normalizedSearchText(searchText)
        let items = ordered(appModel.menuBarScanner.detectedItems.filter { !$0.isHideCandidate })
        guard !query.isEmpty else { return items }
        return items.filter {
            searchableText(for: $0).contains(query)
        }
    }

    private var shouldShowMendyStatusItem: Bool {
        let query = normalizedSearchText(searchText)
        guard !query.isEmpty else { return true }
        return "mendy macmender menu bar".contains(query)
    }

    private func mendyInsertionIndex(in visibleItems: [DetectedMenuBarItem]) -> Int? {
        guard shouldShowMendyStatusItem else { return nil }
        guard let mendyFrame = appModel.menuBarScanner.visibleControlItem?.frame else { return 0 }
        return visibleItems.firstIndex { item in
            item.frame.midX > mendyFrame.midX
        } ?? visibleItems.count
    }

    private func ordered(_ items: [DetectedMenuBarItem]) -> [DetectedMenuBarItem] {
        return items.sorted { lhs, rhs in
            if lhs.frame.minX != rhs.frame.minX { return lhs.frame.minX < rhs.frame.minX }
            return lhs.windowID < rhs.windowID
        }
    }

    private func displaySection(for item: DetectedMenuBarItem) -> MenuBarSection {
        appModel.menuBarSection(for: item)
    }

    private func orderedForDisplay(_ items: [DetectedMenuBarItem], in section: MenuBarSection) -> [DetectedMenuBarItem] {
        ordered(items)
    }

    private func deduplicated(_ items: [DetectedMenuBarItem]) -> [DetectedMenuBarItem] {
        var bestByKey = [String: DetectedMenuBarItem]()
        var keyOrder = [String]()

        for item in items {
            let key = item.sectionKey
            if bestByKey[key] == nil {
                keyOrder.append(key)
                bestByKey[key] = item
            } else if let current = bestByKey[key],
                      isBetterLiveItem(item, than: current) {
                bestByKey[key] = item
            }
        }

        return keyOrder.compactMap { bestByKey[$0] }
    }

    private func isBetterLiveItem(_ candidate: DetectedMenuBarItem, than current: DetectedMenuBarItem) -> Bool {
        let candidateRank = liveSectionTrustRank(candidate.actualSection)
        let currentRank = liveSectionTrustRank(current.actualSection)
        if candidateRank != currentRank {
            return candidateRank < currentRank
        }
        if candidate.windowID != 0 && current.windowID == 0 { return true }
        if candidate.frame.width != current.frame.width {
            return candidate.frame.width > current.frame.width
        }
        return candidate.windowID < current.windowID
    }

    private func liveSectionTrustRank(_ section: MenuBarSection) -> Int {
        switch section {
        case .pinned:
            0
        case .overflow:
            1
        case .hidden:
            2
        }
    }

    private func searchableText(for item: DetectedMenuBarItem) -> String {
        [
            item.displayTitle,
            item.ownerName,
            item.sourceBundleIdentifier ?? ""
        ]
            .map(normalizedSearchText)
            .joined(separator: " ")
    }

    private func normalizedSearchText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: .current)
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
            .lowercased()
    }

    private func resetDragFeedback() {
        activeDraggedItemID = nil
        activeDropSection = nil
        activeInsertionSection = nil
        activeInsertionIndex = nil
        dragPreview = nil
    }

    private func reconcilePendingDisplayMoves() {
        guard !pendingDisplayMoves.isEmpty else { return }
        withAnimation(MenuBarLayoutMotion.drop(reduceMotion: reduceMotion)) {
            pendingDisplayMoves.removeAll()
        }
    }
}

private struct MenuBarSearchField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search menu-bar icons", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct MenuBarMovementDisabledBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.trianglebadge.exclamationmark")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 5) {
                Text("Physical movement disabled")
                    .font(.callout.weight(.semibold))
                Text("The current partial mover is not Thaw-equivalent. macMender will not hide, reorder, or restore menu-bar icons until the full Thaw runtime shape is transplanted and verified.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .liquidGlass(.row)
    }
}

private struct LiveOrderingPermissionBanner: View {
    var requestAction: () -> Void
    var settingsAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "dot.viewfinder")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 32, height: 32)
                .background(.orange.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("Live menu-bar order needs Screen Recording")
                    .font(.headline)
                Text("macMender uses this only to read menu-bar item windows and positions, like Ice and Thaw. It does not record, save, stream, or send your screen anywhere.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                Button("Grant Access") {
                    requestAction()
                }
                .buttonStyle(.borderedProminent)

                Button("Open Settings") {
                    settingsAction()
                }
                .buttonStyle(.link)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.orange.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct MenuBarLayoutLane: View {
    var section: MenuBarSection
    var items: [DetectedMenuBarItem]
    var allItems: [DetectedMenuBarItem]
    var mendyInsertionIndex: Int?
    @ObservedObject var appModel: AppModel
    var movementEnabled: Bool
    var reduceMotion: Bool
    var chipNamespace: Namespace.ID
    @Binding var activeDraggedItemID: String?
    @Binding var activeDropSection: MenuBarSection?
    @Binding var activeInsertionSection: MenuBarSection?
    @Binding var activeInsertionIndex: Int?
    @Binding var dragPreview: MenuBarDragPreviewState?
    @Binding var pendingDisplayMoves: [String: PendingMenuBarDisplayMove]
    var laneFrames: [MenuBarSection: CGRect]

    var body: some View {
        let isActiveDropTarget = activeDropSection == section
        let isDragging = activeDraggedItemID != nil
        let showsMendyStatusItem = mendyInsertionIndex != nil
        let renderedSlotCount = items.count + (showsMendyStatusItem ? 1 : 0)
        let insertionIndex = effectiveInsertionIndex(renderedSlotCount: renderedSlotCount)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(section.title)
                    .font(.headline.weight(.semibold))
                if isActiveDropTarget {
                    Label("Drop here", systemImage: "arrow.down.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.90))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(section.accentColor.opacity(0.26), in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if isDragging, movementEnabled {
                    Text("Drag to arrange")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
                Spacer()
                Text("\(items.count + (showsMendyStatusItem ? 1 : 0))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.18), in: Capsule())
            }

            Text(section.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    if items.isEmpty && !showsMendyStatusItem {
                        MenuBarLaneEmptyState(section: section, isTargeted: isActiveDropTarget, movementEnabled: movementEnabled)
                    } else {
                        if shouldShowInsertionMarker(at: 0, insertionIndex: insertionIndex) {
                            insertionFeedback(at: 0, renderedSlotCount: renderedSlotCount)
                        }
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if mendyInsertionIndex == index {
                                MendyMenuBarStatusChip(
                                    insertionIndex: index,
                                    sectionItems: items,
                                    statusItem: appModel.menuBarScanner.visibleControlItem,
                                    appModel: appModel,
                                    movementEnabled: movementEnabled,
                                    reduceMotion: reduceMotion,
                                    chipNamespace: chipNamespace,
                                    activeDraggedItemID: $activeDraggedItemID,
                                    activeDropSection: $activeDropSection,
                                    activeInsertionSection: $activeInsertionSection,
                                    activeInsertionIndex: $activeInsertionIndex,
                                    dragPreview: $dragPreview,
                                    pendingDisplayMoves: $pendingDisplayMoves,
                                    laneFrames: laneFrames
                            )
                            .transition(chipTransition)
                            }
                            MenuBarLaneItemChip(
                                item: item,
                                section: section,
                                sectionItems: items,
                                allItems: allItems,
                                appModel: appModel,
                                movementEnabled: movementEnabled,
                                reduceMotion: reduceMotion,
                                chipNamespace: chipNamespace,
                                activeDraggedItemID: $activeDraggedItemID,
                                activeDropSection: $activeDropSection,
                                activeInsertionSection: $activeInsertionSection,
                                activeInsertionIndex: $activeInsertionIndex,
                                dragPreview: $dragPreview,
                                pendingDisplayMoves: $pendingDisplayMoves,
                                laneFrames: laneFrames
                            )
                            .offset(x: neighborInsertionOffset(for: item))
                            .transition(chipTransition)
                            if shouldShowInsertionMarker(at: index + 1, insertionIndex: insertionIndex) {
                                insertionFeedback(at: index + 1, renderedSlotCount: renderedSlotCount)
                            }
                        }
                        if mendyInsertionIndex == items.count {
                            MendyMenuBarStatusChip(
                                insertionIndex: items.count,
                                sectionItems: items,
                                statusItem: appModel.menuBarScanner.visibleControlItem,
                                appModel: appModel,
                                movementEnabled: movementEnabled,
                                reduceMotion: reduceMotion,
                                chipNamespace: chipNamespace,
                                activeDraggedItemID: $activeDraggedItemID,
                                activeDropSection: $activeDropSection,
                                activeInsertionSection: $activeInsertionSection,
                                activeInsertionIndex: $activeInsertionIndex,
                                dragPreview: $dragPreview,
                                pendingDisplayMoves: $pendingDisplayMoves,
                                laneFrames: laneFrames
                            )
                            .transition(chipTransition)
                            if shouldShowInsertionMarker(at: items.count + 1, insertionIndex: insertionIndex) {
                                insertionFeedback(at: items.count + 1, renderedSlotCount: renderedSlotCount)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: items.isEmpty && !showsMendyStatusItem ? .center : .trailing)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: MenuBarLaneFramePreferenceKey.self,
                        value: [section: proxy.frame(in: .named(menuBarLayoutDragCoordinateSpace))]
                    )
                }
            }
            .background(laneFill(isActiveDropTarget: isActiveDropTarget), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActiveDropTarget ? Color.white.opacity(0.72) : section.accentColor.opacity(0.48), lineWidth: isActiveDropTarget ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if isActiveDropTarget, movementEnabled {
                    Label("Drop in \(section.title)", systemImage: "arrow.down.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.20), in: Capsule())
                        .padding(9)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .shadow(color: section.accentColor.opacity(isActiveDropTarget ? 0.30 : 0.12), radius: isActiveDropTarget ? 18 : 8, y: 4)
            .scaleEffect(isActiveDropTarget && !reduceMotion ? 1.01 : 1)
            .animation(MenuBarLayoutMotion.hover(reduceMotion: reduceMotion), value: isActiveDropTarget)
            .animation(MenuBarLayoutMotion.lane(reduceMotion: reduceMotion), value: items.map(\.id))
            .animation(MenuBarLayoutMotion.lane(reduceMotion: reduceMotion), value: insertionIndex)
        }
    }

    private func effectiveInsertionIndex(renderedSlotCount: Int) -> Int? {
        guard activeDraggedItemID != nil else { return nil }
        if activeInsertionSection == section, let activeInsertionIndex {
            return max(0, min(renderedSlotCount, activeInsertionIndex))
        }
        if activeDropSection == section {
            return renderedSlotCount
        }
        return nil
    }

    @ViewBuilder
    private func insertionFeedback(at slot: Int, renderedSlotCount: Int) -> some View {
        if shouldReserveDropSlot(at: slot, renderedSlotCount: renderedSlotCount) {
            MenuBarReservedDropSlot(
                section: section,
                width: activeDropSlotWidth,
                reduceMotion: reduceMotion
            )
            .transition(insertionTransition)
        } else {
            MenuBarInsertionMarker(section: section, reduceMotion: reduceMotion)
                .transition(insertionTransition)
        }
    }

    private func shouldShowInsertionMarker(at slot: Int, insertionIndex: Int?) -> Bool {
        guard movementEnabled else { return false }
        guard let insertionIndex,
              insertionIndex == slot,
              let activeDraggedItemID else {
            return false
        }
        if activeDropSection != section {
            return false
        }
        if activeDraggedItemID == mendyStatusItemDragID {
            return section == .pinned && insertionIndex != mendyInsertionIndex
        }
        if let draggedIndex = items.firstIndex(where: { $0.id == activeDraggedItemID }) {
            return insertionIndex != draggedIndex && insertionIndex != draggedIndex + 1
        }
        return true
    }

    private func shouldReserveDropSlot(at slot: Int, renderedSlotCount: Int) -> Bool {
        guard movementEnabled, let activeDraggedItemID else { return false }
        if activeDraggedItemID == mendyStatusItemDragID {
            return slot == renderedSlotCount
        }
        if items.contains(where: { $0.id == activeDraggedItemID }) {
            return slot == renderedSlotCount
        }
        return true
    }

    private var activeDropSlotWidth: CGFloat {
        guard let activeDraggedItemID else { return MenuBarChipMetrics.defaultCompactWidth }
        if activeDraggedItemID == mendyStatusItemDragID {
            return 48
        }
        if let item = allItems.first(where: { $0.id == activeDraggedItemID }) {
            return MenuBarChipMetrics(item: item, isHovered: false).chipWidth
        }
        return MenuBarChipMetrics.defaultCompactWidth
    }

    private var insertionTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.82))
    }

    private func resetDragFeedback() {
        activeDraggedItemID = nil
        activeDropSection = nil
        activeInsertionSection = nil
        activeInsertionIndex = nil
        dragPreview = nil
    }

    private func neighborInsertionOffset(for item: DetectedMenuBarItem) -> CGFloat {
        guard movementEnabled,
              !reduceMotion,
              activeInsertionSection == section,
              let activeDraggedItemID,
              activeDraggedItemID != item.id,
              let insertionIndex = activeInsertionIndex,
              let draggedIndex = items.firstIndex(where: { $0.id == activeDraggedItemID }),
              let draggedItem = items.first(where: { $0.id == activeDraggedItemID }),
              let itemIndex = items.firstIndex(where: { $0.id == item.id }) else {
            return 0
        }

        let shift = MenuBarChipMetrics(item: draggedItem, isHovered: false).chipWidth + 7
        if insertionIndex > draggedIndex, itemIndex > draggedIndex, itemIndex < insertionIndex {
            return -shift
        }
        if insertionIndex < draggedIndex, itemIndex >= insertionIndex, itemIndex < draggedIndex {
            return shift
        }
        return 0
    }

    private var chipTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96))
    }

    private func laneFill(isActiveDropTarget: Bool) -> LinearGradient {
        LinearGradient(
            colors: [
                section.accentColor.opacity(isActiveDropTarget ? 0.96 : 0.78),
                section.accentColor.opacity(isActiveDropTarget ? 0.76 : 0.58)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct MenuBarLaneItemChip: View {
    var item: DetectedMenuBarItem
    var section: MenuBarSection
    var sectionItems: [DetectedMenuBarItem]
    var allItems: [DetectedMenuBarItem]
    @ObservedObject var appModel: AppModel
    var movementEnabled: Bool
    var reduceMotion: Bool
    var chipNamespace: Namespace.ID
    @Binding var activeDraggedItemID: String?
    @Binding var activeDropSection: MenuBarSection?
    @Binding var activeInsertionSection: MenuBarSection?
    @Binding var activeInsertionIndex: Int?
    @Binding var dragPreview: MenuBarDragPreviewState?
    @Binding var pendingDisplayMoves: [String: PendingMenuBarDisplayMove]
    var laneFrames: [MenuBarSection: CGRect]

    var body: some View {
        let isActivelyDragged = activeDraggedItemID == item.id
        MenuBarItemChip(
            item: item,
            section: section,
            reduceMotion: reduceMotion,
            movementEnabled: movementEnabled,
            moveAction: { destination in
                appModel.setMenuBarSection(item, section: destination)
            }
        )
        .opacity(isActivelyDragged ? 0.42 : 1)
        .scaleEffect(isActivelyDragged && !reduceMotion ? 0.96 : 1)
        .matchedGeometryEffect(id: item.id, in: chipNamespace, properties: .position, isSource: !isActivelyDragged)
        .animation(MenuBarLayoutMotion.lane(reduceMotion: reduceMotion), value: item.id)
        .animation(MenuBarLayoutMotion.hover(reduceMotion: reduceMotion), value: isActivelyDragged)
        .highPriorityGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .named(menuBarLayoutDragCoordinateSpace))
                .onChanged { value in
                    guard movementEnabled else { return }
                    activeDraggedItemID = item.id
                    let targetSection = section(at: value.location) ?? sectionAfterVerticalDrag(value.translation.height) ?? section
                    let commitSlot = insertionSlot(for: value.location, in: targetSection)
                    updateDragFeedback(
                        dropSection: targetSection,
                        insertionSection: targetSection,
                        insertionIndex: visualInsertionSlot(forCommitSlot: commitSlot, in: targetSection)
                    )
                    updateDragPreview(location: value.location)
                }
                .onEnded { value in
                    guard movementEnabled else {
                        resetDragFeedback()
                        return
                    }
                    handleGestureDrop(value)
                    withAnimation(MenuBarLayoutMotion.drop(reduceMotion: reduceMotion)) {
                        resetDragFeedback()
                    }
                }
        )
    }

    private func handleGestureDrop(_ value: DragGesture.Value) {
        let targetSection = section(at: value.location) ?? sectionAfterVerticalDrag(value.translation.height) ?? section
        let targetSlot = insertionSlot(for: value.location, in: targetSection)
        let targetItems = items(in: targetSection, excludingDraggedItem: true)

        if targetSection != section {
            withAnimation(MenuBarLayoutMotion.drop(reduceMotion: reduceMotion)) {
                beginPendingDisplayMove(to: targetSection, before: targetSlot < targetItems.count ? targetItems[targetSlot] : nil)
                if targetSlot < targetItems.count {
                    appModel.moveMenuBarItem(item, to: targetSection, before: targetItems[targetSlot])
                } else {
                    appModel.moveMenuBarItem(item, to: targetSection, before: nil)
                }
            }
            syncAfterDrop()
            return
        }

        guard abs(value.translation.width) > 28,
              let currentIndex = sectionItems.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        guard targetSlot != currentIndex,
              targetSlot != currentIndex + 1 else { return }

        withAnimation(MenuBarLayoutMotion.drop(reduceMotion: reduceMotion)) {
            beginPendingDisplayMove(to: section, before: targetSlot < targetItems.count ? targetItems[targetSlot] : nil)
            if targetSlot < targetItems.count {
                appModel.moveMenuBarItem(item, to: section, before: targetItems[targetSlot])
            } else {
                appModel.moveMenuBarItem(item, to: section, before: nil)
            }
        }
        syncAfterDrop()
    }

    private var currentInsertionSlot: Int {
        sectionItems.firstIndex(where: { $0.id == item.id }) ?? 0
    }

    private func section(at location: CGPoint) -> MenuBarSection? {
        MenuBarSection.allCases.first { section in
            laneFrames[section]?.insetBy(dx: 0, dy: -18).contains(location) == true
        }
    }

    private func insertionSlot(for location: CGPoint, in targetSection: MenuBarSection) -> Int {
        guard let frame = laneFrames[targetSection] else {
            if targetSection == section {
                return horizontalInsertionSlot(for: location.x - (laneFrames[section]?.midX ?? location.x))
            }
            return items(in: targetSection, excludingDraggedItem: true).count
        }

        let targetItems = items(in: targetSection, excludingDraggedItem: true)
        guard !targetItems.isEmpty else { return 0 }

        let spacing: CGFloat = 7
        let widths = targetItems.map { MenuBarChipMetrics(item: $0, isHovered: false).chipWidth }
        let totalWidth = widths.reduce(0, +) + spacing * CGFloat(max(0, widths.count - 1))
        let contentMaxX = frame.maxX - 12
        var cursor = max(frame.minX + 12, contentMaxX - totalWidth)

        for (index, width) in widths.enumerated() {
            let midpoint = cursor + (width / 2)
            if location.x < midpoint {
                return index
            }
            cursor += width + spacing
        }
        return targetItems.count
    }

    private func visualInsertionSlot(forCommitSlot commitSlot: Int, in targetSection: MenuBarSection) -> Int {
        guard targetSection == section,
              let draggedIndex = sectionItems.firstIndex(where: { $0.id == item.id }) else {
            return commitSlot
        }
        return commitSlot >= draggedIndex ? commitSlot + 1 : commitSlot
    }

    private func items(in targetSection: MenuBarSection, excludingDraggedItem: Bool) -> [DetectedMenuBarItem] {
        let items = allItems
            .filter { appModel.menuBarSection(for: $0) == targetSection }
            .sorted {
                if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
                return $0.windowID < $1.windowID
            }
        guard excludingDraggedItem else { return items }
        return items.filter { $0.id != item.id }
    }

    private func horizontalInsertionSlot(for horizontalTranslation: CGFloat) -> Int {
        guard let currentIndex = sectionItems.firstIndex(where: { $0.id == item.id }) else {
            return 0
        }
        let stepWidth = MenuBarChipMetrics(item: item, isHovered: false).chipWidth + 7
        let rawStep = Int((horizontalTranslation / stepWidth).rounded())
        let baseSlot = horizontalTranslation >= 0 ? currentIndex + 1 : currentIndex
        return max(0, min(sectionItems.count, baseSlot + rawStep))
    }

    private func updateDragFeedback(dropSection: MenuBarSection?, insertionSection: MenuBarSection?, insertionIndex: Int?) {
        guard activeDropSection != dropSection ||
            activeInsertionSection != insertionSection ||
            activeInsertionIndex != insertionIndex
        else {
            return
        }
        withAnimation(MenuBarLayoutMotion.lane(reduceMotion: reduceMotion)) {
            activeDropSection = dropSection
            activeInsertionSection = insertionSection
            activeInsertionIndex = insertionIndex
        }
    }

    private func resetDragFeedback() {
        activeDraggedItemID = nil
        activeDropSection = nil
        activeInsertionSection = nil
        activeInsertionIndex = nil
        dragPreview = nil
    }

    private func updateDragPreview(location: CGPoint) {
        let targetSection = activeDropSection ?? section
        let preview = MenuBarDragPreviewState(
            id: item.id,
            item: item,
            isMendy: false,
            location: location,
            targetSection: targetSection
        )
        if dragPreview != preview {
            dragPreview = preview
        }
    }

    private func syncAfterDrop() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            appModel.syncMenuBarLayoutLive()
            try? await Task.sleep(for: .milliseconds(1_600))
            if pendingDisplayMoves[item.id]?.expiresAt ?? .distantPast <= Date() {
                withAnimation(MenuBarLayoutMotion.drop(reduceMotion: reduceMotion)) {
                    pendingDisplayMoves[item.id] = nil
                }
                appModel.syncMenuBarLayoutLive()
            }
        }
    }

    private func beginPendingDisplayMove(to section: MenuBarSection, before target: DetectedMenuBarItem?) {
        pendingDisplayMoves[item.id] = nil
    }

    private func sectionAfterVerticalDrag(_ verticalTranslation: CGFloat) -> MenuBarSection? {
        guard abs(verticalTranslation) > 48,
              let currentIndex = MenuBarSection.allCases.firstIndex(of: section) else {
            return nil
        }
        let rawStep = Int((verticalTranslation / 98).rounded(.towardZero))
        let step = rawStep == 0 ? (verticalTranslation > 0 ? 1 : -1) : rawStep
        let targetIndex = max(0, min(MenuBarSection.allCases.count - 1, currentIndex + step))
        return MenuBarSection.allCases[targetIndex]
    }
}

private struct MenuBarFloatingDragPreview: View {
    var preview: MenuBarDragPreviewState
    var reduceMotion: Bool

    var body: some View {
        Group {
            if preview.isMendy {
                mendyPreview
            } else if let item = preview.item {
                MenuBarItemChip(
                    item: item,
                    section: preview.targetSection,
                    reduceMotion: reduceMotion,
                    movementEnabled: false,
                    moveAction: { _ in }
                )
            } else {
                fallbackPreview
            }
        }
        .frame(width: preview.chipWidth, height: MenuBarChipMetrics.chipHeight)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(preview.targetSection.accentColor.opacity(0.78), lineWidth: 1.4)
        }
        .shadow(color: .black.opacity(reduceMotion ? 0.18 : 0.34), radius: reduceMotion ? 8 : 18, y: reduceMotion ? 4 : 10)
        .scaleEffect(reduceMotion ? 1 : 1.08)
        .accessibilityLabel("Dragging \(preview.item?.displayTitle ?? "Mendy")")
    }

    private var mendyPreview: some View {
        HStack(spacing: 6) {
            if let item = preview.item {
                MenuBarStatusItemIconView(item: item)
            } else {
                Image(nsImage: MendyAssets.menuBarImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 24, height: 22)
            }
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, 8)
    }

    private var fallbackPreview: some View {
        Image(systemName: "menubar.rectangle")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white.opacity(0.86))
    }
}

private struct MendyMenuBarStatusChip: View {
    var insertionIndex: Int
    var sectionItems: [DetectedMenuBarItem]
    var statusItem: DetectedMenuBarItem?
    @ObservedObject var appModel: AppModel
    var movementEnabled: Bool
    var reduceMotion: Bool
    var chipNamespace: Namespace.ID
    @Binding var activeDraggedItemID: String?
    @Binding var activeDropSection: MenuBarSection?
    @Binding var activeInsertionSection: MenuBarSection?
    @Binding var activeInsertionIndex: Int?
    @Binding var dragPreview: MenuBarDragPreviewState?
    @Binding var pendingDisplayMoves: [String: PendingMenuBarDisplayMove]
    var laneFrames: [MenuBarSection: CGRect]
    @State private var isHovered = false

    var body: some View {
        let isActivelyDragged = activeDraggedItemID == mendyStatusItemDragID
        HStack(spacing: 8) {
            if let statusItem {
                MenuBarStatusItemIconView(item: statusItem)
            } else {
                Image(nsImage: MendyAssets.menuBarImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 24, height: 22)
            }

            if isHovered || isActivelyDragged {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .transition(.opacity.combined(with: .scale(scale: 0.86)))
            }
        }
        .padding(.horizontal, isHovered || isActivelyDragged ? 8 : 7)
        .frame(width: isHovered || isActivelyDragged ? 52 : 38, height: 34)
        .background(.white.opacity(isHovered ? 0.20 : 0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(isHovered ? 0.44 : 0.24), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovered ? 0.16 : 0.07), radius: isHovered ? 8 : 3, y: isHovered ? 3 : 1)
        .scaleEffect(isHovered && !reduceMotion ? 1.045 : 1)
        .opacity(isActivelyDragged ? 0.42 : 1)
        .matchedGeometryEffect(id: mendyStatusItemDragID, in: chipNamespace, properties: .position, isSource: !isActivelyDragged)
        .highPriorityGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .named(menuBarLayoutDragCoordinateSpace))
                .onChanged { value in
                    guard movementEnabled else { return }
                    updateDragFeedback(insertionIndex: mendyInsertionIndex(for: value))
                    updateDragPreview(location: value.location)
                }
                .onEnded { value in
                    guard movementEnabled else {
                        resetDragFeedback()
                        return
                    }
                    handleGestureDrop(value)
                    withAnimation(MenuBarLayoutMotion.drop(reduceMotion: reduceMotion)) {
                        resetDragFeedback()
                    }
                }
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(MenuBarLayoutMotion.hover(reduceMotion: reduceMotion), value: isHovered)
        .animation(MenuBarLayoutMotion.lane(reduceMotion: reduceMotion), value: insertionIndex)
        .help(movementEnabled ? "Mendy stays Visible so you can open macMender, but you can drag it left or right." : "Mendy movement is disabled until the real Thaw runtime is transplanted.")
    }

    private func handleGestureDrop(_ value: DragGesture.Value) {
        guard abs(value.translation.width) > 58 else { return }

        let targetIndex = mendyInsertionIndex(for: value)
        guard targetIndex != insertionIndex else { return }

        withAnimation(MenuBarLayoutMotion.drop(reduceMotion: reduceMotion)) {
            if targetIndex < sectionItems.count {
                appModel.moveMendyStatusItem(before: sectionItems[targetIndex])
            } else {
                appModel.moveMendyStatusItem(before: nil)
            }
        }
    }

    private func mendyInsertionIndex(for value: DragGesture.Value) -> Int {
        if let frame = laneFrames[.pinned] {
            let spacing: CGFloat = 7
            let widths = sectionItems.map { MenuBarChipMetrics(item: $0, isHovered: false).chipWidth }
            let totalWidth = widths.reduce(0, +) + spacing * CGFloat(max(0, widths.count - 1)) + MenuBarChipMetrics.defaultCompactWidth + spacing
            let contentMaxX = frame.maxX - 12
            var cursor = max(frame.minX + 12, contentMaxX - totalWidth)
            for (index, width) in widths.enumerated() {
                let midpoint = cursor + (width / 2)
                if value.location.x < midpoint {
                    return index
                }
                cursor += width + spacing
            }
            return sectionItems.count
        }

        let stepWidth = MenuBarChipMetrics.defaultCompactWidth + 7
        let rawStep = Int((value.translation.width / stepWidth).rounded())
        return max(0, min(sectionItems.count, insertionIndex + rawStep))
    }

    private func updateDragFeedback(insertionIndex: Int) {
        guard activeDraggedItemID != mendyStatusItemDragID ||
            activeDropSection != .pinned ||
            activeInsertionSection != .pinned ||
            activeInsertionIndex != insertionIndex
        else {
            return
        }
        withAnimation(MenuBarLayoutMotion.lane(reduceMotion: reduceMotion)) {
            activeDraggedItemID = mendyStatusItemDragID
            activeDropSection = .pinned
            activeInsertionSection = .pinned
            activeInsertionIndex = insertionIndex
        }
    }

    private func resetDragFeedback() {
        activeDraggedItemID = nil
        activeDropSection = nil
        activeInsertionSection = nil
        activeInsertionIndex = nil
        dragPreview = nil
    }

    private func updateDragPreview(location: CGPoint) {
        let preview = MenuBarDragPreviewState(
            id: mendyStatusItemDragID,
            item: statusItem,
            isMendy: true,
            location: location,
            targetSection: .pinned
        )
        if dragPreview != preview {
            dragPreview = preview
        }
    }
}

private struct MenuBarInsertionMarker: View {
    var section: MenuBarSection
    var reduceMotion: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(.white.opacity(0.92))
            .frame(width: reduceMotion ? 4 : 6, height: MenuBarChipMetrics.chipHeight - 4)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(section.accentColor.opacity(0.38), lineWidth: 1)
            }
            .shadow(color: .white.opacity(reduceMotion ? 0 : 0.38), radius: reduceMotion ? 0 : 5)
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }
}

private struct MenuBarReservedDropSlot: View {
    var section: MenuBarSection
    var width: CGFloat
    var reduceMotion: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.white.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            .white.opacity(0.72),
                            style: StrokeStyle(lineWidth: 1.4, dash: reduceMotion ? [] : [4, 3])
                        )
                }

            HStack(spacing: 4) {
                MenuBarInsertionMarker(section: section, reduceMotion: reduceMotion)
                    .frame(height: MenuBarChipMetrics.chipHeight - 8)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .frame(width: max(width, MenuBarChipMetrics.defaultCompactWidth), height: MenuBarChipMetrics.chipHeight)
        .shadow(color: section.accentColor.opacity(reduceMotion ? 0 : 0.32), radius: reduceMotion ? 0 : 8, y: 3)
        .scaleEffect(reduceMotion ? 1 : 1.035)
        .accessibilityLabel("Drop slot")
    }
}

private struct MenuBarLaneEmptyState: View {
    var section: MenuBarSection
    var isTargeted: Bool
    var movementEnabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: section.emptySymbolName)
                .font(.system(size: 15, weight: .semibold))
            Text(movementEnabled ? (isTargeted ? "Drop here" : "Drop icons here") : "No detected icons")
                .font(.callout.weight(.medium))
        }
        .foregroundStyle(.white.opacity(0.72))
        .frame(maxWidth: .infinity)
    }
}

private struct MenuBarItemChip: View {
    var item: DetectedMenuBarItem
    var section: MenuBarSection
    var reduceMotion: Bool
    var movementEnabled: Bool
    var moveAction: (MenuBarSection) -> Void
    @State private var isHovered = false

    var body: some View {
        let metrics = MenuBarChipMetrics(item: item, isHovered: isHovered)
        HStack(spacing: 6) {
            MenuBarStatusItemIconView(item: item, metrics: metrics)

            if isHovered {
                Image(systemName: movementEnabled ? "line.3.horizontal" : "lock")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.70))
                    .transition(.opacity.combined(with: .scale(scale: 0.86)))
            }
        }
        .padding(.horizontal, isHovered ? 8 : 7)
        .frame(width: metrics.chipWidth, height: MenuBarChipMetrics.chipHeight)
        .background(.white.opacity(isHovered ? 0.22 : 0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(isHovered ? 0.42 : 0.24), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovered ? 0.16 : 0.07), radius: isHovered ? 8 : 3, y: isHovered ? 3 : 1)
        .scaleEffect(isHovered && !reduceMotion ? 1.045 : 1)
        .contentShape(.rect)
        .contextMenu {
            if movementEnabled {
                ForEach(MenuBarSection.allCases) { destination in
                    Button(destination.title) {
                        moveAction(destination)
                    }
                    .disabled(destination == section)
                }
            } else {
                Text("Physical movement disabled")
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.08) : .easeInOut(duration: 0.14), value: isHovered)
        .help(movementEnabled ? "\(item.displayTitle). Drag to reorder, or click for section options." : "\(item.displayTitle). Discovery only; physical movement is disabled.")
        .accessibilityLabel(item.displayTitle)
    }
}

private struct MenuBarStatusItemIconView: View {
    var item: DetectedMenuBarItem
    var metrics: MenuBarChipMetrics = .standard
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(width: metrics.iconWidth, height: metrics.iconHeight)
            } else {
                Text(String(item.displayTitle.prefix(1)).uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: min(metrics.iconWidth, 28), height: metrics.iconHeight)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
        .frame(width: metrics.iconWidth, height: metrics.iconHeight + 2)
        .task(id: iconCacheKey) {
            image = await MenuBarIconImageCache.shared.image(for: item)
        }
    }

    private var iconCacheKey: String {
        "\(item.windowID)-\(Int(item.frame.width.rounded()))x\(Int(item.frame.height.rounded()))"
    }
}

private struct MenuBarChipMetrics {
    static let chipHeight: CGFloat = 34
    static let defaultCompactWidth: CGFloat = 36
    static let standard = MenuBarChipMetrics(isComposite: false, isHovered: false)

    var isComposite: Bool
    var isHovered: Bool

    init(item: DetectedMenuBarItem, isHovered: Bool) {
        self.init(isComposite: item.isCompositeStatusItem, isHovered: isHovered)
    }

    init(isComposite: Bool, isHovered: Bool) {
        self.isComposite = isComposite
        self.isHovered = isHovered
    }

    var chipWidth: CGFloat {
        if isComposite { return isHovered ? 76 : 64 }
        return isHovered ? 48 : Self.defaultCompactWidth
    }

    var iconWidth: CGFloat {
        isComposite ? 48 : 24
    }

    var iconHeight: CGFloat {
        isComposite ? 22 : 20
    }
}

@MainActor
private final class MenuBarIconImageCache {
    static let shared = MenuBarIconImageCache()
    private var images = [String: NSImage]()

    func image(for item: DetectedMenuBarItem) async -> NSImage? {
        let key = "\(item.windowID)-\(Int(item.frame.width.rounded()))x\(Int(item.frame.height.rounded()))"
        if let image = images[key] {
            return image
        }
        guard let image = await snapshotImage(for: item) else {
            return nil
        }
        images[key] = image
        return image
    }

    private func snapshotImage(for item: DetectedMenuBarItem) async -> NSImage? {
        guard item.windowID != 0 else {
            return nil
        }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let window = content.windows.first(where: { $0.windowID == item.windowID }) else {
                return nil
            }

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let configuration = SCStreamConfiguration()
            let scale = NSScreen.main?.backingScaleFactor ?? 2
            configuration.width = max(1, Int(window.frame.width * scale))
            configuration.height = max(1, Int(window.frame.height * scale))
            configuration.showsCursor = false

            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
            )
        } catch {
            return nil
        }
    }
}

private struct MenuBarResetLayoutCard: View {
    var action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "arrow.counterclockwise.circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(.regularMaterial, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Reset Menu Bar Layout")
                    .font(.headline)
                Text("Moves managed icons back to Visible and clears Mendy’s saved layout.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Reset Layout", role: .destructive) {
                action()
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private extension MenuBarSection {
    var accentColor: Color {
        switch self {
        case .pinned:
            Color.orange
        case .overflow:
            Color.indigo
        case .hidden:
            Color.purple
        }
    }

    var emptySymbolName: String {
        switch self {
        case .pinned:
            "menubar.rectangle"
        case .overflow:
            "eye.slash"
        case .hidden:
            "archivebox"
        }
    }
}

private extension DetectedMenuBarItem {
    var isCompositeStatusItem: Bool {
        let source = (sourceBundleIdentifier ?? "").lowercased()
        let title = title.lowercased()
        let display = displayTitle.lowercased()
        if frame.width >= 32 { return true }
        return source.contains("stats") ||
            source.contains("istat") ||
            source.contains("hammerspoon") ||
            title.contains("combinedmodules") ||
            display.contains("stats") ||
            display.contains("istat")
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
            MendyAvatarView(mood: .sleeping, size: MendyAvatarSize.compact)
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
