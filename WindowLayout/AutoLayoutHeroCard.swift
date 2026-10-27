import SwiftUI
import AppKit

fileprivate struct AutoLayoutRecordMatches {
    let olderIndexByCurrentIndex: [Int: Int]
    let unmatchedCurrentIndices: [Int]
}

/// CG window numbers identify a live window, not a permanent identity. Window
/// Server can replace or recycle one while an app moves between Spaces, so a
/// match must also stay within the same app and fall back to stable window
/// details before a changed number is treated as a launch.
fileprivate enum AutoLayoutRecordMatcher {
    private struct CGWindowKey: Hashable {
        let bundleID: String
        let windowID: CGWindowID
    }

    static func match(current: [WindowRecord], older: [WindowRecord]) -> AutoLayoutRecordMatches {
        var unmatchedCurrent = Set(current.indices)
        var unmatchedOlder = Set(older.indices)
        var olderIndexByCurrentIndex: [Int: Int] = [:]

        func pair(_ currentIndex: Int, with olderIndex: Int) {
            olderIndexByCurrentIndex[currentIndex] = olderIndex
            unmatchedCurrent.remove(currentIndex)
            unmatchedOlder.remove(olderIndex)
        }

        func bestOlderIndex(for currentIndex: Int,
                            matching predicate: (WindowRecord, WindowRecord) -> Bool) -> Int? {
            let currentRecord = current[currentIndex]
            let candidates = unmatchedOlder
                .filter { predicate(currentRecord, older[$0]) }
                .sorted()
            return candidates.min { lhs, rhs in
                let lhsDistance = geometryDistance(currentRecord, older[lhs])
                let rhsDistance = geometryDistance(currentRecord, older[rhs])
                return lhsDistance == rhsDistance ? lhs < rhs : lhsDistance < rhsDistance
            }
        }

        // Exact IDs are the strongest match, but only inside the owning app:
        // WindowServer may recycle an ID after an app's window disappears.
        var olderByCGWindowID: [CGWindowKey: [Int]] = [:]
        for olderIndex in older.indices {
            guard let windowID = older[olderIndex].cgWindowID else { continue }
            let key = CGWindowKey(bundleID: older[olderIndex].windowID.appBundleID,
                                  windowID: windowID)
            olderByCGWindowID[key, default: []].append(olderIndex)
        }
        for currentIndex in current.indices {
            guard let windowID = current[currentIndex].cgWindowID else { continue }
            let key = CGWindowKey(bundleID: current[currentIndex].windowID.appBundleID,
                                  windowID: windowID)
            guard let olderIndex = olderByCGWindowID[key]?.first(where: { unmatchedOlder.contains($0) }) else {
                continue
            }
            pair(currentIndex, with: olderIndex)
        }

        // Titles survive most Space transitions and disambiguate multiple
        // windows belonging to one app. Empty titles are common without Screen
        // Recording permission, so they are handled by the index/geometry passes.
        for currentIndex in current.indices where unmatchedCurrent.contains(currentIndex) {
            let currentRecord = current[currentIndex]
            guard !currentRecord.windowID.windowTitle.isEmpty,
                  let olderIndex = bestOlderIndex(for: currentIndex, matching: { currentRecord, olderRecord in
                      currentRecord.windowID.appBundleID == olderRecord.windowID.appBundleID
                          && currentRecord.windowID.windowTitle == olderRecord.windowID.windowTitle
                  }) else { continue }
            pair(currentIndex, with: olderIndex)
        }

        // App-local indices are the next-best identity when a CG ID changes.
        for currentIndex in current.indices where unmatchedCurrent.contains(currentIndex) {
            let currentRecord = current[currentIndex]
            guard let olderIndex = bestOlderIndex(for: currentIndex, matching: { currentRecord, olderRecord in
                currentRecord.windowID.appBundleID == olderRecord.windowID.appBundleID
                    && currentRecord.windowID.appWindowIndex == olderRecord.windowID.appWindowIndex
            }) else { continue }
            pair(currentIndex, with: olderIndex)
        }

        // If IDs and ordering both changed during a Space transition, preserve
        // continuity by pairing remaining records from the same app by nearest
        // geometry. Pair only as many as existed before; any surplus current
        // records are genuine count increases and remain marked as additions.
        let bundleIDs = Set(unmatchedCurrent.map { current[$0].windowID.appBundleID }).sorted()
        for bundleID in bundleIDs {
            var currentIndices = unmatchedCurrent
                .filter { current[$0].windowID.appBundleID == bundleID }
                .sorted()
            var olderIndices = unmatchedOlder
                .filter { older[$0].windowID.appBundleID == bundleID }
                .sorted()

            while !currentIndices.isEmpty && !olderIndices.isEmpty {
                var bestPair: (currentIndex: Int, olderIndex: Int, distance: CGFloat)?
                for currentIndex in currentIndices {
                    for olderIndex in olderIndices {
                        let distance = geometryDistance(current[currentIndex], older[olderIndex])
                        if bestPair == nil || distance < bestPair!.distance {
                            bestPair = (currentIndex, olderIndex, distance)
                        }
                    }
                }
                guard let bestPair else { break }
                pair(bestPair.currentIndex, with: bestPair.olderIndex)
                currentIndices.removeAll { $0 == bestPair.currentIndex }
                olderIndices.removeAll { $0 == bestPair.olderIndex }
            }
        }

        return AutoLayoutRecordMatches(
            olderIndexByCurrentIndex: olderIndexByCurrentIndex,
            unmatchedCurrentIndices: current.indices.filter { unmatchedCurrent.contains($0) }
        )
    }

    /// Returns true if an unmatched window was already present at the exact same coordinates
    /// in recent history, indicating it returned from another Space rather than being newly launched.
    static func isReturningUnchangedWindow(
        _ record: WindowRecord,
        recentHistory: [[WindowRecord]],
        tolerance: CGFloat = 2
    ) -> Bool {
        for pastRecords in recentHistory {
            for past in pastRecords {
                guard past.windowID.appBundleID == record.windowID.appBundleID else { continue }
                let matchesID = (record.cgWindowID != nil && past.cgWindowID == record.cgWindowID)
                    || (!record.windowID.windowTitle.isEmpty && past.windowID.windowTitle == record.windowID.windowTitle)
                    || (past.windowID.appWindowIndex == record.windowID.appWindowIndex)
                guard matchesID else { continue }
                let sameFrame = abs(past.globalFrame.origin.x - record.globalFrame.origin.x) <= tolerance
                    && abs(past.globalFrame.origin.y - record.globalFrame.origin.y) <= tolerance
                    && abs(past.globalFrame.width - record.globalFrame.width) <= tolerance
                    && abs(past.globalFrame.height - record.globalFrame.height) <= tolerance
                let sameFS = past.isFullScreenMode == record.isFullScreenMode
                    && past.isNativeFullScreen == record.isNativeFullScreen
                if sameFrame && sameFS {
                    return true
                }
            }
        }
        return false
    }

    private static func geometryDistance(_ lhs: WindowRecord, _ rhs: WindowRecord) -> CGFloat {
        abs(lhs.globalFrame.origin.x - rhs.globalFrame.origin.x)
            + abs(lhs.globalFrame.origin.y - rhs.globalFrame.origin.y)
            + abs(lhs.globalFrame.width - rhs.globalFrame.width)
            + abs(lhs.globalFrame.height - rhs.globalFrame.height)
    }
}

enum AutoLayoutCaptureIndicator: Equatable {
    case sameWindowCount
    case addedWindows(Int)
    case history

    var color: Color {
        Color(nsColor: nsColor)
    }

    var nsColor: NSColor {
        switch self {
        case .sameWindowCount:
            return .systemBlue
        case .addedWindows:
            return .systemGreen
        case .history:
            return .systemOrange
        }
    }

    static func classify(
        current: [WindowRecord],
        comparedTo older: [WindowRecord]?,
        recentHistory: [[WindowRecord]] = []
    ) -> (indicator: AutoLayoutCaptureIndicator, activityApps: [AutoLayoutCaptureAppIcon]) {
        guard let older else {
            // Strictly reserved for the baseline/oldest item at the last place of the list for aesthetic looks
            return (.history, [])
        }
        let matches = AutoLayoutRecordMatcher.match(current: current, older: older)
        let genuinelyAddedIndices = matches.unmatchedCurrentIndices.filter { currentIndex in
            !AutoLayoutRecordMatcher.isReturningUnchangedWindow(current[currentIndex], recentHistory: recentHistory)
        }
        if !genuinelyAddedIndices.isEmpty {
            let added = AutoLayoutCaptureAppIcon.apps(in: current, at: genuinelyAddedIndices)
            return (.addedWindows(genuinelyAddedIndices.count), added)
        }
        // Check if any window moved, resized, or changed full-screen state.
        let moved = AutoLayoutCaptureAppIcon.movedApps(current: current,
                                                     older: older,
                                                     matches: matches)
        if !moved.isEmpty {
            return (.sameWindowCount, moved)
        }
        // No windows moved or added: windows were closed without movement or baseline capture.
        // Never classify as .sameWindowCount when no windows moved or were added.
        return (.history, [])
    }

    static func classify(windowCount: Int, comparedTo nextOlderWindowCount: Int?) -> Self {
        guard let nextOlderWindowCount else {
            return .history
        }
        if windowCount > nextOlderWindowCount {
            return .addedWindows(windowCount - nextOlderWindowCount)
        }
        return .sameWindowCount
    }

    /// Returns the exact UUIDs of windows that were added or whose frame/full-screen state changed.
    static func changedRecordIDs(
        current: [WindowRecord],
        comparedTo older: [WindowRecord]?,
        recentHistory: [[WindowRecord]] = []
    ) -> Set<UUID> {
        guard let older else { return [] }

        let matches = AutoLayoutRecordMatcher.match(current: current, older: older)
        var changedIDs = Set<UUID>()

        let genuinelyAddedIndices = matches.unmatchedCurrentIndices.filter { currentIndex in
            !AutoLayoutRecordMatcher.isReturningUnchangedWindow(current[currentIndex], recentHistory: recentHistory)
        }

        for currentIndex in genuinelyAddedIndices {
            changedIDs.insert(current[currentIndex].id)
        }
        for (currentIndex, olderIndex) in matches.olderIndexByCurrentIndex {
            if hasGeometryOrFullScreenChange(current[currentIndex], comparedTo: older[olderIndex]) {
                changedIDs.insert(current[currentIndex].id)
            }
        }

        return changedIDs
    }

    fileprivate static func hasGeometryOrFullScreenChange(_ record: WindowRecord,
                                                           comparedTo olderRecord: WindowRecord,
                                                           tolerance: CGFloat = 2) -> Bool {
        record.isFullScreenMode != olderRecord.isFullScreenMode
            || record.isNativeFullScreen != olderRecord.isNativeFullScreen
            || abs(record.globalFrame.origin.x - olderRecord.globalFrame.origin.x) > tolerance
            || abs(record.globalFrame.origin.y - olderRecord.globalFrame.origin.y) > tolerance
            || abs(record.globalFrame.width - olderRecord.globalFrame.width) > tolerance
            || abs(record.globalFrame.height - olderRecord.globalFrame.height) > tolerance
    }
}

/// The app icon and accessible app name associated with a capture change.
struct AutoLayoutCaptureAppIcon: Identifiable {
    let bundleID: String
    let appName: String?
    let image: NSImage

    var id: String { bundleID }

    var accessibilityName: String {
        guard let appName = appName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !appName.isEmpty else {
            return bundleID
        }
        return appName
    }

    /// Apps with matched windows whose geometry or full-screen state changed between captures.
    static func movedApps(
        older: [WindowRecord]?,
        current: [WindowRecord],
        tolerance: CGFloat = 2
    ) -> [AutoLayoutCaptureAppIcon] {
        guard let older else { return [] }
        let matches = AutoLayoutRecordMatcher.match(current: current, older: older)
        return movedApps(current: current, older: older, matches: matches, tolerance: tolerance)
    }

    fileprivate static func movedApps(current: [WindowRecord],
                                      older: [WindowRecord],
                                      matches: AutoLayoutRecordMatches,
                                      tolerance: CGFloat = 2) -> [AutoLayoutCaptureAppIcon] {
        var changedApps: [(bundleID: String, appName: String?)] = []
        for (currentIndex, olderIndex) in matches.olderIndexByCurrentIndex.sorted(by: { $0.key < $1.key }) {
            let record = current[currentIndex]
            guard AutoLayoutCaptureIndicator.hasGeometryOrFullScreenChange(
                record,
                comparedTo: older[olderIndex],
                tolerance: tolerance
            ) else { continue }
            let bundleID = record.windowID.appBundleID
            if !changedApps.contains(where: { $0.bundleID == bundleID }) {
                changedApps.append((bundleID, record.windowID.appName))
            }
        }
        return resolve(changedApps)
    }

    fileprivate static func apps(in records: [WindowRecord], at indices: [Int]) -> [AutoLayoutCaptureAppIcon] {
        var changedApps: [(bundleID: String, appName: String?)] = []
        for index in indices {
            let record = records[index]
            let bundleID = record.windowID.appBundleID
            if !changedApps.contains(where: { $0.bundleID == bundleID }) {
                changedApps.append((bundleID, record.windowID.appName))
            }
        }
        return resolve(changedApps)
    }

    private static func resolve(_ apps: [(bundleID: String, appName: String?)]) -> [AutoLayoutCaptureAppIcon] {
        apps.map { app in
            AutoLayoutCaptureAppIcon(
                bundleID: app.bundleID,
                appName: app.appName,
                image: AppIconColorCache.appIcon(for: app.bundleID, appName: app.appName)
                    ?? NSWorkspace.shared.icon(for: .application)
            )
        }
    }
}

/// Shared data and formatting for one capture row in the menu bar and main window.
struct AutoLayoutCapturePresentation: Identifiable {
    let entry: AutoSaveEntry
    let isLatest: Bool
    let matchesCurrentScreens: Bool
    let changeIndicator: AutoLayoutCaptureIndicator
    let activityApps: [AutoLayoutCaptureAppIcon]
    let triggeringRecordIDs: Set<UUID>

    var id: UUID { entry.id }

    /// Projects one display's newest-first entries into the rows both capture lists render.
    static func make(
        from entries: [AutoSaveEntry],
        displayScreenKey: String,
        currentScreenKey: String
    ) -> [AutoLayoutCapturePresentation] {
        let displayEntries = entries.filter { $0.screenKey == displayScreenKey }

        return displayEntries.enumerated().map { index, entry in
            let remainingEntries = displayEntries.dropFirst(index + 1)
            let nextOlder = remainingEntries.first
            let recentHistory = remainingEntries.prefix(5).map(\.records)
            let (indicator, activityApps) = AutoLayoutCaptureIndicator.classify(
                current: entry.records,
                comparedTo: nextOlder?.records,
                recentHistory: Array(recentHistory)
            )
            let triggeringRecordIDs = AutoLayoutCaptureIndicator.changedRecordIDs(
                current: entry.records,
                comparedTo: nextOlder?.records,
                recentHistory: Array(recentHistory)
            )

            return AutoLayoutCapturePresentation(
                entry: entry,
                isLatest: index == 0,
                matchesCurrentScreens: entry.screenKey == currentScreenKey,
                changeIndicator: indicator,
                activityApps: activityApps,
                triggeringRecordIDs: triggeringRecordIDs
            )
        }
    }

    /// The shared, localized row label used by both interfaces.
    func title(at now: Date, language: AppLanguage) -> String {
        let age = ageLabel(at: now, language: language)
        let count = entry.windowCount

        if isLatest {
            let format = count == 1 ? "Latest (%@) · 1 window" : "Latest (%@) · %d windows"
            return count == 1
                ? String(format: format.localized(language), age)
                : String(format: format.localized(language), age, count)
        }

        let format = count == 1 ? "%@ · 1 window" : "%@ · %d windows"
        return count == 1
            ? String(format: format.localized(language), age)
            : String(format: format.localized(language), age, count)
    }

    /// The first text segment in the main-window timeline row.
    func ageTitle(at now: Date, language: AppLanguage) -> String {
        let age = ageLabel(at: now, language: language)
        guard isLatest else { return age }
        return String(format: "Latest (%@)".localized(language), age)
    }

    /// The trailing count label in the main-window timeline row.
    func windowCountTitle(language: AppLanguage) -> String {
        entry.windowCount == 1
            ? "1 window".localized(language)
            : "\(entry.windowCount) \("windows".localized(language))"
    }

    private func ageLabel(at now: Date, language: AppLanguage) -> String {
        let seconds = now.timeIntervalSince(entry.capturedAt)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = seconds < 3600
            ? [.minute]
            : (seconds <= AutoLayoutHeroCard.dayDisplayThreshold ? [.hour] : [.day])

        if seconds < 60 {
            if isLatest {
                return "just now".localized(language)
            }
            let oneMinute = formatter.string(from: 60) ?? "1 minute"
            return String(format: "%@ ago".localized(language), oneMinute)
        }

        let spelled = formatter.string(from: seconds) ?? ""
        guard !spelled.isEmpty else {
            let fallbackMinute = formatter.string(from: 60) ?? "1 minute"
            return isLatest
                ? "just now".localized(language)
                : String(format: "%@ ago".localized(language), fallbackMinute)
        }
        return String(format: "%@ ago".localized(language), spelled)
    }
}

/// The Auto layout's place in the sidebar.
///
/// A one-button restore of an arrangement nobody saved by hand has to show
/// what it is about to do, or there is no reason to trust it. So the card
/// leads with three facts: when the capture was taken, how many windows it
/// holds, and which display setup it came from.
///
/// Takes plain values rather than reaching into `WindowManager`, so it can be
/// rendered on its own and looked at.
struct AutoLayoutHeroCard: View {

    let capturedAt: Date?
    /// The main-window timeline age can trail the selected capture without
    /// delaying selection feedback or the preview. Other presentations use
    /// `capturedAt` directly.
    var timelineCapturedAt: Date? = nil
    let windowCount: Int
    let screenName: String?
    let matchesCurrentScreens: Bool
    let tint: Color
    let language: AppLanguage
    let onRestore: () -> Void
    /// The full display-scoped ring, newest first. The newest entry is also shown above.
    var captures: [AutoLayoutCapturePresentation] = []
    var onRestoreCapture: (UUID) -> Void = { _ in }
    var selectedCaptureID: UUID? = nil
    var onSelectCapture: ((UUID) -> Void)? = nil
    var isExpanded: Binding<Bool>? = nil
    @State private var internalExpanded: Bool = true
    @State private var isHeaderHovered: Bool = false
    /// Briefly true after a new capture arrives (not when viewing an earlier one).
    @State private var justUpdated: Bool = false
    @State private var updateFlashTask: Task<Void, Never>? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var expandedBinding: Binding<Bool> {
        isExpanded ?? $internalExpanded
    }

    /// How old a capture may be before the card stops looking confident.
    /// Restoring a days-old layout is worse than not restoring, so past this
    /// the card mutes rather than raising a warning nobody asked for.
    static let staleAfter: TimeInterval = 60 * 60 * 12

    /// Keep hour precision until a capture is more than two days old. A
    /// "1 day ago" label is too vague for the first 48 hours of the timeline.
    static let dayDisplayThreshold: TimeInterval = 48 * 60 * 60

    /// Injectable so the stale and fresh states can both be rendered.
    var now: Date = Date()

    private var age: TimeInterval? { capturedAt.map { now.timeIntervalSince($0) } }
    private var isStale: Bool { (age ?? .infinity) > Self.staleAfter }
    private var hasCapture: Bool { capturedAt != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 10)

            if let capturedAt {
                Text(relativeAge)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(isStale ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .accessibilityLabel(Text(String(format: "Captured %@".localized(language),
                                                    relativeAge)))
                    .padding(.bottom, 10)

                HStack(spacing: 6) {
                    Image(systemName: "macwindow")
                        .mainWindowSymbolAnimation(.wiggleByLayer)
                    Text(windowCount == 1 ? "1 window".localized(language) : "\(windowCount) \("windows".localized(language))")
                    if let screenName {
                        Text("·").foregroundStyle(.tertiary)
                        Text(screenName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .mainWindowSymbolHoverRegion()

                // A stale card mutes its heading and its age, so the button
                // must come down with them. Leaving the loudest element at full
                // strength undoes the point of muting the rest.
                restoreButton
                    .padding(.top, 10)

                // Only the display mismatch gets a line, because that is a
                // fact the card cannot show any other way. Age is carried by
                // the muting alone: a stale card is meant to look stale, not to
                // argue with the user about it.
                if !matchesCurrentScreens {
                    footnote("Captured on a different display setup.", systemImage: "display.trianglebadge.exclamationmark")
                        .padding(.top, 8)
                }

                if !captures.isEmpty {
                    recentCaptures
                        .padding(.top, 10)
                }
            } else {
                // No capture recorded yet — show a disabled placeholder button
                // so the layout stays consistent, then explain why.
                noCaptureButton
                    .padding(.top, 4)
                footnote("Nothing captured yet. Move a window and it will appear here.", systemImage: "macwindow.badge.plus")
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: capturedAt) { _, newDate in
            // Only flash when the user is looking at the live/latest state,
            // not when they are browsing an earlier capture.
            guard newDate != nil, !isViewingEarlierCapture else { return }
            updateFlashTask?.cancel()
            withAnimation(.easeInOut(duration: 0.25)) { justUpdated = true }
            updateFlashTask = Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.4)) { justUpdated = false }
            }
        }
    }

    /// Whether the selected row is older than the newest capture for this display.
    private var isViewingEarlierCapture: Bool {
        guard let selectedCaptureID else { return false }
        return selectedCaptureID != captures.first(where: \.isLatest)?.id
    }

    @ViewBuilder
    private var restoreButton: some View {
        // Label varies by state:
        //   • No capture at all        → disabled, "No Capture Yet"
        //   • Latest capture, no focus → passive,  "Layout Saved" (clock)
        //   • Earlier capture focused  → active,   "Restore" (back-arrow)
        //
        // The card heading (AUTO LAYOUT TIMELINE) already distinguishes this
        // button from the toolbar's Restore. Accessibility labels spell it out
        // explicitly so VoiceOver users hear the difference.
        if #available(macOS 26.0, *) {
            restoreButtonContent
                .glassEffect(
                    .regular.tint(tint.opacity(isStale ? 0.26 : 0.42)).interactive(),
                    in: .rect(cornerRadius: 18)
                )
        } else {
            restoreButtonContent
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(tint.opacity(isStale ? 0.24 : 0.35), lineWidth: 1)
                }
        }
    }

    /// The inner content of the restore button, split by interaction mode.
    ///
    /// - **Active** (`isViewingEarlierCapture`): a real tappable `Button` that
    ///   restores the focused earlier capture. Label: "Restore".
    /// - **Passive** (latest / no focus): a non-interactive label that flashes
    ///   "Layout updated ✓" for 2.5 s after every new capture, then rests as
    ///   "Layout Saved". Nothing happens on tap — the layout is already current.
    @ViewBuilder
    private var restoreButtonContent: some View {
        if isViewingEarlierCapture {
            // Active: tappable restore for the earlier capture in focus.
            Button(action: onRestore) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.uturn.backward")
                        .mainWindowSymbolAnimation(.flip, capturesClicks: false)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                    Text("Restore".localized(language))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .mainWindowSymbolHoverRegion()
            .disabled(!matchesCurrentScreens)
            .opacity(matchesCurrentScreens ? 1 : 0.42)
            .accessibilityLabel(Text("Restore the selected earlier capture".localized(language)))
        } else {
            // Passive: non-interactive status label. Flashes "Layout updated ✓"
            // briefly after a new capture, then returns to "Layout Saved".
            let icon  = justUpdated ? "checkmark.circle.fill" : "clock"
            let label = justUpdated
                ? "Layout updated".localized(language)
                : "Layout Saved".localized(language)
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .mainWindowSymbolAnimation(justUpdated ? .breathePlain : .wiggleByLayer,
                                              capturesClicks: false)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(justUpdated ? Color.green : tint)
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .opacity(matchesCurrentScreens ? 1 : 0.42)
            .accessibilityLabel(Text(label))
            .accessibilityAddTraits(.isStaticText)
        }
    }

    /// Disabled placeholder shown when no capture exists yet.
    private var noCaptureButton: some View {
        let content = HStack(spacing: 7) {
            Image(systemName: "clock.badge.questionmark")
                .mainWindowSymbolAnimation(.breathePlain, capturesClicks: false)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No Capture Yet".localized(language))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)

        return Group {
            if #available(macOS 26.0, *) {
                content
                    .glassEffect(
                        .regular.tint(Color.secondary.opacity(0.12)).interactive(),
                        in: .rect(cornerRadius: 18)
                    )
            } else {
                content
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.secondary.opacity(0.20), lineWidth: 1)
                    }
            }
        }
        .opacity(0.55)
        .accessibilityLabel(Text("No capture recorded yet".localized(language)))
        .accessibilityAddTraits(.isButton)
        .accessibilityRemoveTraits(.isSelected)
    }

    /// The same newest-first capture ring shown in the menu-bar list.
    private var recentCaptures: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    expandedBinding.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Recent Auto Captures".localized(language))
                        .font(.system(size: 12, weight: .semibold))

                    Text("\(captures.count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08), in: Capsule())

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expandedBinding.wrappedValue ? 90 : 0))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHeaderHovered = hovering
            }
            .background(
                RoundedRectangle(cornerRadius: expandedBinding.wrappedValue ? 10 : 12, style: .continuous)
                    .fill(isHeaderHovered ? Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04) : Color.clear)
            )

            if expandedBinding.wrappedValue {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(captures) { capture in
                        CaptureRow(
                            capture: capture,
                            isSelected: selectedCaptureID == capture.id,
                            title: capture.title(at: now, language: language),
                            now: now,
                            tint: tint,
                            language: language,
                            action: {
                                if let onSelect = onSelectCapture {
                                    onSelect(capture.id)
                                } else {
                                    onRestoreCapture(capture.id)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.10), lineWidth: 1)
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06),
            radius: 4,
            x: 0,
            y: 2
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: expandedBinding.wrappedValue)
    }

    /// A row that displays or restores one auto capture.
    private struct CaptureRow: View {
        let capture: AutoLayoutCapturePresentation
        var isSelected: Bool = false
        let title: String
        let now: Date
        let tint: Color
        let language: AppLanguage
        let action: () -> Void

        @State private var isHovering = false

        private var isApplicable: Bool { capture.matchesCurrentScreens }

        private var rowAccessibilityLabel: String {
            guard !capture.activityApps.isEmpty else { return title }
            let appNames = capture.activityApps.map(\.accessibilityName).joined(separator: ", ")
            let changedApps = String(format: "Apps changed: %@".localized(language), appNames)
            return "\(title). \(changedApps)"
        }

        var body: some View {
            Button(action: action) {
                HStack(spacing: 7) {
                    captureIndicator

                    Text(capture.ageTitle(at: now, language: language))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(isApplicable ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .layoutPriority(0)

                    Spacer(minLength: 8)

                    if !capture.activityApps.isEmpty {
                        appIcons
                    }

                    Text(capture.windowCountTitle(language: language))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .fixedSize()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? tint.opacity(0.16) : (tint.opacity(isHovering && isApplicable ? 0.12 : 0)))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(
                            isSelected ? tint.opacity(0.30) : tint.opacity(isHovering && isApplicable ? 0.20 : 0),
                            lineWidth: isSelected ? 1 : 0.75
                        )
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isApplicable)
            .mainWindowSymbolHoverRegion()
            .onHover { isHovering = $0 }
            .accessibilityElement(children: .ignore)
            .help(isApplicable
                  ? Text("Select and view this capture".localized(language))
                  : Text("Captured on a different display setup.".localized(language)))
            .accessibilityLabel(Text(rowAccessibilityLabel))
            .accessibilityValue(Text(isSelected ? "Selected".localized(language) : ""))
        }

        private var appIcons: some View {
            HStack(spacing: 4) {
                ForEach(Array(capture.activityApps.prefix(4))) { appIcon in
                    Image(nsImage: appIcon.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                }

                if capture.activityApps.count > 4 {
                    Text("+\(capture.activityApps.count - 4)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize()
            .opacity(isApplicable ? 1 : 0.45)
            .accessibilityHidden(true)
        }

        @ViewBuilder
        private var captureIndicator: some View {
            if !isApplicable {
                Image(systemName: "display.trianglebadge.exclamationmark")
                    .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)
            } else {
                switch capture.changeIndicator {
                case .sameWindowCount:
                    Image(systemName: "rectangle.and.arrow.up.right.and.arrow.down.left")
                        .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(capture.changeIndicator.color)
                        .frame(width: 20)
                case .addedWindows(let count):
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                        Text("+")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .baselineOffset(2)
                    }
                    .foregroundStyle(capture.changeIndicator.color)
                    .frame(minWidth: 20)
                case .history:
                    Image(systemName: "clock.arrow.circlepath")
                        .mainWindowSymbolAnimation(.wiggleByLayer, capturesClicks: false)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(capture.changeIndicator.color)
                        .frame(width: 20)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .mainWindowSymbolAnimation(.wiggleByLayer)
                .font(.system(size: 14, weight: .semibold))
            Text("AUTO LAYOUT TIMELINE".localized(language))
                .font(.system(size: 13, weight: .bold))
            Spacer()
            if hasCapture && !matchesCurrentScreens {
                Label {
                    Text("OTHER DISPLAYS".localized(language))
                } icon: {
                    Image(systemName: "display.trianglebadge.exclamationmark")
                        .mainWindowSymbolAnimation(.breathe)
                }
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(!hasCapture || isStale ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
        .mainWindowSymbolHoverRegion()
    }

    private func footnote(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text.localized(language))
        } icon: {
            Image(systemName: systemImage)
                .mainWindowSymbolAnimation(.breathePlain)
        }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .mainWindowSymbolHoverRegion()
    }

    /// Spelled out rather than using `Text(_:style:.relative)`, which cannot be
    /// given a reference date and so cannot be rendered for a chosen age.
    private var relativeAge: String {
        guard let date = timelineCapturedAt ?? capturedAt else { return "" }
        return age(of: date)
    }

    private func age(of date: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        let f = DateComponentsFormatter()
        f.unitsStyle = .full
        f.maximumUnitCount = 1
        f.allowedUnits = seconds < 3600
            ? [.minute]
            : (seconds <= Self.dayDisplayThreshold ? [.hour] : [.day])
        let spelled = f.string(from: max(seconds, 60)) ?? ""
        // The formatter localises the quantity; the suffix has to be localised
        // too, or a Hebrew system reads "5 דקות ago" in the largest text on the
        // card. A format string rather than concatenation, because the suffix
        // does not follow the quantity in every language.
        guard !spelled.isEmpty else { return "just now".localized(language) }
        return String(format: "%@ ago".localized(language), spelled)
    }
}
