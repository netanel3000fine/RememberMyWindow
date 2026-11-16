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
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var hoveredKey: String? = nil

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

                    // SAVED SESSIONS SECTION
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SAVED SESSIONS".localized(appLanguage))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                            .accessibilityAddTraits(.isHeader)

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
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 1)
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
            captures: AutoLayoutCapturePresentation.make(
                from: entries,
                displayScreenKey: currentKey,
                currentScreenKey: currentKey
            ),
            onRestoreCapture: { manager.restoreAutoLayout(entryID: $0) },
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
                Text(snapshot.displayName)
                    .font(.system(.headline, design: .rounded).weight(.medium))
                    .lineLimit(1)

                if isLive {
                    Text(ScreenFingerprint.from(key: snapshot.screenKey).readableName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
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
                isHighlighted: isApplicable,
                badgeStatus: isApplicable ? .live : nil
            )
        }
    }
}

// MARK: - Snapshot Detail View

struct SnapshotDetailView: View {
    @EnvironmentObject var manager: WindowManager
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @AppStorage("appListViewMode") private var appListViewMode: AppListViewMode = .list
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
        GeometryReader { outerGeo in
            let locationLayout: LocationBlock.DisplayMode = {
                if outerGeo.size.width < 400 {
                    return .compact
                }
                if outerGeo.size.width < 520 {
                    return .intermediate
                }
                return .expanded
            }()
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snapshot.displayName)
                                    .font(.system(.title2, design: .rounded).weight(.semibold))
                                    .lineLimit(1)
                                Text(ScreenFingerprint.from(key: snapshot.screenKey).readableName)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            
                            HStack(spacing: locationLayout == .expanded ? 24 : 16) {
                                statPill(label: "Windows".localized(appLanguage), value: "\(snapshot.previewRecords.count)")
                                statPill(label: "Created".localized(appLanguage), value: snapshot.createdAt.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: currentLocale)))
                                statPill(label: "Updated".localized(appLanguage), value: snapshot.updatedAt.formatted(.relative(presentation: .named).locale(currentLocale)))
                            }
                        }
                        
                        Spacer(minLength: 8)

                        if let location = snapshot.location, !snapshot.isAutoSave && manager.store.saveLocationEnabled {
                            LocationBlock(
                                snapshotID: key,
                                location: location,
                                isUpdated: snapshot.updatedAt.timeIntervalSince(snapshot.createdAt) > 1,
                                layout: locationLayout
                            )
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

            // Window list / grid
            ScrollViewReader { proxy in
                ScrollView {
                    let records = snapshot.records.deduplicatedByApp.filter { !$0.windowID.appBundleID.isEmpty }
                    if appListViewMode == .grid {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(records) { record in
                                let isForeground = record.windowID.appBundleID == snapshot.foregroundBundleID
                                let isCurrentApp = record.windowID.appBundleID == manager.selectedAppBundleID
                                windowGrid(record, isForeground: isForeground, isCurrentApp: isCurrentApp)
                                    .id(record.id)
                            }
                        }
                        .padding(20)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(records) { record in
                                let isForeground = record.windowID.appBundleID == snapshot.foregroundBundleID
                                let isCurrentApp = record.windowID.appBundleID == manager.selectedAppBundleID
                                windowRow(record, isForeground: isForeground, isCurrentApp: isCurrentApp)
                                    .id(record.id)
                            }
                        }
                        .padding(24)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appListViewMode)
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
            .frame(width: outerGeo.size.width, height: outerGeo.size.height, alignment: .topLeading)
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
        let rowTint = isFull ? Color.green : themeColor.color(seed: 6)
        
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

    func windowGrid(_ record: WindowRecord, isForeground: Bool, isCurrentApp: Bool) -> some View {
        let isFull = isEntireScreen(record)
        let rowTint = isFull ? Color.green : themeColor.color(seed: 6)

        return WindowGridCard(
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
              let record = snapshot.records.deduplicatedByApp.first(where: { $0.windowID.appBundleID == currentAppID }) else {
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
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
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
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                    if isCurrentApp {
                        Text("Active".localized(appLanguage))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.primary)
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
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.primary)
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
                            .foregroundStyle(.primary)
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
                let appID = record.windowID.appBundleID
                let isCommandTriggerActive = snapshot.commandExcludedBundleIDs.contains(appID)
                let showsCommandTrigger = isRowHovered || isCommandTriggerActive
                let showsBringToFront = isRowHovered || isForeground

                // Keep active state visible, but remove inactive controls from
                // the layout entirely so the app name gets the available width.
                if showsCommandTrigger || showsBringToFront || isRowHovered {
                    HStack(spacing: 8) {
                        if showsCommandTrigger {
                            ExcludeCommandButton(appLanguage: appLanguage, isIncluded: isCommandTriggerActive) {
                                manager.toggleCommandExclusion(key: key, bundleID: appID)
                            }
                        }

                        if showsBringToFront {
                            BringToFrontButton(appLanguage: appLanguage, isActive: isForeground) {
                                manager.setForegroundApp(key: key, bundleID: appID)
                                manager.bringAppToFront(bundleID: appID)
                            }
                        }

                        if isRowHovered {
                            DeleteSessionAppButton(appLanguage: appLanguage) {
                                manager.removeAppFromSnapshot(key: key, windowID: record.windowID)
                            }
                        }
                    }
                    .transition(.opacity)
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
            withAnimation(.snappy(duration: 0.15)) {
                isRowHovered = hovering
            }
        }
    }
}

// MARK: - View Mode

enum AppListViewMode: String {
    case list, grid
}

// MARK: - Grid Card

struct WindowGridCard: View {
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
    @State private var isCardHovered = false
    private var appID: String { record.windowID.appBundleID }
    private var isCommandTriggerActive: Bool { snapshot.commandExcludedBundleIDs.contains(appID) }
    private var showsHoverActions: Bool { !snapshot.isAutoSave && isCardHovered }

    var body: some View {
        VStack(spacing: 0) {
            // ── Window-position thumbnail ──────────────────────────────
            ZStack {
                if isFull {
                    FullScreenPreviewIcon(tint: rowTint)
                        .frame(width: 68, height: 44)
                } else {
                    // WindowPreviewIcon now fills its proposed 68×44 frame,
                    // matching the visual size of the full-screen thumbnail.
                    WindowPreviewIcon(record: record, tint: rowTint)
                        .frame(width: 68, height: 44)
                }
            }
            // ── Top-corner badges hanging just outside the thumbnail ───
            // Negative offsets push badges beyond the thumbnail corners
            // into the surrounding card padding, mirroring the full-screen
            // card's badge placement.
            .overlay(alignment: .topLeading) {
                if isCommandTriggerActive && !showsHoverActions {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "command")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(3.5)
                            .background(Circle().fill(.ultraThinMaterial))

                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                            .offset(x: 1, y: -1)
                    }
                    .offset(x: -6, y: -6)
                    .help("Command Trigger active for this app".localized(appLanguage))
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isForeground && !showsHoverActions {
                    Image(systemName: "square.3.layers.3d.top.filled")
                        .mainWindowSymbolAnimation(.breathePlain)
                        .font(.system(size: 9))
                        .foregroundStyle(themeColor.color(seed: 5))
                        .padding(3)
                        .background(Circle().fill(.ultraThinMaterial))
                        .offset(x: 6, y: -6)
                        .help("This app will be brought to the front upon restore".localized(appLanguage))
                        .transition(.opacity)
                }
            }
            // ── Expand to card area after badges are anchored ──────────
            .frame(width: 100, height: 64)
            .overlay(alignment: .bottomTrailing) {
                // Keep the app recognizable without adding another row to the card.
                if !showsHoverActions {
                    AppIconView(bundleID: appID)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.16), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1)
                        .padding(4)
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if showsHoverActions {
                    HStack(spacing: 2) {
                        ExcludeCommandButton(appLanguage: appLanguage, isIncluded: isCommandTriggerActive) {
                            manager.toggleCommandExclusion(key: key, bundleID: appID)
                        }

                        BringToFrontButton(appLanguage: appLanguage, isActive: isForeground) {
                            manager.setForegroundApp(key: key, bundleID: appID)
                            manager.bringAppToFront(bundleID: appID)
                        }

                        DeleteSessionAppButton(appLanguage: appLanguage) {
                            manager.removeAppFromSnapshot(key: key, windowID: record.windowID)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
                    .scaleEffect(0.8, anchor: .bottom)
                    .offset(y: 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 10)

            // ── App name + status ──────────────────────────────────────
            VStack(spacing: 2) {
                Text(record.windowID.appName ?? record.windowID.appBundleID)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)

                if isFull {
                    Text("Full Screen".localized(appLanguage))
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.18))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                } else if isCurrentApp {
                    Text("Active".localized(appLanguage))
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.18))
                        .foregroundStyle(.primary)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .liquidGlass(isSelected: isCurrentApp || isForeground, prominent: false, tint: themeColor.color(seed: 6), isHovered: isCardHovered)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isCardHovered ? rowTint.opacity(0.4) : Color.clear, lineWidth: 1.5)
        }
        .mainWindowSymbolHoverRegion()
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.15)) {
                isCardHovered = hovering
            }
        }
    }
}

struct LocationBlock: View {
    enum DisplayMode: Equatable {
        case compact
        case intermediate
        case expanded
    }

    @EnvironmentObject var manager: WindowManager
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    let snapshotID: String
    let location: LocationInfo
    let isUpdated: Bool
    var layout: DisplayMode = .expanded
    
    @State private var isEditing = false
    @State private var editedAddress: String = ""
    @FocusState private var isFocused: Bool
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }

    private var displayAddress: String {
        location.address ?? "\(location.latitude), \(location.longitude)"
    }

    private var mapSize: CGSize {
        layout == .intermediate
            ? CGSize(width: 80, height: 64)
            : CGSize(width: 100, height: 80)
    }

    private var mapPreview: some View {
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
        .frame(width: mapSize.width, height: mapSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .help(displayAddress)
        .fixedSize()
    }

    private func locationDetails(width: CGFloat, showsRenameHint: Bool) -> some View {
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
                    editedAddress = displayAddress
                    isFocused = true
                }
            } else {
                Text(displayAddress)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: width, alignment: .leading)
                    .onTapGesture {
                        isEditing = true
                    }
            }

            if !isEditing && showsRenameHint {
                Text("Click to rename".localized(appLanguage))
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: width, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: layout == .intermediate ? .bottom : .trailing)))
    }

    var body: some View {
        Group {
            switch layout {
            case .compact:
                mapPreview
            case .intermediate:
                VStack(alignment: .leading, spacing: 6) {
                    mapPreview
                    locationDetails(width: 150, showsRenameHint: false)
                }
                .frame(width: 150, alignment: .leading)
            case .expanded:
                HStack(spacing: 14) {
                    mapPreview
                    locationDetails(width: 170, showsRenameHint: true)
                }
            }
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
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: layout)
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
                                     ? Color.primary
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
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var activeAccent: Color { themeColor.color(seed: 0) }
    private var activeAccentText: Color {
        if themeColor.isGalaxy {
            return .black
        }
        return themeColor.onAccentColor(for: colorScheme)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isActive
                      ? activeAccent
                      : (isHovered ? activeAccent.opacity(0.15) : Color.clear))
                .frame(width: 26, height: 26)
            Image(systemName: "square.3.layers.3d.top.filled")
                .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive ? activeAccentText : (isHovered ? Color.primary : Color.secondary))
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
    @AppStorage("minimalVisualAnimations") private var minimalVisualAnimations: Bool = true
    @State private var isEarlierExpanded: Bool = true
    @State private var timelineSelectionTask: Task<Void, Never>? = nil
    @State private var pendingTimelineCaptureID: UUID? = nil
    @State private var timelineCaptureID: UUID? = nil
    @State private var hasInitializedTimelineCaptureID = false
    @State private var forceFullWindowsAnimated: Bool = false
    @State private var returnToLatestTrigger: UUID? = nil

    private let timelineUpdateDelayNanoseconds: UInt64 = 150_000_000

    private func selectCapture(_ selectionID: UUID?, timelineID: UUID?) {
        scheduleTimelineSelection(timelineID)
        if manager.selectedAutoSaveEntryID != selectionID {
            manager.selectedAutoSaveEntryID = selectionID
        }
    }

    private func scheduleTimelineSelection(_ timelineID: UUID?) {
        guard timelineSelectionTask == nil || pendingTimelineCaptureID != timelineID else { return }

        pendingTimelineCaptureID = timelineID
        timelineSelectionTask?.cancel()
        timelineSelectionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: timelineUpdateDelayNanoseconds)
            guard !Task.isCancelled else { return }

            timelineCaptureID = timelineID
            hasInitializedTimelineCaptureID = true
            pendingTimelineCaptureID = nil
            timelineSelectionTask = nil
        }
    }

    private var activeEntry: AutoSaveEntry? {
        if let id = manager.selectedAutoSaveEntryID,
           let found = (manager.autoSaveStore?.visibleEntries ?? (rememberedEntries + entries)).first(where: { $0.id == id }) {
            return found
        }
        return currentEntry
    }

    private var activeScreenKey: String {
        activeEntry?.screenKey ?? manager.currentFingerprint.key
    }

    private var displayEntries: [AutoSaveEntry] {
        manager.autoSaveStore?.entries(forScreenKey: activeScreenKey) ?? []
    }

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

    private var activeCaptures: [AutoLayoutCapturePresentation] {
        AutoLayoutCapturePresentation.make(
            from: displayEntries,
            displayScreenKey: activeScreenKey,
            currentScreenKey: manager.currentFingerprint.key
        )
    }

    private var activeCapturePresentation: AutoLayoutCapturePresentation? {
        guard let id = activeEntry?.id else { return nil }
        return activeCaptures.first(where: { $0.id == id })
    }

    /// The date in the timeline heading trails row selection slightly; the
    /// selected layout, preview, and row feedback all update immediately.
    private var timelineEntry: AutoSaveEntry? {
        guard hasInitializedTimelineCaptureID else { return activeEntry }
        guard manager.selectedAutoSaveEntryID != nil || timelineSelectionTask != nil else { return activeEntry }
        guard let timelineCaptureID else { return nil }

        return manager.autoSaveStore?.visibleEntries.first(where: { $0.id == timelineCaptureID })
            ?? (rememberedEntries + entries).first(where: { $0.id == timelineCaptureID })
            ?? activeEntry
    }

    private var activeSnapshot: LayoutSnapshot? {
        if let entry = activeEntry {
            return LayoutSnapshot(
                id: entry.id,
                name: entry.readableScreenKey ?? manager.currentFingerprint.readableName,
                screenKey: entry.screenKey,
                readableScreenKey: entry.readableScreenKey,
                records: entry.records,
                createdAt: entry.capturedAt,
                updatedAt: entry.capturedAt,
                location: nil,
                isAutoSave: true,
                foregroundBundleID: manager.autoSaveStore?.foregroundApp(forScreenKey: entry.screenKey),
                commandExcludedBundleIDs: []
            )
        }
        return manager.autoLayoutSnapshot
    }

    var body: some View {
        GeometryReader { outerGeo in
            let isViewingEarlier = (manager.selectedAutoSaveEntryID != nil) &&
                                   (manager.selectedAutoSaveEntryID != manager.autoSaveStore?.entry(forScreenKey: activeScreenKey)?.id)

            VStack(alignment: .leading, spacing: 16) {
                // Return to latest banner if an earlier capture is selected
                if isViewingEarlier, let entry = activeEntry {
                    earlierCaptureBanner(entry: entry, activeScreenKey: activeScreenKey)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .clipped()
                        .fullVisualAnimations()
                }

                // 1. Auto Layout Card on top (takes natural height)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let currentKey = manager.currentFingerprint.key
                    let entry = activeEntry
                    AutoLayoutHeroCard(
                        capturedAt: entry?.capturedAt,
                        timelineCapturedAt: timelineEntry?.capturedAt,
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
                        captures: activeCaptures,
                        onRestoreCapture: { manager.restoreAutoLayout(entryID: $0) },
                        selectedCaptureID: manager.selectedAutoSaveEntryID,
                        onSelectCapture: { tappedID in
                            forceFullWindowsAnimated = false
                            selectCapture(tappedID, timelineID: tappedID)
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
                        let activePres = activeCapturePresentation
                        LayoutPreviewView(
                            snapshot: snap,
                            selectedRecordID: manager.selectedRecordID,
                            tint: themeColor.color(seed: 0),
                            enable3DHover: !isViewingEarlier,
                            animateWindowReveal: true,
                            isMainWindow: true,
                            isWindowArrangementPreview: true,
                            isMinimalVisualAnimations: minimalVisualAnimations,
                            triggeringRecordIDs: forceFullWindowsAnimated ? [] : (activePres?.triggeringRecordIDs ?? []),
                            triggeringBundleIDs: forceFullWindowsAnimated ? [] : Set(activePres?.activityApps.map(\.bundleID).filter { !$0.isEmpty } ?? []),
                            triggeringAppNames: forceFullWindowsAnimated ? [] : Set(activePres?.activityApps.compactMap(\.appName).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []),
                            captureIndicator: forceFullWindowsAnimated ? .history : activePres?.changeIndicator,
                            revealTrigger: returnToLatestTrigger
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
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isViewingEarlier)
            .fullVisualAnimations()
            .frame(width: outerGeo.size.width, height: outerGeo.size.height, alignment: .topLeading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isEarlierExpanded = true
            timelineCaptureID = activeEntry?.id
            hasInitializedTimelineCaptureID = true
        }
        .onChange(of: manager.selectedAutoSaveEntryID) { _, selectionID in
            let timelineID = selectionID ?? activeEntry?.id
            guard timelineSelectionTask != nil,
                  pendingTimelineCaptureID == timelineID else {
                timelineSelectionTask?.cancel()
                timelineSelectionTask = nil
                pendingTimelineCaptureID = nil
                timelineCaptureID = timelineID
                hasInitializedTimelineCaptureID = true
                return
            }
        }
        .onDisappear {
            timelineSelectionTask?.cancel()
            timelineSelectionTask = nil
            pendingTimelineCaptureID = nil
            hasInitializedTimelineCaptureID = false
        }
    }

    private func earlierCaptureBanner(entry: AutoSaveEntry, activeScreenKey: String) -> some View {
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
                var t = Transaction(animation: .spring(response: 0.5, dampingFraction: 0.85))
                t.disablesAnimations = false
                withTransaction(t) {
                    forceFullWindowsAnimated = true
                    returnToLatestTrigger = UUID()
                    let latestID = displayEntries.first?.id
                    if activeScreenKey == manager.currentFingerprint.key {
                        selectCapture(nil, timelineID: latestID)
                    } else {
                        selectCapture(latestID, timelineID: latestID)
                    }
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
            .coloredActionButtonEffect(
                tint: themeColor.color(seed: 0),
                shape: AnyShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            )
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
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var isOtherDisplaysExpanded: Bool = true
    @State private var symphonyHighlightRecordID: UUID? = nil
    @State private var isListHovered: Bool = false

    private var activeScreenKey: String {
        activeEntry?.screenKey ?? manager.currentFingerprint.key
    }

    private var isAnyTopmostSelected: Bool {
        if let foreground = manager.autoSaveStore?.foregroundApp(forScreenKey: activeScreenKey), !foreground.isEmpty {
            return true
        }
        return false
    }

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

    private var currentDisplayEntry: AutoSaveEntry? {
        rememberedDisplays.first(where: { $0.screenKey == manager.currentFingerprint.key })
            ?? manager.autoSaveStore?.entry(forScreenKey: manager.currentFingerprint.key)
            ?? currentEntry
    }

    private var otherDisplays: [AutoSaveEntry] {
        rememberedDisplays.filter { $0.screenKey != manager.currentFingerprint.key }
    }

    private var currentEntry: AutoSaveEntry? {
        manager.autoSaveStore?.entry(forScreenKey: manager.currentFingerprint.key)
            ?? entries.first
    }

    private var activeEntry: AutoSaveEntry? {
        if let id = manager.selectedAutoSaveEntryID,
           let found = (manager.autoSaveStore?.visibleEntries ?? (rememberedEntries + entries)).first(where: { $0.id == id }) {
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
                        Button {
                            if !otherDisplays.isEmpty {
                                var t = Transaction(animation: .spring(response: 0.5, dampingFraction: 0.85))
                                t.disablesAnimations = false
                                withTransaction(t) {
                                    isOtherDisplaysExpanded.toggle()
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("REMEMBERED DISPLAYS".localized(appLanguage))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)

                                if !otherDisplays.isEmpty {
                                    Text("\(otherDisplays.count)")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(themeColor.color(seed: 0).opacity(0.15))
                                        .foregroundStyle(.primary)
                                        .clipShape(Capsule())

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .rotationEffect(.degrees(isOtherDisplaysExpanded ? 90 : 0))
                                } else {
                                    Spacer()
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                    // Current display is always visible directly
                    if let currentDisplay = currentDisplayEntry {
                        let isSelected = (activeEntry?.screenKey == currentDisplay.screenKey)
                        AutoLayoutRememberedDisplayRow(
                            entry: currentDisplay,
                            isSelected: isSelected,
                            isLive: true,
                            themeColor: themeColor
                        )
                        .onTapGesture {
                            var t = Transaction(animation: .spring(response: 0.5, dampingFraction: 0.85))
                            t.disablesAnimations = false
                            withTransaction(t) {
                                manager.selectedAutoSaveEntryID = currentDisplay.id
                                manager.selectedRecordID = nil
                            }
                        }
                    } else if rememberedDisplays.isEmpty {
                        Text("No remembered displays".localized(appLanguage))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                    }

                    // Other displays dropdown
                    if isOtherDisplaysExpanded && !otherDisplays.isEmpty {
                        LazyVStack(spacing: 6) {
                            ForEach(otherDisplays) { displayEntry in
                                let isSelected = (activeEntry?.screenKey == displayEntry.screenKey)
                                AutoLayoutRememberedDisplayRow(
                                    entry: displayEntry,
                                    isSelected: isSelected,
                                    isLive: false,
                                    themeColor: themeColor
                                )
                                .onTapGesture {
                                    var t = Transaction(animation: .spring(response: 0.5, dampingFraction: 0.85))
                                    t.disablesAnimations = false
                                    withTransaction(t) {
                                        manager.selectedAutoSaveEntryID = displayEntry.id
                                        manager.selectedRecordID = nil
                                    }
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 1)
                }

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
                                    .foregroundStyle(.primary)
                                    .clipShape(Capsule())
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isOtherDisplaysExpanded {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isOtherDisplaysExpanded = false
                                }
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
                                    isSymphonyActive: symphonyHighlightRecordID == record.id,
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
                                        if isOtherDisplaysExpanded {
                                            isOtherDisplaysExpanded = false
                                        }
                                    }
                                }
                            }
                        }
                        .onHover { hovering in
                            isListHovered = hovering
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 16)
            .padding(.bottom, 10)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Remember")
        .fullVisualAnimations()
        .task(id: "\(activeScreenKey)|\(manager.autoSaveStore?.foregroundApp(forScreenKey: activeScreenKey) ?? "")|\(records.count)") {
            withAnimation(.easeOut(duration: 0.08)) {
                symphonyHighlightRecordID = nil
            }

            guard !isAnyTopmostSelected, !records.isEmpty else {
                withAnimation(.easeOut(duration: 0.08)) {
                    symphonyHighlightRecordID = nil
                }
                return
            }

            // Initial brief pause before the first cycle begins
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }

            while !Task.isCancelled {
                if isAnyTopmostSelected {
                    withAnimation(.easeOut(duration: 0.08)) {
                        symphonyHighlightRecordID = nil
                    }
                    break
                }

                if isListHovered {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    continue
                }

                let currentRecords = records
                guard !currentRecords.isEmpty else { break }

                for record in currentRecords {
                    if Task.isCancelled || isAnyTopmostSelected { break }

                    // If user is hovering over the list, pause until mouse leaves
                    while isListHovered && !Task.isCancelled && !isAnyTopmostSelected {
                        if symphonyHighlightRecordID != nil {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                symphonyHighlightRecordID = nil
                            }
                        }
                        try? await Task.sleep(nanoseconds: 150_000_000)
                    }
                    if Task.isCancelled || isAnyTopmostSelected { break }

                    // Note on: balanced smooth fade-in (120ms)
                    withAnimation(.easeInOut(duration: 0.12)) {
                        symphonyHighlightRecordID = record.id
                    }

                    // Dwell visible (60ms)
                    try? await Task.sleep(nanoseconds: 60_000_000)
                    if Task.isCancelled || isAnyTopmostSelected { break }

                    // Note off: balanced smooth fade-out (120ms)
                    withAnimation(.easeInOut(duration: 0.12)) {
                        if symphonyHighlightRecordID == record.id {
                            symphonyHighlightRecordID = nil
                        }
                    }

                    // Breathing gap before next row (25ms)
                    try? await Task.sleep(nanoseconds: 25_000_000)
                }

                withAnimation(.easeInOut(duration: 0.12)) {
                    symphonyHighlightRecordID = nil
                }

                if Task.isCancelled || isAnyTopmostSelected {
                    withAnimation(.easeOut(duration: 0.12)) {
                        symphonyHighlightRecordID = nil
                    }
                    break
                }

                // Calm rest between cycles (2.5 seconds)
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }
}

// MARK: - Remembered Display Row (for Auto Layout sidebar)

struct AutoLayoutRememberedDisplayRow: View {
    let entry: AutoSaveEntry
    let isSelected: Bool
    let isLive: Bool
    let themeColor: ThemeColor

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
                Text(displayName)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .lineLimit(1)

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
                isHighlighted: isSelected,
                badgeStatus: isLive ? .live : nil
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

// MARK: - Thumbnail Bring To Front Button (for Auto Layout sidebar thumbnail overlay)

struct ThumbnailBringToFrontButton: View {
    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @Environment(\.colorScheme) private var colorScheme
    let appLanguage: AppLanguage
    let isActive: Bool
    let action: () -> Void

    @State private var isButtonHovered = false

    private var activeAccent: Color { themeColor.color(seed: 0) }
    private var activeAccentText: Color {
        if themeColor.isGalaxy {
            return .black
        }
        return themeColor.onAccentColor(for: colorScheme)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive
                          ? activeAccent
                          : (isButtonHovered ? Color.black.opacity(0.70) : Color.black.opacity(0.48)))
                    .frame(width: 22, height: 22)
                    .overlay {
                        Circle()
                            .stroke(isActive ? Color.white.opacity(0.35) : Color.white.opacity(0.22), lineWidth: 0.75)
                    }
                    .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)

                Image(systemName: "square.3.layers.3d.top.filled")
                    .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? activeAccentText : Color.white)
            }
            .frame(width: 22, height: 22)
            .contentShape(Circle())
            .scaleEffect(isButtonHovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .mainWindowSymbolHoverRegion()
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isButtonHovered = hovering }
        }
        .help(isActive
              ? "Click to unset Bring to Front".localized(appLanguage)
              : "Bring to Front".localized(appLanguage))
    }
}

struct AutoLayoutSidebarWindowRow: View {
    @EnvironmentObject var manager: WindowManager
    let record: WindowRecord
    let isSelected: Bool
    var isSymphonyActive: Bool = false
    let themeColor: ThemeColor
    let appLanguage: AppLanguage

    @State private var isHovered = false

    var body: some View {
        let isFull = record.isFullScreenMode
        let baseTint = isFull ? Color.green : themeColor.color(seed: 0)
        let thumbTint = isSelected ? baseTint : (isHovered ? baseTint : baseTint.opacity(0.85))
        let appID = record.windowID.appBundleID
        let screenKey = record.screenKey
        let isForeground = manager.autoSaveStore?.foregroundApp(forScreenKey: screenKey) == appID

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

                    if isFull {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .mainWindowSymbolAnimation(.wiggle, capturesClicks: false)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                    }

                    if isForeground {
                        Image(systemName: "square.3.layers.3d.top.filled")
                            .mainWindowSymbolAnimation(.breathePlain, capturesClicks: false)
                            .font(.system(size: 9))
                            .foregroundStyle(themeColor.color(seed: 5))
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
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    Text("\(record.globalFrame.width.clampedInt) × \(record.globalFrame.height.clampedInt)")
                        .font(.system(size: 10).monospaced())
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            // Window Thumbnail with interactive Front Most button overlay
            ZStack {
                Group {
                    if isFull {
                        FullScreenPreviewIcon(tint: thumbTint)
                    } else {
                        WindowPreviewIcon(record: record, tint: thumbTint)
                    }
                }
                .frame(width: 52, height: 34)

                if isHovered || isForeground || isSymphonyActive {
                    ThumbnailBringToFrontButton(
                        appLanguage: appLanguage,
                        isActive: isForeground
                    ) {
                        manager.setAutoLayoutForegroundApp(screenKey: screenKey, bundleID: appID)
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: 52, height: 34)
            .shadow(color: isSelected ? baseTint.opacity(0.35) : (isHovered ? baseTint.opacity(0.20) : .clear), radius: 3)
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
