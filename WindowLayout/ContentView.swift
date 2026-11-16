//this file is the main view of the app
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: WindowManager
    @Environment(\.openSettings) private var openSettings
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("hasSeenV15_5Notes") private var hasSeenV15_5Notes: Bool = false
    @AppStorage("minimalVisualAnimations") private var minimalVisualAnimations: Bool = true
    @AppStorage("appListViewMode") private var appListViewMode: AppListViewMode = .list
    @ObservedObject private var desktopToggleManager = DesktopToggleManager.shared
    @State private var hidePermissionBanner = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    private var isV15_5NotesPending: Bool {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return (appVersion == "15.5" || appVersion == "15.1") && hasCompletedOnboarding && !hasSeenV15_5Notes
    }

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
                .navigationSplitViewColumnWidth(min: 350, ideal: 350, max: 350)
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
        .background {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(id: "mainSettings", placement: .navigation) {
                settingsToolbarContent
            }
            if manager.isWindowServerInitializing {
                ToolbarItem(id: "windowServerLoadingStatus", placement: .navigation) {
                    HStack(spacing: 6) {
                        Divider()
                            .frame(height: 20)
                            .accessibilityHidden(true)
                        WindowServerLoadingStatus(language: appLanguage, style: .toolbar)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            if #available(macOS 26.0, *) {
                ToolbarSpacer(.flexible, placement: .primaryAction)
            }
            ToolbarItem(id: "layoutModeSelector", placement: .primaryAction) {
                liquidGlassHeaderSlider
            }
            ToolbarItem(id: "mainLayoutActions", placement: .primaryAction) {
                actionButtonsToolbar
            }
            if !manager.store.autoSaveEnabled {
                ToolbarItem(id: "appListViewToggle", placement: .primaryAction) {
                    listGridToggleButton
                }
            }
        }
        .overlay(alignment: .top) {
            if !manager.hasAccessibilityPermission && !hidePermissionBanner {
                permissionBanner
            }
        }
        // 1. First-run onboarding for brand new users
        .sheet(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { _ in }
        )) {
            OnboardingView {
                withAnimation {
                    hasCompletedOnboarding = true
                    hasSeenV15_5Notes = true
                }
                Task { @MainActor in
                    UpdateManager.shared.checkIfNeeded()
                }
            }
            .environmentObject(manager)
            .fullVisualAnimations()
        }
        // 2. Standalone What's New window for existing users who upgraded to v15.5
        .sheet(isPresented: Binding(
            get: { hasCompletedOnboarding && isV15_5NotesPending },
            set: { _ in }
        )) {
            WhatsNewView {
                withAnimation {
                    hasSeenV15_5Notes = true
                }
                Task { @MainActor in
                    UpdateManager.shared.checkIfNeeded()
                }
            }
            .environmentObject(manager)
            .fullVisualAnimations()
        }
        // Defer the shortcut migration notice until the first-run or v15.5 release
        // notes are complete so two sheets never compete for the window.
        .sheet(isPresented: Binding(
            get: {
                hasCompletedOnboarding &&
                    !isV15_5NotesPending &&
                    desktopToggleManager.needsShortcutMigrationNotice
            },
            set: { _ in }
        )) {
            ShortcutMigrationView(language: appLanguage, manager: desktopToggleManager) {
                withAnimation { desktopToggleManager.acknowledgeShortcutChange() }
            }
            .minimalVisualAnimations()
            .environment(\.minimalVisualAnimationsEnabled, minimalVisualAnimations)
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
        .minimalVisualAnimations()
        .environment(\.minimalVisualAnimationsEnabled, minimalVisualAnimations)
        .appThemeColorScheme(themeColor)
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

                        LayoutPreviewView(
                            snapshot: snapshot,
                            selectedRecordID: manager.selectedRecordID,
                            tint: themeColor.color(seed: 2),
                            enable3DHover: true,
                            animateWindowReveal: true,
                            isMainWindow: true
                        )
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
        if !manager.store.autoSaveEnabled {
            ControlGroup {
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
                            .padding(.trailing, 4)
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

    private var listGridToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                appListViewMode = appListViewMode == .list ? .grid : .list
            }
        } label: {
            Image(systemName: appListViewMode == .list ? "square.grid.2x2" : "list.bullet")
                .mainWindowSymbolAnimation(.wiggle, capturesClicks: false)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle)
        .mainWindowSymbolHoverRegion()
        .help(appListViewMode == .list ? "Switch to Grid View".localized(appLanguage) : "Switch to List View".localized(appLanguage))
        .accessibilityLabel(appListViewMode == .list ? "Grid View" : "List View")
    }

    private var settingsToolbarContent: some View {
        Button {
            openSettings()
        } label: {
            Image(systemName: "gearshape")
                .mainWindowSymbolAnimation(.rotate, capturesClicks: false)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .mainWindowSymbolHoverRegion()
        .accessibilityLabel("Settings".localized(appLanguage))
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
            .coloredActionButtonEffect()
            
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
