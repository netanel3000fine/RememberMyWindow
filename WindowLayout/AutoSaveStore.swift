import Foundation

/// Durable home for the live layout.
///
/// The live layout has been tracked in memory since auto-save was taken out of
/// `LayoutStore`: full-store rewrites during a drag caused excess disk activity,
/// and mixing transient state into the saved snapshots caused clutter and edge
/// cases. Nothing here goes back on either of those decisions.
///
/// - It writes its **own file**, so a window drag never touches `layouts.json`
///   and never appears in the saved-snapshot dictionary.
/// - It coalesces far more slowly than the AX tracker, and takes a **forced
///   flush** on terminate, sleep and log-out so the last state before a
///   shutdown is the one kept.
/// - It keeps a short **ring** for recent captures, plus one durable latest
///   capture for every display configuration, and refuses to record a capture
///   whose window count has collapsed, so closing everything before a meeting
///   cannot become the layout you restore to.
struct AutoSaveEntry: Codable, Identifiable {
    var id: UUID = UUID()
    let capturedAt: Date
    let screenKey: String
    let readableScreenKey: String?
    let records: [WindowRecord]

    var windowCount: Int { records.count }
    var previewRecords: [WindowRecord] { records.previewRecords }
    var previewWindowCount: Int { previewRecords.count }
}

/// One reusable window template for an app on a particular display setup.
/// Auto Layout restores this frame to every currently open window of the app;
/// it does not describe a saved document or an individual window identity.
struct AppWindowDefault: Codable, Identifiable {
    let bundleID: String
    let screenKey: String
    let readableScreenKey: String?
    let record: WindowRecord
    let updatedAt: Date

    var id: String { "\(screenKey)::\(bundleID)" }
}

struct AutoSaveFile: Codable {
    /// Newest first. This is the recent-capture history, up to
    /// `AutoSaveStore.ringCapacity` captures per screen configuration.
    var entries: [AutoSaveEntry] = []
    /// One latest capture per screen fingerprint. Unlike `entries`, this does
    /// not roll away just because another display configuration was used more
    /// recently.
    var displayEntries: [AutoSaveEntry] = []
    /// Last frame seen for each window, newest first, and it never expires.
    /// See `AutoSaveStore.lastKnown`.
    var lastKnown: [WindowRecord] = []
    /// Pinned frontmost app bundle ID per screen configuration.
    var foregroundAppByScreenKey: [String: String] = [:]
    /// One default window template per app and display configuration.
    var appWindowDefaults: [AppWindowDefault] = []

    init(entries: [AutoSaveEntry] = [],
         displayEntries: [AutoSaveEntry] = [],
         lastKnown: [WindowRecord] = [],
         foregroundAppByScreenKey: [String: String] = [:],
         appWindowDefaults: [AppWindowDefault] = []) {
        self.entries = entries
        self.displayEntries = displayEntries
        self.lastKnown = lastKnown
        self.foregroundAppByScreenKey = foregroundAppByScreenKey
        self.appWindowDefaults = appWindowDefaults
    }

    /// Written by hand rather than synthesised, because synthesised decoding
    /// requires every key and ignores property defaults. A file written before
    /// `lastKnown` existed would fail to decode, and this store refuses to
    /// overwrite a file it could not read, so the whole history would be
    /// stranded on disk and unreadable.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries = try c.decodeIfPresent([AutoSaveEntry].self, forKey: .entries) ?? []
        displayEntries = try c.decodeIfPresent([AutoSaveEntry].self, forKey: .displayEntries) ?? []
        lastKnown = try c.decodeIfPresent([WindowRecord].self, forKey: .lastKnown) ?? []
        foregroundAppByScreenKey = try c.decodeIfPresent([String: String].self, forKey: .foregroundAppByScreenKey) ?? [:]
        appWindowDefaults = try c.decodeIfPresent([AppWindowDefault].self, forKey: .appWindowDefaults) ?? []
    }
}

@MainActor
final class AutoSaveStore: ObservableObject {

    // MARK: - Policy

    /// Captures kept **per screen configuration**, not in total.
    ///
    /// Enough history to step back past a bad capture. Per configuration
    /// because a global ring loses the setup you are not currently using, and
    /// that is exactly when history matters. Measured 2026-09-07: a morning of
    /// work on one monitor pair filled all five slots with that pair, so
    /// switching back to laptop-plus-LG found nothing recent for it and
    /// restored the only capture left — 21 hours old, 14 windows, onto a desk
    /// that now had 30.
    ///
    /// `displayEntries` is what stopped that being nothing at all, and it is
    /// still the durable per-configuration index. But it holds one capture per
    /// configuration, so there was no recent alternative to step back to. This
    /// gives every configuration its own history rather than making them
    /// compete for the same five slots.
    static let ringCapacity = 5

    /// A backstop on the file size, not a policy.
    ///
    /// Five per configuration is the rule. This only stops an unusual number of
    /// remembered setups growing the file without limit. Eight configurations is
    /// already generous — laptop alone, laptop with each monitor, each pair,
    /// docked, clamshell — and at roughly 15 KB a capture it bounds the file
    /// near 600 KB.
    static let ringConfigurationAllowance = 8
    static let ringTotalCapacity = ringCapacity * ringConfigurationAllowance

    /// The live tracker settles in seconds because the UI follows it. Durability
    /// does not need that: nothing reads this file until the next launch, so the
    /// only thing a short interval buys is disk writes.
    static let coalescingInterval: TimeInterval = 90

    /// The per-window memory is bounded, and not arbitrarily: `WindowID`
    /// includes the window title, so with Screen Recording granted a window
    /// that changes document gets a new identity and the map grows with title
    /// churn rather than with the number of windows. Without it the key is
    /// effectively bundle id plus index and a real desk settles around fifty
    /// records. This is high enough that eviction only ever bites the churn
    /// case, at roughly 140KB in the file.
    static let lastKnownCapacity = 400

    /// A capture is rejected when the window count falls to this fraction of the
    /// last recorded one or below. Chosen rather than an absolute drop because
    /// losing 3 of 4 windows matters and losing 3 of 30 does not.
    static let collapseFraction = 0.5

    // MARK: - State

    /// The recent capture history, newest first, holding up to
    /// `ringCapacity` captures for each screen configuration.
    @Published private(set) var entries: [AutoSaveEntry] = []

    /// The newest capture for each display configuration, newest first.
    /// Unlike `entries`, this is the durable source for the Remembered Displays
    /// list and survives ordinary captures on another monitor setup.
    @Published private(set) var displayEntries: [AutoSaveEntry] = []

    /// Where each window was the last time it was seen, regardless of how long
    /// ago that was or whether the app is still running.
    ///
    /// The ring cannot answer "where was this app before it quit". Each entry
    /// describes the whole desk at one moment, and the first capture after an
    /// app quits correctly stops mentioning it — measured at 85 seconds. So the
    /// answer survives only as long as a ring slot, which is five captures and
    /// no particular amount of time. Quit an app before lunch and the ring has
    /// rolled past it by the time you come back.
    ///
    /// This is the other shape of the same data: one record per window instead
    /// of one record per moment. It is scoped by screen fingerprint, because a
    /// frame from another display setup is not an answer.
    @Published private(set) var lastKnown: [WindowRecord] = []
    /// Latest default frame and full-screen state for each app/display pair.
    @Published private(set) var appWindowDefaults: [AppWindowDefault] = []
    /// Pinned frontmost app bundle ID per screen configuration.
    @Published private(set) var foregroundAppByScreenKey: [String: String] = [:]
    /// Set when the file existed but could not be read. Writing is refused
    /// while true, for the same reason `WindowManager.persist()` refuses.
    @Published private(set) var isUnreadable = false

    /// The newest capture, which is the one still inside the coalescing interval
    /// whenever there is one.
    ///
    /// Reading only what had reached disk made a restore undo a deliberate move.
    /// Drag a window, press Restore within the interval, and the arrangement
    /// applied was the one from before the drag, because that was the newest
    /// entry on disk. The automatic paths never saw this: a display change
    /// flushes before it restores. Every restore the user asks for by hand did.
    var latest: AutoSaveEntry? { pending ?? entries.first }

    /// Every capture a caller can reach, newest first, deduplicating any consecutive identical captures per screen.
    var visibleEntries: [AutoSaveEntry] {
        let all = pending.map { [$0] + entries } ?? entries
        var result: [AutoSaveEntry] = []
        for entry in all {
            if let last = result.last(where: { $0.screenKey == entry.screenKey }),
               Self.recordsMatchGeometry(entry.records, last.records) {
                continue
            }
            result.append(entry)
        }
        return result
    }

    /// The unwritten capture replaces the stored capture for its display while
    /// it is pending, so the UI and a manual restore always see the same state.
    var visibleDisplayEntries: [AutoSaveEntry] {
        var result = displayEntries
        if let pending {
            result.removeAll { $0.screenKey == pending.screenKey }
            result.append(pending)
        }
        return result.sorted { $0.capturedAt > $1.capturedAt }
    }

    /// The latest remembered capture for one display configuration.
    func entry(forScreenKey screenKey: String) -> AutoSaveEntry? {
        visibleDisplayEntries.first { $0.screenKey == screenKey }
    }

    /// The captures that could actually be restored onto a given screen
    /// configuration, newest first.
    ///
    /// `WindowManager.snapshot(from:)` refuses any entry whose `screenKey` is
    /// not the live one, so a capture from another configuration is not a
    /// choice the user has — it is a row that does nothing when clicked. The
    /// UI used to show them all and mark them instead, which was tolerable
    /// while the ring held five captures in total and is not now that it holds
    /// five per configuration.
    func entries(forScreenKey screenKey: String) -> [AutoSaveEntry] {
        visibleEntries.filter { $0.screenKey == screenKey }
    }

    /// Preferred frontmost application bundle ID for a display setup when restored in Auto Layout mode.
    func foregroundApp(forScreenKey screenKey: String) -> String? {
        foregroundAppByScreenKey[screenKey]
    }

    func setForegroundApp(_ bundleID: String?, forScreenKey screenKey: String) {
        if let bundleID = bundleID {
            foregroundAppByScreenKey[screenKey] = bundleID
        } else {
            foregroundAppByScreenKey.removeValue(forKey: screenKey)
        }
        write()
    }

    /// Returns the saved frame template for one app on one display setup.
    func appWindowDefault(forBundleID bundleID: String, screenKey: String) -> WindowRecord? {
        appWindowDefaults.first {
            $0.bundleID == bundleID && $0.screenKey == screenKey
        }?.record ?? appWindowDefaults.first {
            $0.screenKey == screenKey && $0.record.windowID.appName == bundleID
        }?.record
    }

    /// Seeds missing app defaults from the first observed window of each app.
    /// The caller passes records in its known opening order; on the first
    /// capture that is the capture order, which is the safe fallback when the
    /// app was already open before tracking began.
    func seedAppWindowDefaults(from records: [WindowRecord],
                               screenKey: String,
                               readableScreenKey: String?) {
        var seenBundleIDs = Set<String>()
        var changed = false
        for record in records where seenBundleIDs.insert(record.windowID.appBundleID).inserted {
            changed = upsertAppWindowDefault(from: record,
                                             screenKey: screenKey,
                                             readableScreenKey: readableScreenKey,
                                             onlyIfMissing: true) || changed
        }
        guard changed else { return }
        appWindowDefaults.sort { $0.updatedAt > $1.updatedAt }
        appWindowDefaultsIsDirty = true
        flush()
    }

    /// Makes a closed window's last known frame the app's next default.
    func rememberClosedWindowAsDefault(_ record: WindowRecord,
                                       screenKey: String,
                                       readableScreenKey: String?) {
        guard upsertAppWindowDefault(from: record,
                                     screenKey: screenKey,
                                     readableScreenKey: readableScreenKey,
                                     onlyIfMissing: false) else { return }
        appWindowDefaults.sort { $0.updatedAt > $1.updatedAt }
        appWindowDefaultsIsDirty = true
        // A close is the event that chooses the next default, so persist it
        // immediately rather than leaving it behind the long capture interval.
        flush()
    }

    @discardableResult
    private func upsertAppWindowDefault(from source: WindowRecord,
                                        screenKey: String,
                                        readableScreenKey: String?,
                                        onlyIfMissing: Bool,
                                        now: Date = Date()) -> Bool {
        let bundleID = source.windowID.appBundleID
        let existingIndex = appWindowDefaults.firstIndex {
            $0.bundleID == bundleID && $0.screenKey == screenKey
        }
        if onlyIfMissing, existingIndex != nil { return false }

        // A default is a template, not an identity for the closed window.
        // Clearing its CG ID and title prevents a recycled system window ID or
        // an old document title from steering a future restore to the wrong
        // window. The first live window is used as the template target.
        let template = WindowRecord(
            id: source.id,
            windowID: WindowID(appBundleID: bundleID,
                               appName: source.windowID.appName ?? bundleID,
                               windowTitle: "",
                               appWindowIndex: 0),
            cgWindowID: nil,
            globalFrame: source.globalFrame,
            screenKey: screenKey,
            screenFrame: source.screenFrame,
            screenName: source.screenName,
            savedAt: now,
            zIndex: 0,
            isFullScreenMode: source.isFullScreenMode,
            isNativeFullScreen: source.isNativeFullScreen
        )

        if let existingIndex,
           Self.recordsMatchGeometry([appWindowDefaults[existingIndex].record], [template]),
           appWindowDefaults[existingIndex].record.isNativeFullScreen == template.isNativeFullScreen {
            return false
        }

        let value = AppWindowDefault(bundleID: bundleID,
                                     screenKey: screenKey,
                                     readableScreenKey: readableScreenKey,
                                     record: template,
                                     updatedAt: now)
        if let existingIndex {
            appWindowDefaults[existingIndex] = value
        } else {
            appWindowDefaults.append(value)
        }
        return true
    }

    private let fileURL: URL
    private var pending: AutoSaveEntry?
    private var lastWrite: Date?
    /// Guarantees the settled arrangement reaches disk. See `armTrailingFlush`.
    private var trailingTimer: Timer?
    /// Set when `lastKnown` has changed but not yet reached disk, so a flush
    /// with no pending capture still writes.
    private var lastKnownIsDirty = false
    /// Set when an older file was hydrated with per-display entries, or when a
    /// display entry is replaced during a flush.
    private var displayEntriesIsDirty = false
    private var appWindowDefaultsIsDirty = false
    private var log: (String) -> Void

    init(directory: URL, log: @escaping (String) -> Void = { _ in }) {
        self.fileURL = directory.appendingPathComponent("auto-layout.json")
        self.log = log
        load()
    }

    // MARK: - Recording

    /// Compares two sets of window records for layout equality (same count, app IDs,
    /// full-screen state, and matching frames within tolerance).
    /// Focus order/zIndex is intentionally ignored so active window switches do not create duplicate captures.
    private static func recordsMatchGeometry(_ lhs: [WindowRecord], _ rhs: [WindowRecord], tolerance: CGFloat = 2) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var unmatchedRHS = rhs
        for left in lhs {
            guard let matchIndex = unmatchedRHS.firstIndex(where: { right in
                left.windowID.appBundleID == right.windowID.appBundleID &&
                left.isFullScreenMode == right.isFullScreenMode &&
                left.isNativeFullScreen == right.isNativeFullScreen &&
                abs(left.globalFrame.origin.x - right.globalFrame.origin.x) <= tolerance &&
                abs(left.globalFrame.origin.y - right.globalFrame.origin.y) <= tolerance &&
                abs(left.globalFrame.width - right.globalFrame.width) <= tolerance &&
                abs(left.globalFrame.height - right.globalFrame.height) <= tolerance
            }) else {
                return false
            }
            unmatchedRHS.remove(at: matchIndex)
        }
        return true
    }

    /// Detailed diagnostic difference explainer when two snapshots have the same count but fail geometry matching.
    private static func explainGeometryDifference(_ lhs: [WindowRecord], _ rhs: [WindowRecord], tolerance: CGFloat = 2) -> String {
        guard lhs.count == rhs.count else {
            return "count mismatch (\(lhs.count) vs \(rhs.count))"
        }
        var unmatchedRHS = rhs
        var diffs: [String] = []
        for left in lhs {
            if let matchIndex = unmatchedRHS.firstIndex(where: { right in
                left.windowID.appBundleID == right.windowID.appBundleID &&
                left.isFullScreenMode == right.isFullScreenMode &&
                left.isNativeFullScreen == right.isNativeFullScreen &&
                abs(left.globalFrame.origin.x - right.globalFrame.origin.x) <= tolerance &&
                abs(left.globalFrame.origin.y - right.globalFrame.origin.y) <= tolerance &&
                abs(left.globalFrame.width - right.globalFrame.width) <= tolerance &&
                abs(left.globalFrame.height - right.globalFrame.height) <= tolerance
            }) {
                unmatchedRHS.remove(at: matchIndex)
            } else {
                let app = left.windowID.appName ?? left.windowID.appBundleID
                if let closest = unmatchedRHS.first(where: { $0.windowID.appBundleID == left.windowID.appBundleID }) {
                    let dx = left.globalFrame.origin.x - closest.globalFrame.origin.x
                    let dy = left.globalFrame.origin.y - closest.globalFrame.origin.y
                    let dw = left.globalFrame.width - closest.globalFrame.width
                    let dh = left.globalFrame.height - closest.globalFrame.height
                    var reasons: [String] = []
                    if abs(dx) > tolerance { reasons.append(String(format: "dx=%.1f", dx)) }
                    if abs(dy) > tolerance { reasons.append(String(format: "dy=%.1f", dy)) }
                    if abs(dw) > tolerance { reasons.append(String(format: "dw=%.1f", dw)) }
                    if abs(dh) > tolerance { reasons.append(String(format: "dh=%.1f", dh)) }
                    if left.isFullScreenMode != closest.isFullScreenMode {
                        reasons.append("isFullScreenMode (\(left.isFullScreenMode) vs \(closest.isFullScreenMode))")
                    }
                    if left.isNativeFullScreen != closest.isNativeFullScreen {
                        reasons.append("isNativeFullScreen (\(left.isNativeFullScreen) vs \(closest.isNativeFullScreen))")
                    }
                    diffs.append("\(app): [\(reasons.joined(separator: ", "))]")
                    unmatchedRHS.removeAll(where: { $0.id == closest.id })
                } else {
                    diffs.append("\(app): missing in other snapshot")
                }
            }
        }
        return diffs.isEmpty ? "no difference" : diffs.prefix(3).joined(separator: "; ")
    }

    /// Checks if `subset` is a strict subset of `superset` where every window in `subset`
    /// has identical geometry to its corresponding window in `superset`.
    /// When true, windows were closed/hidden but none of the remaining windows moved or resized.
    private static func isSubsetWithoutMovement(subset: [WindowRecord], superset: [WindowRecord], tolerance: CGFloat = 3) -> Bool {
        guard subset.count < superset.count, !subset.isEmpty else { return false }
        var unmatchedSuperset = superset
        for sub in subset {
            guard let matchIndex = unmatchedSuperset.firstIndex(where: { sup in
                sub.windowID.appBundleID == sup.windowID.appBundleID &&
                sub.isFullScreenMode == sup.isFullScreenMode &&
                sub.isNativeFullScreen == sup.isNativeFullScreen &&
                abs(sub.globalFrame.origin.x - sup.globalFrame.origin.x) <= tolerance &&
                abs(sub.globalFrame.origin.y - sup.globalFrame.origin.y) <= tolerance &&
                abs(sub.globalFrame.width - sup.globalFrame.width) <= tolerance &&
                abs(sub.globalFrame.height - sup.globalFrame.height) <= tolerance
            }) else {
                return false
            }
            unmatchedSuperset.remove(at: matchIndex)
        }
        return true
    }

    /// Offers a capture. Held in memory and written only when the coalescing
    /// interval has passed, unless `force` is set.
    func record(records: [WindowRecord],
                screenKey: String,
                readableScreenKey: String?,
                now: Date = Date(),
                force: Bool = false) {
        guard !records.isEmpty else {
            log("auto-save: ignoring an empty capture")
            return
        }

        // Updated even when the arrangement is about to be refused. A collapse
        // is a statement about the shape of the desk, not about whether the
        // windows still open are where the capture says they are.
        rememberLastKnown(records)

        // Existing captures for this screen configuration, newest first.
        let existingForScreen = entries.filter { $0.screenKey == screenKey }

        // 1. Check if the incoming layout is identical to the latest capture or pending capture
        if let p = pending, p.screenKey == screenKey, Self.recordsMatchGeometry(records, p.records) {
            log("auto-save: layout matches pending capture — skipping duplicate snapshot")
            return
        }
        if let latestCommitted = existingForScreen.first, Self.recordsMatchGeometry(records, latestCommitted.records) {
            log("auto-save: layout matches latest committed capture — skipping duplicate snapshot")
            pending = nil
            return
        }

        // Check if windows were closed without any remaining windows moving/resizing:
        // Test against pending first (if set for this screen), then against the committed latestEntry.
        let isSubsetOfPending = (pending?.screenKey == screenKey) && Self.isSubsetWithoutMovement(subset: records, superset: pending!.records)
        let isSubsetOfCommitted = existingForScreen.first.map { Self.isSubsetWithoutMovement(subset: records, superset: $0.records) } ?? false

        if isSubsetOfPending || isSubsetOfCommitted {
            log("auto-save: windows closed but remaining windows did not move — skipping capture to keep existing history intact")
            return
        }

        // 2. Check if the incoming layout matches a previous capture (e.g. Capture 1 in a 2-layout toggle, or older in ring)
        if let matchIndex = existingForScreen.indices.first(where: { idx in
            if pending != nil && pending?.screenKey == screenKey {
                return Self.recordsMatchGeometry(records, existingForScreen[idx].records)
            } else {
                return idx > 0 && Self.recordsMatchGeometry(records, existingForScreen[idx].records)
            }
        }) {
            let matchedEntry = existingForScreen[matchIndex]
            if let globalIndex = entries.firstIndex(where: { $0.id == matchedEntry.id }) {
                entries.remove(at: globalIndex)
                let updatedEntry = AutoSaveEntry(
                    id: matchedEntry.id,
                    capturedAt: now,
                    screenKey: screenKey,
                    readableScreenKey: readableScreenKey ?? matchedEntry.readableScreenKey,
                    records: records
                )
                entries.insert(updatedEntry, at: 0)

                // Update displayEntries for this screen
                displayEntries.removeAll { $0.screenKey == screenKey }
                displayEntries.insert(updatedEntry, at: 0)
                displayEntriesIsDirty = true

                // If pending was for this screen and had a distinct layout, preserve it as an older capture
                if let p = pending, p.screenKey == screenKey {
                    pending = nil
                    if !Self.recordsMatchGeometry(p.records, records) {
                        entries.insert(p, at: 1)
                    }
                }

                // Trim per configuration to maintain ring capacity
                var keptPerConfiguration: [String: Int] = [:]
                entries = entries.filter { candidate in
                    let kept = (keptPerConfiguration[candidate.screenKey] ?? 0) + 1
                    keptPerConfiguration[candidate.screenKey] = kept
                    return kept <= Self.ringCapacity
                }
                if entries.count > Self.ringTotalCapacity {
                    entries.removeSubrange(Self.ringTotalCapacity...)
                }

                consecutiveCollapseRefusals = 0
                log("auto-save: layout matches previous capture — rearranged layouts, promoted to latest")
                scheduleWrite(now: now, force: force)
                return
            }
        }

        // Diagnostic: If no match was found, explain why recent captures with the same count differed
        for (idx, candidate) in existingForScreen.prefix(3).enumerated() where candidate.windowCount == records.count {
            let diff = Self.explainGeometryDifference(records, candidate.records)
            log("auto-save diff vs [\(idx == 0 ? "latest" : "capture #\(idx)")]: \(diff)")
        }

        if let reason = collapseReason(newCount: records.count, screenKey: screenKey) {
            consecutiveCollapseRefusals += 1
            if consecutiveCollapseRefusals < Self.collapseRefusalLimit {
                log("auto-save: \(reason) [\(consecutiveCollapseRefusals)/\(Self.collapseRefusalLimit)]")
                scheduleWrite(now: now, force: false)
                return
            }
            log("auto-save: \(reason) — accepting it, refused \(consecutiveCollapseRefusals) times running")
        }
        consecutiveCollapseRefusals = 0

        // If an entry for this screen has the same window count and was captured
        // within a short settling window (10s), it was likely an unplaced launch position
        // or intermediate window move. Replace it with this settled layout rather than cluttering
        // history with two captures of the same window count back-to-back.
        if let p = pending, p.screenKey == screenKey, p.windowCount == records.count, now.timeIntervalSince(p.capturedAt) < 10.0 {
            log("auto-save: updating pending layout (\(String(format: "%.1f", now.timeIntervalSince(p.capturedAt)))s old, count \(records.count)) with settled layout")
            pending = AutoSaveEntry(id: p.id,
                                    capturedAt: now,
                                    screenKey: screenKey,
                                    readableScreenKey: readableScreenKey ?? p.readableScreenKey,
                                    records: records)
            scheduleWrite(now: now, force: force)
            return
        }

        if pending == nil,
           let latest = existingForScreen.first,
           latest.windowCount == records.count,
           now.timeIntervalSince(latest.capturedAt) < 10.0 {
            if let globalIndex = entries.firstIndex(where: { $0.id == latest.id }) {
                entries.remove(at: globalIndex)
                displayEntries.removeAll { $0.id == latest.id }
                log("auto-save: updating recently captured layout (\(String(format: "%.1f", now.timeIntervalSince(latest.capturedAt)))s old, count \(records.count)) with settled layout")
            }
        }

        pending = AutoSaveEntry(capturedAt: now,
                                screenKey: screenKey,
                                readableScreenKey: readableScreenKey,
                                records: records)
        scheduleWrite(now: now, force: force)
    }

    /// Writes now if the coalescing interval has run out, otherwise arms the
    /// trailing timer so it is written when it does.
    private func scheduleWrite(now: Date, force: Bool) {
        guard pending != nil || lastKnownIsDirty || displayEntriesIsDirty || appWindowDefaultsIsDirty else { return }
        if force || lastWrite == nil || now.timeIntervalSince(lastWrite!) >= Self.coalescingInterval {
            flush(now: now)
        } else {
            armTrailingFlush(from: now)
        }
    }

    /// Upserts a capture's records into the per-window memory.
    ///
    /// Keyed on `WindowID`, which is what the restore already matches against,
    /// so nothing new has to be invented to look a window up. Records carry
    /// their own `screenKey`, so the display setup is already part of each one
    /// and needs no separate structure.
    private func rememberLastKnown(_ records: [WindowRecord]) {
        var byID = Dictionary(lastKnown.map { ($0.windowID, $0) },
                              uniquingKeysWith: { _, newer in newer })
        var changed = false
        for record in records {
            if let existing = byID[record.windowID],
               existing.globalFrame == record.globalFrame,
               existing.screenKey == record.screenKey,
               existing.isFullScreenMode == record.isFullScreenMode,
               existing.isNativeFullScreen == record.isNativeFullScreen {
                continue
            }
            byID[record.windowID] = record
            changed = true
        }
        guard changed else { return }

        // Newest first, so the cap evicts the least recently seen window and
        // the file reads in a useful order.
        var merged = byID.values.sorted { $0.savedAt > $1.savedAt }
        if merged.count > Self.lastKnownCapacity {
            merged.removeSubrange(Self.lastKnownCapacity...)
        }
        lastKnown = merged
        lastKnownIsDirty = true
    }

    /// Writes the pending capture once the coalescing interval has run out.
    ///
    /// Throttling on the leading edge alone loses the arrangement the user
    /// actually settled on. Move six windows and stop: the first move writes,
    /// the rest coalesce, and then nothing more arrives to trigger the write
    /// that would record where they ended up. Observed holding a half-finished
    /// arrangement on disk for over three minutes while the settled one sat in
    /// memory, and it would have held it indefinitely.
    ///
    /// The fire time is derived from `lastWrite`, not from now, so re-arming on
    /// every capture keeps aiming at the same instant rather than pushing the
    /// write further out. That keeps the one-write-per-interval promise intact
    /// and still guarantees the last state lands within one interval.
    private func armTrailingFlush(from now: Date) {
        guard let lastWrite else { return }
        let due = lastWrite.addingTimeInterval(Self.coalescingInterval)
        trailingTimer?.invalidate()
        trailingTimer = Timer.scheduledTimer(withTimeInterval: max(due.timeIntervalSince(now), 0),
                                             repeats: false) { [weak self] _ in
            Task { @MainActor in self?.flush() }
        }
    }

    /// Writes whatever is pending. Called on terminate, sleep and log-out, so
    /// the state at shutdown is the state kept.
    func flush(now: Date = Date()) {
        trailingTimer?.invalidate()
        trailingTimer = nil
        guard pending != nil || lastKnownIsDirty || displayEntriesIsDirty || appWindowDefaultsIsDirty else { return }
        guard !isUnreadable else {
            log("auto-save: refusing to write over a file that could not be read")
            return
        }
        if let entry = pending {
            pending = nil
            // If this entry was an in-place update of an existing entry, update it in-place in entries
            if let existingIndex = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[existingIndex] = entry
            } else {
                let isDuplicateOfLatest = entries.first(where: { $0.screenKey == entry.screenKey }).map {
                    Self.recordsMatchGeometry(entry.records, $0.records)
                } ?? false

                if !isDuplicateOfLatest {
                    entries.insert(entry, at: 0)
                    // Trim per configuration. `entries` is newest-first, so counting
                    // forward per `screenKey` and dropping a configuration's sixth and
                    // later captures keeps the five newest of each, and leaves every
                    // other configuration's history alone.
                    var keptPerConfiguration: [String: Int] = [:]
                    entries = entries.filter { candidate in
                        let kept = (keptPerConfiguration[candidate.screenKey] ?? 0) + 1
                        keptPerConfiguration[candidate.screenKey] = kept
                        return kept <= Self.ringCapacity
                    }
                    if entries.count > Self.ringTotalCapacity {
                        entries.removeSubrange(Self.ringTotalCapacity...)
                    }
                }
            }
            displayEntries.removeAll { $0.screenKey == entry.screenKey }
            displayEntries.insert(entry, at: 0)
            displayEntriesIsDirty = true
        }
        lastKnownIsDirty = false
        displayEntriesIsDirty = false
        appWindowDefaultsIsDirty = false
        lastWrite = now
        write()
    }

    /// Nil when the capture is acceptable, otherwise why it was rejected.
    ///
    /// Compared against the newest capture **for the same screen configuration**.
    /// Comparing against whatever happened to be newest made the guard latch: a
    /// 25-window docked desk became the floor for a 10-window laptop desk, the
    /// laptop capture was refused, a refusal never becomes the new baseline, and
    /// nothing on the laptop could clear it. That case cannot self-heal, because
    /// a laptop desk is structurally smaller than a docked one.
    func collapseReason(newCount: Int, screenKey: String) -> String? {
        guard let last = visibleDisplayEntries.first(where: { $0.screenKey == screenKey }) else { return nil }
        guard last.windowCount > 0 else { return nil }
        let floor = Double(last.windowCount) * Self.collapseFraction
        guard Double(newCount) <= floor else { return nil }
        return "rejected a capture of \(newCount) window(s) against \(last.windowCount) recorded — a collapse, not an arrangement"
    }

    /// How many refusals in a row before the desk is taken at its word.
    ///
    /// The guard is for a moment — everything closed before a meeting — not for
    /// a state. If the smaller desk is still there several coalescing intervals
    /// later it is not a moment, it is what the user is working in, and refusing
    /// for ever would mean auto-save had quietly stopped recording.
    private static let collapseRefusalLimit = 3
    private var consecutiveCollapseRefusals = 0

    // MARK: - Disk

    private func write() {
        // Deduplicate consecutive identical entries per screen configuration before saving:
        var deduplicated: [AutoSaveEntry] = []
        for entry in entries {
            if let last = deduplicated.last(where: { $0.screenKey == entry.screenKey }),
               Self.recordsMatchGeometry(entry.records, last.records) {
                continue
            }
            deduplicated.append(entry)
        }
        entries = deduplicated

        do {
            let data = try JSONEncoder().encode(AutoSaveFile(entries: entries,
                                                             displayEntries: displayEntries,
                                                             lastKnown: lastKnown,
                                                             foregroundAppByScreenKey: foregroundAppByScreenKey,
                                                             appWindowDefaults: appWindowDefaults))
            try data.write(to: fileURL, options: .atomic)
            log("auto-save: wrote \(entries.first?.windowCount ?? 0) window(s), \(entries.count) in ring, \(displayEntries.count) display configuration(s), \(lastKnown.count) remembered, \(appWindowDefaults.count) app default(s)")
        } catch {
            log("auto-save: write failed — \(error.localizedDescription)")
        }
    }

    /// Picks the newest capture for each screen fingerprint while retaining the
    /// full entry, including its window frames.
    private static func latestEntryPerDisplay(_ entries: [AutoSaveEntry]) -> [AutoSaveEntry] {
        var latest: [String: AutoSaveEntry] = [:]
        for entry in entries {
            guard let existing = latest[entry.screenKey] else {
                latest[entry.screenKey] = entry
                continue
            }
            if entry.capturedAt > existing.capturedAt {
                latest[entry.screenKey] = entry
            }
        }
        return latest.values.sorted { $0.capturedAt > $1.capturedAt }
    }

    private func load() {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch CocoaError.fileReadNoSuchFile {
            return
        } catch {
            isUnreadable = true
            log("auto-save: \(fileURL.lastPathComponent) could not be read — \(error.localizedDescription)")
            return
        }
        do {
            let file = try JSONDecoder().decode(AutoSaveFile.self, from: data)
            // Filter out duplicate captures for the same screen configuration:
            var deduplicatedEntries: [AutoSaveEntry] = []
            for entry in file.entries {
                let hasDuplicate = deduplicatedEntries.contains { existing in
                    existing.screenKey == entry.screenKey && Self.recordsMatchGeometry(entry.records, existing.records)
                }
                if !hasDuplicate {
                    deduplicatedEntries.append(entry)
                }
            }
            entries = deduplicatedEntries
            lastKnown = file.lastKnown
            foregroundAppByScreenKey = file.foregroundAppByScreenKey
            appWindowDefaults = file.appWindowDefaults

            // Files written before per-display retention only have the recent
            // ring. Merge it with the new field, then recover configurations
            // that have already rolled out of the ring from the per-window
            // memory that was added for app relaunch restores.
            var hydrated = Self.latestEntryPerDisplay(file.displayEntries + file.entries)
            let hydratedKeys = Set(hydrated.map(\.screenKey))
            let recovered = Dictionary(grouping: file.lastKnown, by: { $0.screenKey })
                .filter { !hydratedKeys.contains($0.key) }
                .map { item in
                    let screenKey = item.key
                    let records = item.value
                    return AutoSaveEntry(
                        capturedAt: records.map(\.savedAt).max() ?? Date(),
                        screenKey: screenKey,
                        readableScreenKey: ScreenFingerprint.from(key: screenKey).readableName,
                        records: records.sorted { $0.savedAt > $1.savedAt }
                    )
                }
            hydrated.append(contentsOf: recovered)
            displayEntries = hydrated.sorted { $0.capturedAt > $1.capturedAt }
            displayEntriesIsDirty = Set(file.displayEntries.map(\.id)) != Set(displayEntries.map(\.id))

            // Older files have no app templates. Recover one from the first
            // captured window for each app/display pair so an upgrade keeps
            // restoring automatically instead of starting with an empty map.
            var migratedDefaults = 0
            for entry in displayEntries {
                var seenBundleIDs = Set<String>()
                for record in entry.records where seenBundleIDs.insert(record.windowID.appBundleID).inserted {
                    if upsertAppWindowDefault(from: record,
                                              screenKey: entry.screenKey,
                                              readableScreenKey: entry.readableScreenKey,
                                              onlyIfMissing: true,
                                              now: entry.capturedAt) {
                        migratedDefaults += 1
                    }
                }
            }
            appWindowDefaults.sort { $0.updatedAt > $1.updatedAt }
            appWindowDefaultsIsDirty = migratedDefaults > 0

            // The coalescing floor is a promise about writes to this file, and
            // the file outlives the process. Without this, a relaunch starts
            // with no memory of when it last wrote and flushes on its first
            // capture — measured at 80s after the previous write, under the 90s
            // floor. The file's own modification date is that memory.
            lastWrite = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            if migratedDefaults > 0 {
                log("auto-save: migrated \(migratedDefaults) app default(s) from earlier captures")
                flush()
            }
            log("auto-save: loaded \(entries.count) entr(ies), \(displayEntries.count) display configuration(s), \(lastKnown.count) remembered window(s), \(appWindowDefaults.count) app default(s)")
        } catch {
            isUnreadable = true
            log("auto-save: \(fileURL.lastPathComponent) could not be decoded — \(error.localizedDescription)")
        }
    }

    // MARK: - Testing seam

    /// Exposed so the coalescing and ring behaviour can be exercised without
    /// waiting 90 seconds or touching the real support directory.
    func _setLastWriteForTesting(_ date: Date?) { lastWrite = date }
    var _trailingFlushIsArmedForTesting: Bool { trailingTimer?.isValid == true }
    var _pendingForTesting: AutoSaveEntry? { pending }
}
