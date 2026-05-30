import Foundation
import MacMenderMenuBarEngine
import Testing

@Suite("Menu Bar Engine Port")
struct MenuBarEnginePortTests {
    @Test("Thaw tag identifiers preserve stable multi-icon instance indexes")
    func thawTagIdentifiersPreserveInstanceIndexes() {
        let tags = [
            MenuBarItemTag(namespace: .init("eu.exelban.Stats"), title: "CombinedModules"),
            MenuBarItemTag(namespace: .init("eu.exelban.Stats"), title: "CombinedModules")
        ]

        let indexed = MenuBarItemInstanceIndexer.assignStableInstanceIndices(to: tags, windowIDs: [200, 100])

        #expect(indexed[1].tagIdentifier == "eu.exelban.Stats:CombinedModules")
        #expect(indexed[0].tagIdentifier == "eu.exelban.Stats:CombinedModules:1")
    }

    @Test("Thaw cache insertion maps divider destinations to expected sections")
    func thawCacheInsertionMapsDividerDestinations() {
        let hiddenControl = MenuBarItemRecord(tag: .hiddenControlItem)
        let alwaysHiddenControl = MenuBarItemRecord(tag: .alwaysHiddenControlItem)
        let stats = MenuBarItemRecord(tag: MenuBarItemTag(namespace: .init("eu.exelban.Stats"), title: "CombinedModules"))
        let codex = MenuBarItemRecord(tag: MenuBarItemTag(namespace: .init("com.openai.codex"), title: "Codex"))

        var cache = MenuBarItemCache()
        cache[.visible] = [hiddenControl]
        cache[.hidden] = [alwaysHiddenControl]

        cache.insert(stats, at: .rightOfItem(alwaysHiddenControl))
        cache.insert(codex, at: .leftOfItem(alwaysHiddenControl))

        #expect(cache[.hidden].first?.tag == stats.tag)
        #expect(cache[.alwaysHidden].first?.tag == codex.tag)
    }

    @Test("engine snapshot centralizes managed and read-only sections")
    func engineSnapshotCentralizesSections() {
        let visible = engineItem(id: "visible", section: .visible, canHide: true, canMove: true)
        let hidden = engineItem(id: "hidden", section: .hidden, canHide: true, canMove: true)
        let alwaysHidden = engineItem(id: "always", section: .alwaysHidden, canHide: true, canMove: true)
        let readOnly = engineItem(id: "clock", section: .visible, canHide: false, canMove: false)

        let snapshot = MenuBarEngineSnapshot(items: [visible, hidden, alwaysHidden, readOnly])

        #expect(snapshot.visible.map(\.id) == ["visible"])
        #expect(snapshot.hidden.map(\.id) == ["hidden"])
        #expect(snapshot.alwaysHidden.map(\.id) == ["always"])
        #expect(snapshot.readOnly.map(\.id) == ["clock"])
    }

    @Test("engine movement policy documents the scoped cursor guard")
    func engineMovementPolicyDocumentsScopedCursorGuard() {
        #expect(MenuBarEngineMovementPolicy.allowsScopedCursorGuard)
        #expect(MenuBarEngineMovementPolicy.description.localizedCaseInsensitiveContains("Thaw"))
    }

    @Test("source tree forbids cursor warp and hide APIs")
    func sourceTreeForbidsCursorWarpAndHideAPIs() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources")
        let forbidden = [
            "CGWarpMouseCursorPosition",
            "CGDisplayHideCursor",
            "CGDisplayShowCursor",
            "CGAssociateMouseAndMouseCursorPosition"
        ]

        let swiftFiles = FileManager.default
            .enumerator(at: sources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []

        for file in swiftFiles {
            if file.lastPathComponent == "MenuBarItemMover.swift" {
                continue
            }
            let text = try String(contentsOf: file, encoding: .utf8)
            for symbol in forbidden where text.contains(symbol) {
                Issue.record("Forbidden cursor API \(symbol) found in \(file.path)")
            }
        }
    }

    private func engineItem(
        id: String,
        section: MenuBarEngineSection,
        canHide: Bool,
        canMove: Bool
    ) -> MenuBarEngineItem {
        MenuBarEngineItem(
            id: id,
            displayName: id,
            sourceBundleIdentifier: nil,
            sourceProcessIdentifier: nil,
            windowID: 0,
            frame: .zero,
            section: section,
            canHide: canHide,
            canMove: canMove
        )
    }

    @Test("app activation paths do not synthesize mouse input")
    func appActivationPathsDoNotSynthesizeMouseInput() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let auditedFiles = [
            "Sources/macMender/App/AppModel.swift",
            "Sources/macMender/App/macMenderApp.swift",
            "Sources/macMender/App/MacMenderStatusItemController.swift",
            "Sources/macMender/Views/MenuBarPopover.swift",
            "Sources/macMender/MenuBarManagement/MenuBarApplicationMenuController.swift"
        ]
        let forbidden = [
            "CGEvent(mouseEventSource:",
            "CGEventCreateMouseEvent",
            "CGEventPost",
            ".post(tap:",
            "postToPid(",
            "NSEvent.mouseEvent"
        ]

        for relativePath in auditedFiles {
            let url = root.appendingPathComponent(relativePath)
            let text = try String(contentsOf: url, encoding: .utf8)
            for symbol in forbidden where text.contains(symbol) {
                Issue.record("Activation-facing file \(relativePath) must not synthesize mouse input via \(symbol)")
            }
        }
    }

    @Test("menu bar movement cursor guard stays scoped to Thaw-style mover")
    func menuBarMovementCursorGuardStaysScopedToThawStyleMover() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let menuBarSources = root.appendingPathComponent("Sources/macMender/MenuBarManagement")
        let globallyForbidden = [
            "CGAssociateMouseAndMouseCursorPosition",
            ".cghidEventTap",
            ".cgAnnotatedSessionEventTap"
        ]
        let moverRequired = [
            "CGWarpMouseCursorPosition",
            "CGDisplayHideCursor",
            "CGDisplayShowCursor",
            ".post(tap:",
            ".cgSessionEventTap"
        ]

        let swiftFiles = FileManager.default
            .enumerator(at: menuBarSources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []

        for file in swiftFiles {
            let text = try String(contentsOf: file, encoding: .utf8)
            for symbol in globallyForbidden where text.contains(symbol) {
                Issue.record("Menu-bar source \(file.lastPathComponent) must not use global cursor/HID API \(symbol)")
            }
            if file.lastPathComponent != "MenuBarItemMover.swift" {
                for symbol in moverRequired where text.contains(symbol) {
                    Issue.record("Only MenuBarItemMover.swift may use Thaw-style guarded movement API \(symbol)")
                }
            }
        }

        let mover = try String(
            contentsOf: menuBarSources.appendingPathComponent("MenuBarItemMover.swift"),
            encoding: .utf8
        )
        for symbol in moverRequired where !mover.contains(symbol) {
            Issue.record("MenuBarItemMover.swift should keep guarded Thaw-style movement primitive \(symbol)")
        }
    }

    @Test("Thaw XPC and side-by-side parity cases stay covered in QA docs")
    func thawXPCAndSideBySideParityCasesStayCoveredInQADocs() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let qaDocs = [
            "docs/MENU_BAR_SMOKE_TEST_SCRIPT.md",
            "docs/MENU_BAR_MANUAL_TEST_CHECKLIST.md"
        ]
        let requiredTerms = [
            "xpc",
            "presence/connectivity",
            "discovery",
            "hide",
            "always hidden",
            "reorder",
            "secondary bar",
            "reveal triggers",
            "stats",
            "multi-icon",
            "screen recording",
            "auto-hidden menu bar",
            "full-screen",
            "multiple displays"
        ]

        for relativePath in qaDocs {
            let text = try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
                .lowercased()
            for term in requiredTerms where !text.contains(term) {
                Issue.record("\(relativePath) must cover Thaw parity case: \(term)")
            }
        }
    }

    @Test("drag animation checklist coverage stays explicit in QA docs")
    func dragAnimationChecklistCoverageStaysExplicitInQADocs() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let qaDocs = [
            "docs/MENU_BAR_SMOKE_TEST_SCRIPT.md",
            "docs/MENU_BAR_MANUAL_TEST_CHECKLIST.md"
        ]
        let requiredTerms = [
            "in-lane insertion marker",
            "target lane drop-slot reservation",
            "target lane highlight",
            "matched item movement",
            "reduce motion behavior",
            "side-by-side thaw animation comparison"
        ]

        for relativePath in qaDocs {
            let text = try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
                .lowercased()
            for term in requiredTerms where !text.contains(term) {
                Issue.record("\(relativePath) must cover drag animation checklist case: \(term)")
            }
        }
    }

    @Test("layout lanes keep one custom drag source of truth")
    func layoutLanesKeepOneCustomDragSourceOfTruth() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let view = root.appendingPathComponent("Sources/macMender/Views/Sections/MenuBarManagementView.swift")
        let text = try String(contentsOf: view, encoding: .utf8)

        #expect(text.contains("MenuBarFloatingDragPreview"))
        #expect(text.contains("PendingMenuBarDisplayMove"))
        #expect(!text.contains(".onDrag"))
        #expect(!text.contains(".onDrop"))
        #expect(!text.contains("NSItemProvider"))
    }

    @Test("pointer stability parity fields and duplicate chip coverage stays explicit in QA docs")
    func pointerStabilityParityFieldsAndDuplicateChipCoverageStaysExplicitInQADocs() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let qaDocs = [
            "docs/MENU_BAR_SMOKE_TEST_SCRIPT.md",
            "docs/MENU_BAR_MANUAL_TEST_CHECKLIST.md"
        ]
        let requiredTerms = [
            "pointer coordinates",
            "pointer coordinate stability",
            "repeated hide/reveal",
            "drag/cancel and drag/drop attempts",
            "thaw-vs-macmender parity status fields",
            "scenario name",
            "item tag/title/source",
            "starting section",
            "requested section",
            "final macmender section",
            "final thaw section",
            "macmender physical divider boundary",
            "thaw physical divider boundary",
            "macmender reveal state",
            "thaw reveal state",
            "live-order status text",
            "duplicate/ghost live-chip status",
            "pass/fail parity result",
            "duplicate live chip",
            "stale source chip"
        ]

        for relativePath in qaDocs {
            let text = try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
                .lowercased()
            for term in requiredTerms where !text.contains(term) {
                Issue.record("\(relativePath) must cover pointer stability/parity/duplicate chip case: \(term)")
            }
        }
    }

    @Test("XPC helper wiring cannot be partially added without app bundle embedding")
    func xpcHelperWiringCannotBePartiallyAddedWithoutAppBundleEmbedding() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let manifest = try String(contentsOf: root.appendingPathComponent("Package.swift"), encoding: .utf8)
        let buildScript = try String(contentsOf: root.appendingPathComponent("script/build_and_run.sh"), encoding: .utf8)
        let packageScript = try String(contentsOf: root.appendingPathComponent("script/package_brew.sh"), encoding: .utf8)
        let smokeDoc = try String(contentsOf: root.appendingPathComponent("docs/MENU_BAR_SMOKE_TEST_SCRIPT.md"), encoding: .utf8)
            .lowercased()

        #expect(packageScript.contains("build_and_run.sh"))
        #expect(packageScript.contains("--build-only"))

        let xpcProductIsMentioned = manifest.contains("MacMenderMenuBarItemService")
            || buildScript.contains("MacMenderMenuBarItemService")
            || buildScript.contains(".xpc")

        if xpcProductIsMentioned {
            #expect(buildScript.contains("XPCServices"))
            #expect(
                buildScript.contains("MacMenderMenuBarItemService.xpc")
                    || (buildScript.contains("MacMenderMenuBarItemService") && buildScript.contains("$XPC_SERVICE_NAME.xpc"))
            )
            #expect(buildScript.contains("CFBundlePackageType"))
            #expect(buildScript.contains("XPC!"))
            #expect(buildScript.contains("pkill -x \"$XPC_SERVICE_NAME\""))
            #expect(buildScript.contains("-name '*.bundle'"))
            #expect(buildScript.contains("$APP_RESOURCES"))
        } else {
            #expect(smokeDoc.contains("known parity gap"))
            #expect(smokeDoc.contains("macmendermenubaritemservice.xpc"))
        }
    }
}
