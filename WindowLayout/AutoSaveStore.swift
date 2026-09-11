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

    init(entries: [AutoSaveEntry] = [],
         displayEntries: [AutoSaveEntry] = [],
         lastKnown: [WindowRecord] = []) {
        self.entries = entries
        self.displayEntries = displayEntries
        self.lastKnown = lastKnown
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

    /// Every capture a caller can reach, newest first.
    ///
    /// The unwritten one belongs at the front, so `first` is `latest` and any
    /// walk that skips the first entry skips the one already tried.
    var visibleEntries: [AutoSaveEntry] { pending.map { [$0] + entries } ?? entries }

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
    private var log: (String) -> Void

    init(directory: URL, log: @escaping (String) -> Void = { _ in }) {
        self.fileURL = directory.appendingPathComponent("auto-layout.json")
        self.log = log
        load()
    }

    // MARK: - Recording

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

        pending = AutoSaveEntry(capturedAt: now,
                                screenKey: screenKey,
                                readableScreenKey: readableScreenKey,
                                records: records)
        scheduleWrite(now: now, force: force)
    }

    /// Writes now if the coalescing interval has run out, otherwise arms the
    /// trailing timer so it is written when it does.
    private func scheduleWrite(now: Date, force: Bool) {
        guard pending != nil || lastKnownIsDirty else { return }
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
               existing.screenKey == record.screenKey {
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
        guard pending != nil || lastKnownIsDirty || displayEntriesIsDirty else { return }
        guard !isUnreadable else {
            log("auto-save: refusing to write over a file that could not be read")
            return
        }
        if let entry = pending {
            pending = nil
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
            displayEntries.removeAll { $0.screenKey == entry.screenKey }
            displayEntries.insert(entry, at: 0)
            displayEntriesIsDirty = true
        }
        lastKnownIsDirty = false
        displayEntriesIsDirty = false
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
        do {
            let data = try JSONEncoder().encode(AutoSaveFile(entries: entries,
                                                             displayEntries: displayEntries,
                                                             lastKnown: lastKnown))
            try data.write(to: fileURL, options: .atomic)
            log("auto-save: wrote \(entries.first?.windowCount ?? 0) window(s), \(entries.count) in ring, \(displayEntries.count) display configuration(s), \(lastKnown.count) remembered")
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
            entries = file.entries
            lastKnown = file.lastKnown

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

            // The coalescing floor is a promise about writes to this file, and
            // the file outlives the process. Without this, a relaunch starts
            // with no memory of when it last wrote and flushes on its first
            // capture — measured at 80s after the previous write, under the 90s
            // floor. The file's own modification date is that memory.
            lastWrite = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            log("auto-save: loaded \(entries.count) entr(ies), \(displayEntries.count) display configuration(s), \(lastKnown.count) remembered window(s)")
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
