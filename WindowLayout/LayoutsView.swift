import SwiftUI
import MapKit

struct LayoutsView: View {
    @EnvironmentObject var manager: WindowManager
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    private var liveLayoutSnapshot: LayoutSnapshot {
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

    var body: some View {
        if manager.store.autoSaveEnabled {
            AutoLayoutCenterView()
        } else {
            let hasSaved = !manager.store.snapshots.filter({ !$0.value.isAutoSave }).isEmpty
            if manager.liveRecords.isEmpty && !hasSaved {
                emptyState
            } else if let key = manager.selectedSnapshotKey {
                if key == WindowManager.liveKey {
                    SnapshotDetailView(snapshot: liveLayoutSnapshot, key: key)
                } else if let snapshot = manager.store.snapshots[key] {
                    SnapshotDetailView(snapshot: snapshot, key: key)
                } else {
                    SnapshotDetailView(snapshot: liveLayoutSnapshot, key: WindowManager.liveKey)
                }
            } else {
                SnapshotDetailView(snapshot: liveLayoutSnapshot, key: WindowManager.liveKey)
            }
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "macwindow.on.rectangle")
                .mainWindowSymbolAnimation(.wiggleByLayer)
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)
            Text("No layouts saved yet".localized(appLanguage))
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Arrange your windows and click \"Save Layout\" to record their positions.\nThey'll be restored automatically whenever this screen configuration reconnects.".localized(appLanguage))
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .mainWindowSymbolHoverRegion()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Snapshot List View

struct SnapshotListView: View {
    @EnvironmentObject var manager: WindowManager
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var hoveredKey: String? = nil
    /// Whether the user has opened Saved Sessions. Stored, so reopening sticks.
    ///
    /// Read through `sessionsExpanded`, never directly: the section is only
    /// demoted while Auto is carrying the everyday case. With Auto off, saved
    /// sessions are the only thing in this window, and collapsing them by
    /// default would hide the app's entire content behind a disclosure triangle.
    @AppStorage("savedSessionsOpened") private var savedSessionsOpened: Bool = false

    private var sessionsExpanded: Bool {
        savedSessionsOpened || !manager.store.autoSaveEnabled
    }

    var liveSnapshot: (key: String, snapshot: LayoutSnapshot)? {
        guard !manager.liveRecords.isEmpty else { return nil }
        let fp = manager.currentFingerprint
        let snap = LayoutSnapshot(
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
        return (key: WindowManager.liveKey, snapshot: snap)
    }

    var savedSnapshots: [(key: String, snapshot: LayoutSnapshot)] {
        return manager.store.snapshots
            .filter { !$0.value.isAutoSave }
            .sorted { $0.value.updatedAt > $1.value.updatedAt }
            .map { (key: $0.key, snapshot: $0.value) }
    }

    var body: some View {
        if manager.store.autoSaveEnabled {
            AutoLayoutSidebarWindowListView()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // LIVE LAYOUT SECTION
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LIVE LAYOUT".localized(appLanguage))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                        
                        if let live = liveSnapshot {
                            snapshotRow(live.snapshot, key: live.key, isLive: true)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .liquidGlass(
                                    isSelected: manager.selectedSnapshotKey == live.key,
                                    prominent: true,
                                    tint: themeColor.color(seed: 1),
                                    isHovered: hoveredKey == live.key
                                )
                                .contentShape(Rectangle())
                                .mainWindowSymbolHoverRegion()
                                .onHover { isHovered in
                                    if isHovered { hoveredKey = live.key }
                                    else if hoveredKey == live.key { hoveredKey = nil }
                                }
                                .onTapGesture {
                                    manager.selectedSnapshotKey = live.key
                                    manager.selectedAppBundleID = nil
                                }
                        } else {
                            Text("No active layout for this screen config".localized(appLanguage))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 8)
                        }

                        // SCREEN ID — fixed below the live layout row
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SCREEN ID".localized(appLanguage))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.tertiary)
                            Text(manager.currentFingerprint.key)
                                .font(.system(size: 8).monospaced())
                                .foregroundStyle(.tertiary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 8)
                    }

                    // SAVED SESSIONS SECTION — demoted, and collapsible, once the
                    // Auto layout is doing the everyday work.
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { savedSessionsOpened = !sessionsExpanded }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.right")
                                    .mainWindowSymbolAnimation(.wiggle, capturesClicks: false)
                                    .font(.system(size: 9, weight: .bold))
                                    .rotationEffect(.degrees(sessionsExpanded ? 90 : 0))
                                Text("SAVED SESSIONS".localized(appLanguage))
                                    .font(.system(size: 11, weight: .bold))
                                if !sessionsExpanded, !savedSnapshots.isEmpty {
                                    Text("\(savedSnapshots.count)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                        .mainWindowSymbolHoverRegion()

                        if sessionsExpanded {
                            if savedSnapshots.isEmpty {
                                Text("No saved sessions".localized(appLanguage))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.leading, 8)
                            } else {
                                ForEach(savedSnapshots, id: \.key) { item in
                                    snapshotRow(item.snapshot, key: item.key, isLive: false)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .liquidGlass(
                                            isSelected: manager.selectedSnapshotKey == item.key,
                                            prominent: false,
                                            tint: themeColor.color(seed: 1),
                                            isHovered: hoveredKey == item.key
                                        )
                                        .contentShape(Rectangle())
                                        .mainWindowSymbolHoverRegion()
                                        .onHover { isHovered in
                                            if isHovered { hoveredKey = item.key }
                                            else if hoveredKey == item.key { hoveredKey = nil }
                                        }
                                        .onTapGesture {
                                            manager.selectedSnapshotKey = item.key
                                            manager.selectedAppBundleID = nil
                                        }
                                        .contextMenu {
                                            Button("Restore") {
                                                manager.restore(key: item.key)
                                            }
                                            Divider()
                                            Button("Delete", role: .destructive) {
                                                manager.deleteSnapshot(key: item.key)
                                                if manager.selectedSnapshotKey == item.key { manager.selectedSnapshotKey = nil }
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Remember")
        }
    }

    // MARK: - Auto layout hero

    /// Thin adapter. The card itself takes plain values so it can be rendered
    /// and looked at without a WindowManager behind it.
    private var autoLayoutHero: some View {
        // The unwritten capture is included, so the card describes the same
        // arrangement the Restore button would apply. `pending` is not published,
        // so the label can be up to one tick behind; the tick below is what moves
        // it, and the age it shows is approximate anyway.
        let currentKey = manager.currentFingerprint.key
        // Only the captures that could be restored onto the screens in front of
        // the user. An entry for another configuration is refused by
        // `snapshot(from:)`, so listing it offers a choice that does nothing.
        //
        // This also fixes a duplicate the unfiltered list could produce: the
        // hero is the current configuration's newest capture, while
        // `dropFirst()` below drops the newest of ALL configurations, so
        // whenever those differed the hero appeared again in the earlier list.
        let entries = manager.autoSaveStore?.entries(forScreenKey: currentKey) ?? []
        let entry = manager.autoSaveStore?.entry(forScreenKey: currentKey)
            ?? entries.first
        // Ticked once a minute. `now` was injectable so both states could be
        // rendered, but nothing drove it: a card built once kept the `Date()`
        // it was constructed with, so "3 minutes ago" froze and the stale
        // threshold never arrived on a sidebar nobody touched. The age is the
        // one thing here that changes without anyone doing anything.
        return TimelineView(.periodic(from: .now, by: 60)) { context in
        AutoLayoutHeroCard(
            capturedAt: entry?.capturedAt,
            windowCount: entry?.windowCount ?? 0,
            screenName: entry.map { $0.readableScreenKey ?? $0.screenKey },
            matchesCurrentScreens: manager.autoLayoutMatchesCurrentScreens,
            tint: themeColor.color(seed: 0),
            language: appLanguage,
            onRestore: { manager.restoreAutoLayout() },
            earlier: entries.dropFirst().map {
                AutoLayoutHeroCard.EarlierCapture(
                    id: $0.id,
                    capturedAt: $0.capturedAt,
                    windowCount: $0.windowCount,
                    matchesCurrentScreens: $0.screenKey == currentKey)
            },
            onRestoreEarlier: { manager.restoreAutoLayout(entryID: $0) },
            now: context.date
        )
        }
    }

    func snapshotRow(_ snapshot: LayoutSnapshot, key: String, isLive: Bool) -> some View {
        let isApplicable = isLive || (manager.currentApplicableSnapshot?.id == snapshot.id)
        let rowTint = isApplicable ? themeColor.color(seed: 0) : Color.primary
        let displayCount = ScreenFingerprint.from(key: snapshot.screenKey).displays.count
        let systemIcon = displayCount > 1 ? "display.2" : "display"
        return HStack(spacing: 12) {
            Image(systemName: systemIcon)
                .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
                .font(.system(size: 18))
                .foregroundStyle(isApplicable ? themeColor.color(seed: 0) : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(snapshot.displayName)
                        .font(.system(.headline, design: .rounded).weight(.medium))
                        .lineLimit(1)
                    if isLive {
                        Text("Live".localized(appLanguage))
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(themeColor.color(seed: 3).opacity(0.15))
                            .foregroundStyle(themeColor.color(seed: 3))
                            .clipShape(Capsule())
                    }
                }

                if isLive {
                    Text(ScreenFingerprint.from(key: snapshot.screenKey).readableName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(themeColor.color(seed: 4))
                        .lineLimit(1)
                }

                Text("\(snapshot.previewRecords.count) windows · \(snapshot.updatedAt.formatted(.relative(presentation: .named).locale(currentLocale)))")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            ScreenLayoutThumbnail(
                screenKey: snapshot.screenKey,
                tint: rowTint,
                isLive: isLive,
                isHighlighted: isApplicable
            )
        }
    }
}

// MARK: - Snapshot Detail View

struct SnapshotDetailView: View {
    @EnvironmentObject var manager: WindowManager
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    let snapshot: LayoutSnapshot
    let key: String

    var isPhysicalMismatch: Bool {
        let current = manager.currentFingerprint
        let snapFP = ScreenFingerprint.from(key: snapshot.screenKey)
        
        let currentUUIDs = Set(current.displays.compactMap { $0.uuid })
        let snapUUIDs = Set(snapFP.displays.compactMap { $0.uuid })
        
        // If models match (name + resolution) but physical units (UUIDs) differ
        return current.modelKey == snapFP.modelKey && currentUUIDs != snapUUIDs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.displayName)
                                .font(.system(.title2, design: .rounded).weight(.semibold))
                            Text(ScreenFingerprint.from(key: snapshot.screenKey).readableName)
                                .font(.caption.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                        
                        HStack(spacing: 24) {
                            statPill(label: "Windows".localized(appLanguage), value: "\(snapshot.previewRecords.count)")
                            statPill(label: "Created".localized(appLanguage), value: snapshot.createdAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: currentLocale)))
                            statPill(label: "Updated".localized(appLanguage), value: snapshot.updatedAt.formatted(.relative(presentation: .named).locale(currentLocale)))
                        }
                    }
                    
                    if let location = snapshot.location, !snapshot.isAutoSave && manager.store.saveLocationEnabled {
                        LocationBlock(snapshotID: key, location: location, isUpdated: snapshot.updatedAt.timeIntervalSince(snapshot.createdAt) > 1)
                    }
                }
                

                let hasMissingScreens = !manager.canRestore(snapshot: snapshot)
                if isPhysicalMismatch || hasMissingScreens {
                    SavedSessionDisplayWarnings(
                        hasPhysicalMismatch: isPhysicalMismatch,
                        hasMissingScreens: hasMissingScreens,
                        appLanguage: appLanguage
                    )
                }
            }
            .padding(24)
            .background(Color.clear)

            Divider()

            // Window list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(snapshot.records.filter { !$0.windowID.appBundleID.isEmpty }) { record in
                            let isForeground = record.windowID.appBundleID == snapshot.foregroundBundleID
                            let isCurrentApp = record.windowID.appBundleID == manager.selectedAppBundleID
                            windowRow(record, isForeground: isForeground, isCurrentApp: isCurrentApp)
                                .id(record.id)
                        }
                    }
                    .padding(24)
                }
                .onAppear {
                    scrollToCurrentApp(using: proxy)
                }
                .onChange(of: manager.selectedAppBundleID) { _, _ in
                    scrollToCurrentApp(using: proxy)
                }
                .onChange(of: manager.selectedSnapshotKey) { _, _ in
                    // Opening the app from the menu changes the session and
                    // the selected app together. Re-run after the session
                    // changes so the target card exists before scrolling.
                    scrollToCurrentApp(using: proxy)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Returns true if this window was captured from a different Mission Control Space
    /// (i.e. it had no visible window on the current Space at capture time).
    /// Set precisely during capture — no false positives from Fill Screen / maximized windows.
    private func isEntireScreen(_ record: WindowRecord) -> Bool {
        record.isFullScreenMode
    }

    func windowRow(_ record: WindowRecord, isForeground: Bool, isCurrentApp: Bool) -> some View {
        let isFull = isEntireScreen(record)
        let rowTint = isFull ? Color.indigo : themeColor.color(seed: 6)
        
        return WindowRowContainer(
            record: record,
            isForeground: isForeground,
            isCurrentApp: isCurrentApp,
            isFull: isFull,
            rowTint: rowTint,
            snapshot: snapshot,
            key: key,
            appLanguage: appLanguage,
            themeColor: themeColor
        )
    }

    private func scrollToCurrentApp(using proxy: ScrollViewProxy) {
        guard let currentAppID = manager.selectedAppBundleID,
              let record = snapshot.records.first(where: { $0.windowID.appBundleID == currentAppID }) else {
            return
        }
        withAnimation(.smooth) {
            proxy.scrollTo(record.id, anchor: .center)
        }
    }

    func statPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption.weight(.medium))
        }
    }
}

/// Compact display warnings for a saved session. When both conditions apply,
/// they share one card and are separated into readable rows.
private struct SavedSessionDisplayWarnings: View {
    let hasPhysicalMismatch: Bool
    let hasMissingScreens: Bool
    let appLanguage: AppLanguage

    private struct Warning: Identifiable {
        let id: String
        let title: String
        let message: String
        let systemImage: String
    }

    private var warnings: [Warning] {
        var result: [Warning] = []

        if hasPhysicalMismatch {
            result.append(Warning(
                id: "physicalMismatch",
                title: "New monitor detected with the same name".localized(appLanguage),
                message: "This is a different physical unit than the one in this session.".localized(appLanguage),
                systemImage: "display.and.arrow.down"
            ))
        }

        if hasMissingScreens {
            result.append(Warning(
                id: "missingScreens",
                title: "External Screens Missing".localized(appLanguage),
                message: "Connect the required displays to enable restoration of this session.".localized(appLanguage),
                systemImage: "display.trianglebadge.exclamationmark"
            ))
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(warnings.enumerated()), id: \.element.id) { index, warning in
                if index > 0 {
                    Divider()
                        .padding(.leading, 42)
                }

                HStack(spacing: 10) {
                    Image(systemName: warning.systemImage)
                        .mainWindowSymbolAnimation(.breathe)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.72))
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(warning.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Text(warning.message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .mainWindowSymbolHoverRegion()
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.14), lineWidth: 1)
                }
        }
        .padding(.horizontal, 2)
    }
}

struct WindowRowContainer: View {
    let record: WindowRecord
    let isForeground: Bool
    let isCurrentApp: Bool
    let isFull: Bool
    let rowTint: Color
    let snapshot: LayoutSnapshot
    let key: String
    let appLanguage: AppLanguage
    let themeColor: ThemeColor
    @EnvironmentObject var manager: WindowManager
    @State private var isRowHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon: full-screen variant vs normal positioned preview
            if isFull {
                FullScreenPreviewIcon(tint: rowTint)
                    .frame(width: 52, height: 34)
            } else {
                WindowPreviewIcon(record: record, tint: rowTint)
                    .frame(width: 52, height: 34)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    AppIconView(bundleID: record.windowID.appBundleID)
                        .frame(width: 15, height: 15)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                    Text(record.windowID.appName ?? record.windowID.appBundleID)
                        .font(.system(.headline, design: .rounded).weight(.medium))
                    if isCurrentApp {
                        Text("Active".localized(appLanguage))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(Color.green)
                            .clipShape(Capsule())
                    }
                    if isFull {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .mainWindowSymbolAnimation(.wiggle)
                                .font(.system(size: 8, weight: .bold))
                            Text("Full Screen".localized(appLanguage))
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.indigo.opacity(0.15))
                        .foregroundStyle(Color.indigo)
                        .clipShape(Capsule())
                    }
                    if isForeground {
                        Image(systemName: "square.3.layers.3d.top.filled")
                            .mainWindowSymbolAnimation(.breathePlain)
                            .font(.system(size: 10))
                            .foregroundStyle(themeColor.color(seed: 5))
                            .help("This app will be brought to the front upon restore")
                    }
                }

                HStack(spacing: 4) {
                    if let screenName = record.screenName {
                        Text(lz(screenName))
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(rowTint.opacity(0.1))
                            .foregroundStyle(rowTint)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    if !record.windowID.windowTitle.isEmpty {
                        Text(record.windowID.windowTitle)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            
            if !snapshot.isAutoSave {
                HStack(spacing: 8) {
                    let appID = record.windowID.appBundleID
                    let isIncluded = snapshot.commandExcludedBundleIDs.contains(appID)
                    
                    // ⌘⇧R button: always visible, showing green checkmark when enabled, dim when disabled.
                    ExcludeCommandButton(appLanguage: appLanguage, isIncluded: isIncluded) {
                        manager.toggleCommandExclusion(key: key, bundleID: appID)
                    }
                    
                    // Bring-to-front: always visible when active (filled), only on hover otherwise
                    if isForeground || isRowHovered {
                        BringToFrontButton(appLanguage: appLanguage, isActive: isForeground) {
                            manager.setForegroundApp(key: key, bundleID: appID)
                            manager.bringAppToFront(bundleID: appID)
                        }
                    } else {
                        Spacer().frame(width: 26, height: 26)
                    }
                    
                    DeleteSessionAppButton(appLanguage: appLanguage) {
                        manager.removeAppFromSnapshot(key: key, windowID: record.windowID)
                    }
                }
            }
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(record.globalFrame.width.clampedInt) × \(record.globalFrame.height.clampedInt)")
                    .font(.footnote.monospaced())
                Text("(\(record.globalFrame.origin.x.clampedInt), \(record.globalFrame.origin.y.clampedInt))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .liquidGlass(isSelected: isCurrentApp || isForeground, prominent: false, tint: themeColor.color(seed: 6), isHovered: isRowHovered)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isRowHovered ? themeColor.color(seed: 6).opacity(0.35) : Color.clear, lineWidth: 1.5)
        }
        .mainWindowSymbolHoverRegion()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isRowHovered = hovering
            }
        }
    }
}



struct LocationBlock: View {
    @EnvironmentObject var manager: WindowManager
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    let snapshotID: String
    let location: LocationInfo
    let isUpdated: Bool
    
    @State private var isEditing = false
    @State private var editedAddress: String = ""
    @FocusState private var isFocused: Bool
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            // Map Preview
            ZStack {
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )))) {
                    Marker("", coordinate: coordinate)
                }
                .id(snapshotID) // Force recreation when switching layouts to ensure position updates
                .allowsHitTesting(false)
                
                Color.black.opacity(0.01)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let url = URL(string: "http://maps.apple.com/?ll=\(location.latitude),\(location.longitude)&q=Saved%20Location")!
                        NSWorkspace.shared.open(url)
                    }
            }
            .frame(width: 100, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .fixedSize()
            
            VStack(alignment: .leading, spacing: 3) {
                Label {
                    Text((isUpdated ? "Saved&Updated At" : "Saved At").localized(appLanguage))
                } icon: {
                    Image(systemName: "location.fill")
                        .mainWindowSymbolAnimation(.breathe, capturesClicks: false)
                }
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.secondary)
                    .opacity(0.8)
                    .mainWindowSymbolHoverRegion()
                
                if isEditing {
                    TextField("Location Name", text: $editedAddress, onCommit: {
                        manager.updateLocationAddress(key: snapshotID, newAddress: editedAddress)
                        isEditing = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .focused($isFocused)
                    .onAppear {
                        editedAddress = location.address ?? "\(location.latitude), \(location.longitude)"
                        isFocused = true
                    }
                } else {
                    Text(location.address ?? "\(location.latitude), \(location.longitude)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: 170, alignment: .leading)
                        .onTapGesture {
                            isEditing = true
                        }
                }
                
                if !isEditing {
                    Text("Click to rename".localized(appLanguage))
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 170, alignment: .leading)
        }
        .padding(10)
        .fixedSize(horizontal: true, vertical: true)
        .background {
            VisualEffectView(material: .selection, blendingMode: .withinWindow)
                .opacity(0.4)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
        }
    }
}

struct DeleteSessionAppButton: View {
    let appLanguage: AppLanguage
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isHovered ? Color.red.opacity(0.15) : Color.clear)
                .frame(width: 26, height: 26)
            Image(systemName: "trash")
                .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovered ? Color.red : Color.red.opacity(0.7))
        }
        .frame(width: 26, height: 26)
        .contentShape(Circle())
        .mainWindowSymbolHoverRegion()
        .onTapGesture { action() }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
        .help("Remove from Session".localized(appLanguage))
    }
}

struct ExcludeCommandButton: View {
    let appLanguage: AppLanguage
    let isIncluded: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            // Background capsule
            Capsule()
                .fill(isIncluded
                      ? Color.green.opacity(0.1)
                      : (isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.02)))
                .frame(width: 56, height: 26)
            
            // Command badge — use a ZStack.topTrailing for the inclusion checkmark badge
            ZStack(alignment: .topTrailing) {
                Text("⌘⇧R")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isIncluded 
                                     ? Color.green.opacity(0.85) 
                                     : (isHovered ? Color.primary.opacity(0.65) : Color.secondary.opacity(0.35)))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                
                if isIncluded {
                    Image(systemName: "checkmark")
                        .mainWindowSymbolAnimation(.breathePlain, capturesClicks: false)
                        .font(.system(size: 6.5, weight: .black))
                        .foregroundStyle(Color.white)
                        .padding(1.5)
                        .background(Color.green, in: Circle())
                        .offset(x: 3, y: -3)
                }
            }
        }
        .frame(width: 60, height: 30)
        .contentShape(Capsule())
        .mainWindowSymbolHoverRegion()
        .onTapGesture { action() }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
        .help(isIncluded
              ? "Disable Command Trigger for this app".localized(appLanguage)
              : "Enable Command Trigger for this app".localized(appLanguage))
    }
}

struct BringToFrontButton: View {
    let appLanguage: AppLanguage
    let isActive: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isActive
                      ? Color.accentColor
                      : (isHovered ? Color.accentColor.opacity(0.15) : Color.clear))
                .frame(width: 26, height: 26)
            Image(systemName: "square.3.layers.3d.top.filled")
                .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive ? Color.white : (isHovered ? Color.accentColor : Color.secondary))
        }
        .frame(width: 26, height: 26)
        .contentShape(Circle())
        .mainWindowSymbolHoverRegion()
        .onTapGesture { action() }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovering }
        }
        .help(isActive
              ? "Click to unset Bring to Front".localized(appLanguage)
              : "Bring to Front".localized(appLanguage))
    }
}

// MARK: - Auto Layout Mode Views (Active strictly when autoSaveEnabled is true)

struct AutoLayoutCenterView: View {
    @EnvironmentObject var manager: WindowManager
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var isEarlierExpanded: Bool = true

    private var entries: [AutoSaveEntry] {
        // Restorable here, not merely recorded somewhere. See
        // `AutoSaveStore.entries(forScreenKey:)`.
        manager.autoSaveStore?.entries(forScreenKey: manager.currentFingerprint.key) ?? []
    }

    private var rememberedEntries: [AutoSaveEntry] {
        manager.autoSaveStore?.visibleDisplayEntries ?? []
    }

    private var currentEntry: AutoSaveEntry? {
        manager.autoSaveStore?.entry(forScreenKey: manager.currentFingerprint.key)
            ?? entries.first
    }

    private var activeEntry: AutoSaveEntry? {
        if let id = manager.selectedAutoSaveEntryID,
           let found = (rememberedEntries + entries).first(where: { $0.id == id }) {
            return found
        }
        return currentEntry
    }

    private var activeSnapshot: LayoutSnapshot? {
        if let entry = activeEntry {
            return LayoutSnapshot(
                name: entry.readableScreenKey ?? manager.currentFingerprint.readableName,
                screenKey: entry.screenKey,
                readableScreenKey: entry.readableScreenKey,
                records: entry.records,
                createdAt: entry.capturedAt,
                updatedAt: entry.capturedAt,
                location: nil,
                isAutoSave: true,
                foregroundBundleID: nil,
                commandExcludedBundleIDs: []
            )
        }
        return manager.autoLayoutSnapshot
    }

    var body: some View {
        GeometryReader { outerGeo in
            VStack(alignment: .leading, spacing: 16) {
                // Return to latest banner if an earlier capture is selected
                if let selectedID = manager.selectedAutoSaveEntryID,
                   selectedID != currentEntry?.id,
                   let entry = activeEntry {
                    earlierCaptureBanner(entry: entry)
                }

                // 1. Auto Layout Card on top (takes natural height)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let currentKey = manager.currentFingerprint.key
                    let entry = activeEntry
                    AutoLayoutHeroCard(
                        capturedAt: entry?.capturedAt,
                        windowCount: entry?.windowCount ?? 0,
                        screenName: entry.map { $0.readableScreenKey ?? $0.screenKey },
                        matchesCurrentScreens: entry?.screenKey == currentKey,
                        tint: themeColor.color(seed: 0),
                        language: appLanguage,
                        onRestore: {
                            if let id = entry?.id {
                                manager.restoreAutoLayout(entryID: id)
                            } else {
                                manager.restoreAutoLayout()
                            }
                        },
                        earlier: entries.dropFirst().map {
                            AutoLayoutHeroCard.EarlierCapture(
                                id: $0.id,
                                capturedAt: $0.capturedAt,
                                windowCount: $0.windowCount,
                                matchesCurrentScreens: $0.screenKey == currentKey
                            )
                        },
                        onRestoreEarlier: { manager.restoreAutoLayout(entryID: $0) },
                        selectedCaptureID: manager.selectedAutoSaveEntryID,
                        onSelectEarlier: { tappedID in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if manager.selectedAutoSaveEntryID == tappedID {
                                    manager.selectedAutoSaveEntryID = nil
                                } else {
                                    manager.selectedAutoSaveEntryID = tappedID
                                }
                            }
                        },
                        isExpanded: $isEarlierExpanded,
                        now: context.date
                    )
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 1)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                Divider()

                // 2. Visual Preview at the bottom (strictly fills remaining viewport height)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label {
                            Text("Window Arrangement".localized(appLanguage))
                        } icon: {
                            Image(systemName: "rectangle.3.group")
                                .mainWindowSymbolAnimation(.wiggleByLayer)
                        }
                            .font(.system(.headline, design: .rounded))
                            .mainWindowSymbolHoverRegion()
                        Spacer()
                        if let count = activeEntry?.previewWindowCount ?? activeSnapshot?.previewRecords.count {
                            Text(count == 1 ? "1 window".localized(appLanguage) : "\(count) \("windows".localized(appLanguage))")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08), in: Capsule())
                        }
                    }

                    if let snap = activeSnapshot {
                        LayoutPreviewView(
                            snapshot: snap,
                            selectedRecordID: manager.selectedRecordID,
                            tint: themeColor.color(seed: 0),
                            enable3DHover: true,
                            onSelectRecord: { recID in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    manager.selectedRecordID = (manager.selectedRecordID == recID ? nil : recID)
                                }
                            }
                        )
                        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: .infinity)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: snap.previewRecords.count)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: .infinity)
                            .overlay {
                                Text("No layout captured yet".localized(appLanguage))
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: outerGeo.size.width, height: outerGeo.size.height, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isEarlierExpanded = true
        }
    }

    private func earlierCaptureBanner(entry: AutoSaveEntry) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .mainWindowSymbolAnimation(.wiggleByLayer)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeColor.color(seed: 0))
                    .frame(width: 22, height: 22)
                    .background(themeColor.color(seed: 0).opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Viewing Earlier Capture".localized(appLanguage))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text(entry.capturedAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .mainWindowSymbolHoverRegion()

            Spacer(minLength: 10)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    manager.selectedAutoSaveEntryID = nil
                    isEarlierExpanded = false
                }
            } label: {
                Label {
                    Text("Return to Latest".localized(appLanguage))
                } icon: {
                    Image(systemName: "arrow.uturn.backward")
                        .mainWindowSymbolAnimation(.flip, capturesClicks: false)
                }
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .mainWindowSymbolHoverRegion()
            .controlSize(.small)
            .tint(themeColor.color(seed: 0))
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityHint(Text("Show the newest automatic capture".localized(appLanguage)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeColor.color(seed: 0).opacity(colorScheme == .dark ? 0.13 : 0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(themeColor.color(seed: 0).opacity(colorScheme == .dark ? 0.28 : 0.18), lineWidth: 1)
        }
    }
}

struct AutoLayoutSidebarWindowListView: View {
    @EnvironmentObject var manager: WindowManager
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    private var entries: [AutoSaveEntry] {
        // Restorable here, not merely recorded somewhere. See
        // `AutoSaveStore.entries(forScreenKey:)`.
        manager.autoSaveStore?.entries(forScreenKey: manager.currentFingerprint.key) ?? []
    }

    private var rememberedEntries: [AutoSaveEntry] {
        manager.autoSaveStore?.visibleDisplayEntries ?? []
    }

    /// Remembered display configurations, newest first, with the live setup on top.
    private var rememberedDisplays: [AutoSaveEntry] {
        let currentKey = manager.currentFingerprint.key
        return rememberedEntries.sorted { a, b in
            let aIsLive = a.screenKey == currentKey
            let bIsLive = b.screenKey == currentKey
            if aIsLive != bIsLive { return aIsLive }
            return a.capturedAt > b.capturedAt
        }
    }

    private var activeEntry: AutoSaveEntry? {
        if let id = manager.selectedAutoSaveEntryID,
           let found = (rememberedEntries + entries).first(where: { $0.id == id }) {
            return found
        }
        return manager.autoSaveStore?.entry(forScreenKey: manager.currentFingerprint.key)
            ?? rememberedEntries.first
            ?? entries.first
    }

    private var records: [WindowRecord] {
        activeEntry?.previewRecords.filter { !$0.windowID.appBundleID.isEmpty } ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. REMEMBERED DISPLAYS Section (Above Windows List)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("REMEMBERED DISPLAYS".localized(appLanguage))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !rememberedDisplays.isEmpty {
                            Text("\(rememberedDisplays.count)")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(themeColor.color(seed: 0).opacity(0.15))
                                .foregroundStyle(themeColor.color(seed: 0))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                    if rememberedDisplays.isEmpty {
                        Text("No remembered displays".localized(appLanguage))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                    } else {
                        LazyVStack(spacing: 6) {
                            ForEach(rememberedDisplays) { displayEntry in
                                let isSelected = (activeEntry?.screenKey == displayEntry.screenKey)
                                let isLive = displayEntry.screenKey == manager.currentFingerprint.key

                                AutoLayoutRememberedDisplayRow(
                                    entry: displayEntry,
                                    isSelected: isSelected,
                                    isLive: isLive,
                                    themeColor: themeColor,
                                    appLanguage: appLanguage
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        manager.selectedAutoSaveEntryID = displayEntry.id
                                        manager.selectedRecordID = nil
                                    }
                                }
                            }
                        }
                    }
                }

                Divider()
                    .padding(.horizontal, 6)

                // 2. LATEST CAPTURED WINDOWS Section (Below Displays List)
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("LATEST CAPTURED WINDOWS".localized(appLanguage))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !records.isEmpty {
                                Text("\(records.count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(themeColor.color(seed: 0).opacity(0.15))
                                    .foregroundStyle(themeColor.color(seed: 0))
                                    .clipShape(Capsule())
                            }
                        }

                        if let entry = activeEntry {
                            Text(String(format: "From capture %@".localized(appLanguage), entry.capturedAt.formatted(.relative(presentation: .named))))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)

                    if records.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "macwindow.badge.plus")
                                .mainWindowSymbolAnimation(.wiggleByLayer)
                                .font(.system(size: 28))
                                .foregroundStyle(.tertiary)
                            Text("No windows captured yet".localized(appLanguage))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("Windows are captured automatically as you rearrange them.".localized(appLanguage))
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 12)
                        .mainWindowSymbolHoverRegion()
                    } else {
                        LazyVStack(spacing: 6) {
                            ForEach(records) { record in
                                AutoLayoutSidebarWindowRow(
                                    record: record,
                                    isSelected: manager.selectedRecordID == record.id,
                                    themeColor: themeColor,
                                    appLanguage: appLanguage
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        if manager.selectedRecordID == record.id {
                                            manager.selectedRecordID = nil
                                        } else {
                                            manager.selectedRecordID = record.id
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(10)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Remember")
    }
}

// MARK: - Remembered Display Row (for Auto Layout sidebar)

struct AutoLayoutRememberedDisplayRow: View {
    let entry: AutoSaveEntry
    let isSelected: Bool
    let isLive: Bool
    let themeColor: ThemeColor
    let appLanguage: AppLanguage

    @State private var isHovered = false

    var body: some View {
        let displayCount = ScreenFingerprint.from(key: entry.screenKey).displays.count
        let systemIcon = displayCount > 1 ? "display.2" : "display"
        let displayName = entry.readableScreenKey ?? ScreenFingerprint.from(key: entry.screenKey).readableName
        let tint = isLive ? themeColor.color(seed: 0) : Color.primary

        HStack(spacing: 10) {
            Image(systemName: systemIcon)
                .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
                .font(.system(size: 16))
                .foregroundStyle(isLive ? themeColor.color(seed: 0) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .lineLimit(1)

                    if isLive {
                        Text("Live".localized(appLanguage))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(themeColor.color(seed: 3).opacity(0.15))
                            .foregroundStyle(themeColor.color(seed: 3))
                            .clipShape(Capsule())
                    }
                }

                Text(String(format: "%d windows · %@", entry.previewWindowCount, entry.capturedAt.formatted(.relative(presentation: .named))))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            ScreenLayoutThumbnail(
                screenKey: entry.screenKey,
                tint: tint,
                isLive: isLive,
                isHighlighted: isSelected
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidGlass(
            isSelected: isSelected,
            prominent: isLive,
            tint: themeColor.color(seed: 1),
            isHovered: isHovered
        )
        .contentShape(Rectangle())
        .mainWindowSymbolHoverRegion()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

struct AutoLayoutSidebarWindowRow: View {
    let record: WindowRecord
    let isSelected: Bool
    let themeColor: ThemeColor
    let appLanguage: AppLanguage

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // App Icon
            AppIconView(bundleID: record.windowID.appBundleID)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(record.windowID.appName ?? record.windowID.appBundleID)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)

                    if record.isFullScreenMode {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .mainWindowSymbolAnimation(.wiggle, capturesClicks: false)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.indigo)
                    }
                }

                if !record.windowID.windowTitle.isEmpty {
                    Text(record.windowID.windowTitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if let screenName = record.screenName {
                        Text(screenName)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(themeColor.color(seed: 0).opacity(0.1))
                            .foregroundStyle(themeColor.color(seed: 0))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    Text("\(record.globalFrame.width.clampedInt) × \(record.globalFrame.height.clampedInt)")
                        .font(.system(size: 10).monospaced())
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected
                      ? themeColor.color(seed: 0).opacity(0.18)
                      : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? themeColor.color(seed: 0).opacity(0.4) : Color.clear, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .mainWindowSymbolHoverRegion()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
