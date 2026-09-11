//this file is the main view of the app
import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var manager: WindowManager
    @Environment(\.openSettings) private var openSettings
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @ObservedObject private var desktopToggleManager = DesktopToggleManager.shared
    @State private var hidePermissionBanner = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar: Snapshot List
            SnapshotListView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 285, max: 360)
                .background {
                    if themeColor.isGalaxy {
                        ZStack {
                            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                            Color(red: 0.02, green: 0.04, blue: 0.12).opacity(0.68)
                        }
                        .ignoresSafeArea()
                    } else {
                        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                            .ignoresSafeArea()
                    }
                }
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(themeColor.isGalaxy ? Color.white.opacity(0.18) : Color.primary.opacity(0.12))
                        .frame(width: 1)
                        .ignoresSafeArea()
                }
        } content: {
            // Content: Selected Snapshot Detail
            LayoutsView()
                .navigationSplitViewColumnWidth(min: 400, ideal: 500)
                .background {
                    if themeColor.isGalaxy {
                        ZStack {
                            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                            Color(red: 0.02, green: 0.04, blue: 0.12).opacity(0.60)
                        }
                        .ignoresSafeArea()
                    } else {
                        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                            .ignoresSafeArea()
                    }
                }
                .overlay(alignment: .trailing) {
                    if themeColor.isGalaxy {
                        Rectangle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 1)
                            .ignoresSafeArea()
                    }
                }
        } detail: {
            // Detail (Inspector): Actions + Preview + Activity
            inspectorColumn
                .navigationSplitViewColumnWidth(min: 280, ideal: 350, max: 350)
                .background {
                    if themeColor.isGalaxy {
                        ZStack {
                            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                            Color(red: 0.02, green: 0.04, blue: 0.12).opacity(0.68)
                        }
                        .ignoresSafeArea()
                    } else {
                        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                            .ignoresSafeArea()
                    }
                }
        }
        .toolbar {
            ToolbarItem(id: "mainSettings", placement: .navigation) {
                settingsToolbarContent
            }
            ToolbarItem(placement: .navigation) {
                liquidGlassHeaderSlider
            }
            ToolbarItem(placement: .principal) {
                actionButtonsToolbar
            }
        }
        .overlay(alignment: .top) {
            if !manager.hasAccessibilityPermission && !hidePermissionBanner {
                permissionBanner
            }
        }
        .sheet(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { _ in }
        )) {
            OnboardingView {
                withAnimation { hasCompletedOnboarding = true }
                Task { @MainActor in
                    UpdateManager.shared.checkIfNeeded()
                }
            }
        }
        // Shown only on the first launch after upgrading from a build with a
        // hardcoded shortcut, and only once onboarding is out of the way so the
        // two sheets can never compete for the window.
        .sheet(isPresented: Binding(
            get: { hasCompletedOnboarding && desktopToggleManager.needsShortcutMigrationNotice },
            set: { _ in }
        )) {
            ShortcutMigrationView(language: appLanguage, manager: desktopToggleManager) {
                withAnimation { desktopToggleManager.acknowledgeShortcutChange() }
            }
        }
        .frame(minWidth: 1000, idealWidth: 1150, minHeight: 600, idealHeight: 750)
        .onOpenURL { url in
            if url.host == "toggle-desktop" {
                DesktopToggleManager.shared.toggleDesktop()
            }
        }
        .background {
            if themeColor.isGalaxy {
                GalaxyCosmicBackgroundView()
            }
        }
        .background(WindowTransparencyAccessor())
        .background(MainToolbarOrderFix())
    }

    // MARK: - Inspector Column

    private var inspectorColumn: some View {
        VStack(spacing: 0) {
            // Layout Preview (Mini-map) — shown only when Auto Layout is OFF (when ON, it is in the center pane)
            if !manager.store.autoSaveEnabled {
                let previewSnapshot: LayoutSnapshot? = {
                    guard let key = manager.selectedSnapshotKey else { return nil }
                    if key == WindowManager.liveKey {
                        let fp = manager.currentFingerprint
                        return LayoutSnapshot(
                            id: UUID(),
                            name: fp.readableName,
                            screenKey: fp.key,
                            readableScreenKey: fp.readableName,
                            records: manager.liveRecords,
                            createdAt: Date(),
                            updatedAt: Date(),
                            location: nil,
                            isAutoSave: true
                        )
                    }
                    return manager.store.snapshots[key]
                }()

                if let snapshot = previewSnapshot {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("VISUAL PREVIEW".localized(appLanguage))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)

                        LayoutPreviewView(snapshot: snapshot, selectedRecordID: nil, tint: themeColor.color(seed: 2))
                            .frame(height: 160)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: snapshot.previewRecords.count)
                    }
                    .padding(16)
                    // Slides out to the left (-x) when switching to Auto Layout;
                    // slides in from the left (-x -> 0) when returning to Saved Sessions.
                    // Mirrors the center-pane card to create seamless continuity between columns.
                    .transition(.asymmetric(
                        insertion: .offset(x: -260).combined(with: .opacity),
                        removal:   .offset(x: -260).combined(with: .opacity)
                    ))

                    Divider()
                }
            }
            
            // Activity Log
            ActivityView()
                .frame(maxHeight: .infinity)
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: manager.store.autoSaveEnabled)
        .clipped()
    }

    @ViewBuilder
    private var actionButtonsToolbar: some View {
        HStack(spacing: 6) {

            if !manager.store.autoSaveEnabled {
                Button {
                    manager.saveNow()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                            .mainWindowSymbolAnimation(.wiggle, capturesClicks: false)
                        Text((manager.willUpdateSession ? "Update Layout" : "Save Layout").localized(appLanguage))
                    }
                }
                .help({
                    if manager.isUpdateRestricted { return "Cannot update/save while a restricted or mismatched session is selected" }
                    if let key = manager.selectedSnapshotKey, key != WindowManager.liveKey,
                       let snapshot = manager.store.snapshots[key],
                       !manager.canRestore(snapshot: snapshot) {
                        return "Connect the required displays to update this session"
                    }
                    return manager.willUpdateSession ? "Update current layout" : "Save current window positions"
                }())
                .disabled({
                    if manager.isUpdateRestricted { return true }
                    if let key = manager.selectedSnapshotKey, key != WindowManager.liveKey,
                       let snapshot = manager.store.snapshots[key] {
                        return !manager.canRestore(snapshot: snapshot)
                    }
                    return false
                }())
                .mainWindowSymbolHoverRegion()

                Button {
                    if let key = manager.selectedSnapshotKey, key != WindowManager.liveKey {
                        manager.restore(key: key)
                    } else {
                        manager.restoreNow()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .mainWindowSymbolAnimation(.flip, capturesClicks: false)
                        Text("Restore".localized(appLanguage))
                    }
                }
                .help("Restore saved layout for current screens")
                .disabled({
                    if let key = manager.selectedSnapshotKey, key != WindowManager.liveKey {
                        if let snapshot = manager.store.snapshots[key] {
                            return !manager.canRestore(snapshot: snapshot)
                        }
                    }
                    return false
                }())
                .mainWindowSymbolHoverRegion()
            }

        }
    }

    private var settingsToolbarContent: some View {
        Button {
            openSettings()
        } label: {
            Image(systemName: "gearshape")
                .mainWindowSymbolAnimation(.rotate, capturesClicks: false)
        }
        .buttonBorderShape(.circle)
        .mainWindowSymbolHoverRegion()
        .help("Settings".localized(appLanguage))
    }

    private var liquidGlassHeaderSlider: some View {
        Picker("", selection: Binding(
            get: { manager.store.autoSaveEnabled ? 0 : 1 },
            set: { val in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    manager.setAutoSaveEnabled(val == 0)
                }
            }
        )) {
            Label {
                Text("Auto Layout".localized(appLanguage))
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
                    .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
            }
                .labelStyle(.titleAndIcon)
                .tag(0)
            Label {
                Text("Saved Sessions".localized(appLanguage))
            } icon: {
                Image(systemName: "folder")
                    .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
            }
                .labelStyle(.titleAndIcon)
                .tag(1)
        }
        .pickerStyle(.segmented)
        .fixedSize(horizontal: true, vertical: false)
        .mainWindowSymbolHoverRegion()
        .accessibilityLabel(Text("Layout mode".localized(appLanguage)))
        .help("Switch between Auto Layout mode and Saved Sessions mode".localized(appLanguage))
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .mainWindowSymbolAnimation(.breathe)
                    .foregroundStyle(.orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility Permission Required".localized(appLanguage))
                        .font(.headline)
                    Text("To track and restore windows from other apps, please enable RememberMyWindows in System Settings. If already ON, toggle it OFF and ON to refresh macOS cache.".localized(appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .mainWindowSymbolHoverRegion()
            
            Spacer()

            Button("Re-check".localized(appLanguage)) {
                manager.checkAccessibilityPermissionManually()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button("Open System Settings".localized(appLanguage)) {
                manager.openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            Button {
                withAnimation {
                    hidePermissionBanner = true
                }
            } label: {
                Image(systemName: "xmark")
                    .mainWindowSymbolAnimation(.wiggle, capturesClicks: false)
                    .font(.caption.bold())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .mainWindowSymbolHoverRegion()
        }
        .padding(12)
        .background {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        }
        .padding(16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// SwiftUI always places the NavigationSplitView sidebar toggle before custom
/// navigation toolbar items on macOS 14. Move the settings item ahead of that
/// native item once AppKit has created the toolbar.
private struct MainToolbarOrderFix: NSViewRepresentable {
    final class Coordinator {
        weak var scheduledWindow: NSWindow?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let view else { return }
            scheduleReorder(for: view, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        scheduleReorder(for: nsView, coordinator: context.coordinator)
    }

    private func scheduleReorder(for view: NSView, coordinator: Coordinator) {
        guard let window = view.window,
              coordinator.scheduledWindow !== window else { return }

        coordinator.scheduledWindow = window
        for delay in [0.0, 0.1, 0.3, 0.7] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                reorderSettingsItem(in: window)
            }
        }
    }

    private func reorderSettingsItem(in window: NSWindow) {
        guard let toolbar = window.toolbar,
              let settingsIndex = toolbar.items.firstIndex(where: {
                  $0.itemIdentifier.rawValue.contains("mainSettings")
              }),
              let sidebarIndex = toolbar.items.firstIndex(where: {
                  $0.label.localizedCaseInsensitiveContains("sidebar") ||
                  $0.itemIdentifier.rawValue.localizedCaseInsensitiveContains("sidebar")
              }),
              settingsIndex > sidebarIndex else { return }

        let settingsIdentifier = toolbar.items[settingsIndex].itemIdentifier
        toolbar.removeItem(at: settingsIndex)
        toolbar.insertItem(withItemIdentifier: settingsIdentifier, at: sidebarIndex)
    }
}
