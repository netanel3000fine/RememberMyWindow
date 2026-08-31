//this file is the main view of the app
import SwiftUI

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
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    manager.saveNow()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
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

                Button {
                    if let key = manager.selectedSnapshotKey, key != WindowManager.liveKey {
                        manager.restore(key: key)
                    } else {
                        manager.restoreNow()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward.circle")
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

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings".localized(appLanguage))
            }
        }
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
    }

    // MARK: - Inspector Column

    private var inspectorColumn: some View {
        VStack(spacing: 0) {
            // Layout Preview (Mini-map) — shown for both live layout and saved sessions
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
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: snapshot.records.count)
                }
                .padding(16)

                Divider()
            }
            
            // Activity Log
            ActivityView()
                .frame(maxHeight: .infinity)
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility Permission Required".localized(appLanguage))
                    .font(.headline)
                Text("To track and restore windows from other apps, please enable RememberMyWindows in System Settings. If already ON, toggle it OFF and ON to refresh macOS cache.".localized(appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
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
                    .font(.caption.bold())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
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
