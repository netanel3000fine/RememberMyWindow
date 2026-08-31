import Foundation
import AppKit

extension CGRect {
    var area: CGFloat { width * height }
}

struct LocationInfo: Codable {
    let latitude: Double
    let longitude: Double
    let address: String?
}

enum LogLevel: String, Codable, CaseIterable {
    case necessary = "Necessary"
    case moderate = "Moderate"
    case verbose = "Verbose"
}

/// Which shortcut gesture triggers the quick restore.
enum QuickKeyTrigger: String, Codable, CaseIterable {
    case fnLongPress = "Fn Long-Press"
    case capsLockDoubleTap = "Double-Tap Caps Lock"
    case both = "Both (Fn or Caps Lock)"
}

/// Whether the quick key restore restores all windows or just the frontmost app.
enum QuickKeyRestoreMode: String, Codable, CaseIterable {
    case frontAppRestore = "Front App Restore"
    case fullRestore = "Full Restore"
}

// MARK: - Window Record

/// Stable identity for a window across sessions.
struct WindowID: Codable, Hashable {
    let appBundleID: String
    let appName: String?         // Localized app name
    let windowTitle: String      // Best-effort; empty when Screen Recording permission isn't granted
    let appWindowIndex: Int      // 0-based index among all windows of the same app (ensures uniqueness when title is empty)

    var displayName: String {
        let baseApp = appName ?? appBundleID
        let base = windowTitle.isEmpty ? baseApp : "\(baseApp) – \(windowTitle)"
        return appWindowIndex > 0 ? "\(base) [\(appWindowIndex + 1)]" : base
    }
}

/// A single saved window state.
struct WindowRecord: Codable, Identifiable {
    var id: UUID = UUID()
    let windowID: WindowID
    /// Frame in global screen coordinates (origin = bottom-left of primary screen).
    let globalFrame: CGRect
    /// Screen fingerprint the window was on when saved.
    let screenKey: String
    /// The frame of the screen this window was on (in global coordinates).
    let screenFrame: CGRect?
    let screenName: String?      // Name of the screen this window was on
    let savedAt: Date
    var zIndex: Int?             // 0 = front-most
    /// True when this window was captured via the offScreen fallback path —
    /// meaning the app had no visible windows on the current Space at capture time
    /// (e.g. it was arranged to fill a different Space with a window manager).
    var isFullScreenMode: Bool = false
    /// True when this window was in native macOS full-screen mode at capture time.
    var isNativeFullScreen: Bool = false

    /// Frame relative to the screen's own coordinate space.
    func frameRelativeTo(screen: NSScreen) -> CGRect {
        CGRect(
            x: globalFrame.origin.x - screen.frame.origin.x,
            y: globalFrame.origin.y - screen.frame.origin.y,
            width: globalFrame.width,
            height: globalFrame.height
        )
    }
}

// MARK: - Layout Snapshot

/// All window records for a particular screen configuration.
struct LayoutSnapshot: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    let screenKey: String
    let readableScreenKey: String? // Human-readable screen description
    var records: [WindowRecord]
    var createdAt: Date
    var updatedAt: Date
    var location: LocationInfo?
    var isAutoSave: Bool = false
    /// Bundle ID of the app that should be brought to the foreground after restore.
    /// Set via right-click → "Bring to Front" in the window list.
    var foregroundBundleID: String? = nil
    /// Set of bundle identifiers excluded from sending Command+Shift+R keystrokes.
    var commandExcludedBundleIDs: Set<String> = []

    /// A cleaned-up version of the name, removing resolutions and shortening common display names for UI display.
    var displayName: String {
        // Remove resolutions like (1440x932) or (2560×1440)
        let cleaned = name.replacingOccurrences(of: "\\s*\\(\\d+[x×]\\d+\\)", with: "", options: .regularExpression)
        
        // Split by " + " to handle multi-monitor setups
        let parts = cleaned.components(separatedBy: " + ")
        let translatedParts = parts.map { part -> String in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Normalize variation keys for the built-in screen
            var key = trimmed
            let lower = key.lowercased()
            if lower == "built-in" || lower == "built-in retina display" || key == "צג Retina מובנה" || key == "מובנה" {
                key = "Built-in"
            }
            
            return lz(key)
        }
        
        return translatedParts.joined(separator: " + ")
    }

    mutating func upsert(_ record: WindowRecord) {
        if let idx = records.firstIndex(where: { $0.windowID == record.windowID }) {
            records[idx] = record
        } else {
            records.append(record)
        }
        updatedAt = Date()
    }

    // Custom decode so older files don't fail decoding when key is missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        screenKey = try container.decode(String.self, forKey: .screenKey)
        readableScreenKey = try container.decodeIfPresent(String.self, forKey: .readableScreenKey)
        records = try container.decode([WindowRecord].self, forKey: .records)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        location = try container.decodeIfPresent(LocationInfo.self, forKey: .location)
        isAutoSave = try container.decodeIfPresent(Bool.self, forKey: .isAutoSave) ?? false
        foregroundBundleID = try container.decodeIfPresent(String.self, forKey: .foregroundBundleID)
        commandExcludedBundleIDs = try container.decodeIfPresent(Set<String>.self, forKey: .commandExcludedBundleIDs) ?? []
    }

    // Explicit initializer with default arguments
    init(id: UUID = UUID(), name: String, screenKey: String, readableScreenKey: String?, records: [WindowRecord], createdAt: Date, updatedAt: Date, location: LocationInfo?, isAutoSave: Bool = false, foregroundBundleID: String? = nil, commandExcludedBundleIDs: Set<String> = []) {
        self.id = id
        self.name = name
        self.screenKey = screenKey
        self.readableScreenKey = readableScreenKey
        self.records = records
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.location = location
        self.isAutoSave = isAutoSave
        self.foregroundBundleID = foregroundBundleID
        self.commandExcludedBundleIDs = commandExcludedBundleIDs
    }
}

// MARK: - Notification Sound Options

enum SystemSoundCategory: String, CaseIterable, Identifiable {
    case encore  = "Encore Tones"
    case melodic = "Melodic & Ambient"
    case meme    = "Meme & Fun"
    case classic = "Classic Alert Sounds"

    var id: String { rawValue }
}

/// Available macOS native notification alert sounds including longer Apple tones and meme sounds.
enum SystemSound: String, Codable, CaseIterable, Identifiable {
    // 1. Encore Tones (1.5s – 3.8s)
    case welcome   = "Welcome"
    case droplet   = "Droplet"
    case milestone = "Milestone"
    case cheers    = "Cheers"
    case passage   = "Passage"
    case portal    = "Portal"
    case handoff   = "Handoff"
    case rebound   = "Rebound"
    case slide     = "Slide"

    // 2. Melodic & Ambient (1.7s – 2.7s trimmed)
    case stargaze   = "Stargaze"
    case illuminate = "Illuminate"
    case crystals   = "Crystals"
    case cosmic     = "Cosmic"

    // 3. Meme & Fun (0.5s – 2.0s)
    case emotionalDamage = "EmotionalDamage"
    case faah            = "Faah"
    case vineBoom        = "VineBoom"
    case bruh            = "Bruh"
    case robloxOof       = "RobloxOof"
    case windowsError    = "WindowsError"
    case whatTheDogDoin  = "WhatTheDogDoin"
    case mario1Up        = "Mario1Up"
    case marioPowerUp    = "MarioPowerUp"
    case marioJump       = "MarioJump"
    case marioPipe       = "MarioPipe"
    case illuminati      = "Illuminati"
    case directedBy      = "DirectedBy"
    case huhCat          = "HuhCat"
    case wilhelm         = "Wilhelm"
    case tacoBell        = "TacoBell"
    case quack           = "Quack"
    case sheesh          = "Sheesh"
    case yeet            = "Yeet"
    case animeWow        = "AnimeWow"
    case tada            = "Tada"

    // 4. Classic Alerts (0.5s – 1.8s)
    case glass     = "Glass"
    case hero      = "Hero"
    case pop       = "Pop"
    case ping      = "Ping"
    case tink      = "Tink"
    case submarine = "Submarine"
    case funk      = "Funk"
    case morse     = "Morse"
    case purr      = "Purr"
    case frog      = "Frog"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .emotionalDamage: return "Emotional Damage"
        case .faah:            return "Faah"
        case .vineBoom:        return "Vine Boom"
        case .bruh:            return "Bruh"
        case .robloxOof:       return "OOF (Roblox)"
        case .windowsError:    return "Windows Error"
        case .whatTheDogDoin:  return "What The Dog Doin"
        case .mario1Up:        return "Mario 1-Up"
        case .marioPowerUp:    return "Mario Power-Up"
        case .marioJump:       return "Mario Jump"
        case .marioPipe:       return "Mario Pipe"
        case .illuminati:      return "Illuminati (X-Files)"
        case .directedBy:      return "Directed by (Curb)"
        case .huhCat:          return "Huh? (Cat)"
        case .wilhelm:         return "Wilhelm Scream"
        case .tacoBell:        return "Taco Bell Bong"
        case .quack:           return "Quack"
        case .sheesh:          return "Sheesh"
        case .yeet:            return "Yeet"
        case .animeWow:        return "Anime Wow"
        case .tada:            return "Ta-Da"
        default:               return rawValue
        }
    }

    var category: SystemSoundCategory {
        switch self {
        case .welcome, .droplet, .milestone, .cheers, .passage, .portal, .handoff, .rebound, .slide:
            return .encore
        case .stargaze, .illuminate, .crystals, .cosmic:
            return .melodic
        case .emotionalDamage, .faah, .vineBoom, .bruh, .robloxOof, .windowsError, .whatTheDogDoin, .mario1Up, .marioPowerUp, .marioJump, .marioPipe, .illuminati, .directedBy, .huhCat, .wilhelm, .tacoBell, .quack, .sheesh, .yeet, .animeWow, .tada:
            return .meme
        case .glass, .hero, .pop, .ping, .tink, .submarine, .funk, .morse, .purr, .frog:
            return .classic
        }
    }

    /// Resolves file URL for bundled trimmed sounds, ToneLibrary sounds, or classic alert sounds.
    var fileURL: URL? {
        // 1. Check if we bundled a trimmed version in App Resources
        if let bundleURL = Bundle.main.url(forResource: rawValue, withExtension: "m4a") ?? Bundle.main.url(forResource: rawValue, withExtension: "caf") {
            return bundleURL
        }

        let toneLib = "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources"
        switch category {
        case .encore:
            let path = "\(toneLib)/AlertTones/EncoreInfinitum/\(rawValue)-EncoreInfinitum.caf"
            if FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
        case .melodic:
            let path = "\(toneLib)/Ringtones/\(rawValue).m4r"
            if FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
        case .meme:
            break
        case .classic:
            let path = "/System/Library/Sounds/\(rawValue).aiff"
            if FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
        }
        return nil
    }

    func play() {
        if let url = fileURL, let sound = NSSound(contentsOf: url, byReference: true) {
            sound.play()
            return
        }
        NSSound(named: rawValue)?.play()
    }

    static func playSound(named soundName: String) {
        let resolvedName: String
        switch soundName {
        case "Complete", "complete": resolvedName = "Welcome"
        case "Chord", "chord": resolvedName = "Droplet"
        case "Circles", "circles": resolvedName = "Milestone"
        case "Chimes", "Silk", "Uplift", "Waves", "Twinkle", "Daybreak": resolvedName = "Stargaze"
        default: resolvedName = soundName
        }
        if let matched = SystemSound(rawValue: resolvedName) {
            matched.play()
            return
        }
        NSSound(named: resolvedName)?.play()
    }
}

// MARK: - Layout Store (top-level persisted object)

struct LayoutStore: Codable {
    /// key = LayoutSnapshot.id.uuidString
    var snapshots: [String: LayoutSnapshot] = [:]
    /// key = ScreenFingerprint.key, value = LayoutSnapshot.id.uuidString
    var defaultSnapshotIDs: [String: String] = [:]
    var autoSaveEnabled: Bool = true
    var autoRestoreEnabled: Bool = true
    var restoreAnimated: Bool = true
    /// Restores an app's layout automatically when it is launched.
    var autoRestoreOnAppOpen: Bool = true
    /// When true, full restore will automatically launch any missing apps saved in the session.
    var launchMissingAppsOnRestore: Bool = false
    /// Delay (in seconds) before auto-restoring a single app when it launches.
    var singleAppRestoreDelay: Double = 1.0
    /// Delay (in seconds) before sending active app command on single app restore.
    var singleAppCommandDelay: Double = 4.3
    /// Additional delay (in seconds) for web apps and PWAs on launch before sending Command+Shift+R.
    var webAppLaunchCommandDelay: Double = 3.0
    /// User-specified custom web app bundle IDs that should receive the web app launch delay.
    var customWebAppBundleIDs: Set<String> = []
    var logLevel: LogLevel = .moderate
    var saveLocationEnabled: Bool = false
    var refreshFrontmostOnFullRestore: Bool = false
    var refreshFrontmostOnSingleRestore: Bool = false
    var refreshFrontmostOnlyOnExternalDisplay: Bool = false
    /// When true, displays a floating badge overlay over the target window when Command+Shift+R is sent.
    var showCommandOverlayAnimation: Bool = true
    /// When true, falls back to the legacy 5-second poll instead of AX-observer event-driven tracking.
    var usePollingMode: Bool = false
    /// When true, places background apps in the menu bar dropdown into a submenu
    var groupOtherAppsInSubmenu: Bool = true
    /// When true, the selected quick key trigger (Fn Long-Press or Double-Tap Caps Lock) triggers a restore.
    var quickKeyRestoreEnabled: Bool = false
    /// Which key gesture triggers the quick restore.
    var quickKeyTrigger: QuickKeyTrigger = .fnLongPress
    /// Duration in seconds for Fn Long-Press (default 1.0 s).
    var quickKeyHoldDuration: Double = 1.0
    /// Whether the quick key restore triggers a front-app restore or a full restore.
    var quickKeyRestoreMode: QuickKeyRestoreMode = .frontAppRestore
    /// When true, sends standard macOS Notification Center banners in addition to (or instead of) Notch notifications.
    var showSystemNotification: Bool = true
    /// Send macOS notification on full layout restore.
    var systemNotifyOnFullRestore: Bool = false
    /// Send macOS notification on single app restore.
    var systemNotifyOnSingleRestore: Bool = false
    /// Send macOS notification on display connection / disconnection.
    var systemNotifyOnDisplayChange: Bool = true
    /// Send macOS notification on snapshot and app updates.
    var systemNotifyOnSnapshotUpdate: Bool = true
    /// Send macOS notification on desktop toggle.
    var systemNotifyOnDesktopToggle: Bool = false

    /// Global default notification sound
    var defaultNotificationSound: String = SystemSound.stargaze.rawValue

    /// Per-event sound for notch notifications
    var notchSoundOnFullRestore: Bool = true
    var notchSoundOnSingleRestore: Bool = true
    var notchSoundOnDisplayChange: Bool = false
    var notchSoundOnSnapshotUpdate: Bool = true
    var notchSoundOnDesktopToggle: Bool = true

    var notchSoundNameFullRestore: String = SystemSound.passage.rawValue
    var notchSoundNameSingleRestore: String = SystemSound.glass.rawValue
    var notchSoundNameDisplayChange: String = SystemSound.welcome.rawValue
    var notchSoundNameSnapshotUpdate: String = SystemSound.slide.rawValue
    var notchSoundNameDesktopToggle: String = SystemSound.submarine.rawValue

    /// Per-event sound for macOS system notifications
    var systemSoundOnFullRestore: Bool = false
    var systemSoundOnSingleRestore: Bool = false
    var systemSoundOnDisplayChange: Bool = true
    var systemSoundOnSnapshotUpdate: Bool = false
    var systemSoundOnDesktopToggle: Bool = false

    var systemSoundNameFullRestore: String = SystemSound.stargaze.rawValue
    var systemSoundNameSingleRestore: String = SystemSound.glass.rawValue
    var systemSoundNameDisplayChange: String = SystemSound.welcome.rawValue
    var systemSoundNameSnapshotUpdate: String = SystemSound.slide.rawValue
    var systemSoundNameDesktopToggle: String = SystemSound.cheers.rawValue

    /// Notch notification event filters
    var notchNotifyOnFullRestore: Bool = true
    var notchNotifyOnSingleRestore: Bool = true
    var notchNotifyOnDisplayChange: Bool = true
    var notchNotifyOnSnapshotUpdate: Bool = true
    var notchNotifyOnDesktopToggle: Bool = true

    /// When true, single app restore shows a quiet "Already in place" banner with no sound if the window was already in position.
    var quietSingleRestoreWhenInPlace: Bool = true


    // Custom decode so new Bool flags fall back to their defaults when the key
    // is absent in an older persisted JSON, instead of throwing and wiping the store.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        snapshots            = try c.decodeIfPresent([String: LayoutSnapshot].self, forKey: .snapshots)            ?? [:]
        defaultSnapshotIDs   = try c.decodeIfPresent([String: String].self,         forKey: .defaultSnapshotIDs)   ?? [:]
        autoSaveEnabled      = try c.decodeIfPresent(Bool.self, forKey: .autoSaveEnabled)      ?? true
        autoRestoreEnabled   = try c.decodeIfPresent(Bool.self, forKey: .autoRestoreEnabled)   ?? true
        restoreAnimated      = try c.decodeIfPresent(Bool.self, forKey: .restoreAnimated)      ?? true
        autoRestoreOnAppOpen = try c.decodeIfPresent(Bool.self, forKey: .autoRestoreOnAppOpen) ?? true
        launchMissingAppsOnRestore = try c.decodeIfPresent(Bool.self, forKey: .launchMissingAppsOnRestore) ?? false
        singleAppRestoreDelay = try c.decodeIfPresent(Double.self, forKey: .singleAppRestoreDelay) ?? 1.0
        singleAppCommandDelay = try c.decodeIfPresent(Double.self, forKey: .singleAppCommandDelay) ?? 4.3
        webAppLaunchCommandDelay = try c.decodeIfPresent(Double.self, forKey: .webAppLaunchCommandDelay) ?? 3.0
        customWebAppBundleIDs = try c.decodeIfPresent(Set<String>.self, forKey: .customWebAppBundleIDs) ?? []
        logLevel             = try c.decodeIfPresent(LogLevel.self, forKey: .logLevel)             ?? .moderate
        saveLocationEnabled  = try c.decodeIfPresent(Bool.self, forKey: .saveLocationEnabled)  ?? false
        refreshFrontmostOnFullRestore         = try c.decodeIfPresent(Bool.self, forKey: .refreshFrontmostOnFullRestore)         ?? false
        refreshFrontmostOnSingleRestore       = try c.decodeIfPresent(Bool.self, forKey: .refreshFrontmostOnSingleRestore)       ?? false
        refreshFrontmostOnlyOnExternalDisplay = try c.decodeIfPresent(Bool.self, forKey: .refreshFrontmostOnlyOnExternalDisplay) ?? false
        showCommandOverlayAnimation           = try c.decodeIfPresent(Bool.self, forKey: .showCommandOverlayAnimation)           ?? true
        usePollingMode                        = try c.decodeIfPresent(Bool.self, forKey: .usePollingMode)                        ?? false
        groupOtherAppsInSubmenu               = try c.decodeIfPresent(Bool.self, forKey: .groupOtherAppsInSubmenu)               ?? true
        quickKeyRestoreEnabled                = try c.decodeIfPresent(Bool.self,                   forKey: .quickKeyRestoreEnabled)   ?? false
        quickKeyTrigger                       = try c.decodeIfPresent(QuickKeyTrigger.self,        forKey: .quickKeyTrigger)          ?? .fnLongPress
        quickKeyHoldDuration                  = try c.decodeIfPresent(Double.self,                 forKey: .quickKeyHoldDuration)     ?? 1.0
        quickKeyRestoreMode                   = try c.decodeIfPresent(QuickKeyRestoreMode.self,    forKey: .quickKeyRestoreMode)      ?? .frontAppRestore
        showSystemNotification                = try c.decodeIfPresent(Bool.self,                   forKey: .showSystemNotification)   ?? true
        systemNotifyOnFullRestore             = try c.decodeIfPresent(Bool.self,                   forKey: .systemNotifyOnFullRestore) ?? false
        systemNotifyOnSingleRestore           = try c.decodeIfPresent(Bool.self,                   forKey: .systemNotifyOnSingleRestore) ?? false
        systemNotifyOnDisplayChange           = try c.decodeIfPresent(Bool.self,                   forKey: .systemNotifyOnDisplayChange) ?? true
        systemNotifyOnSnapshotUpdate          = try c.decodeIfPresent(Bool.self,                   forKey: .systemNotifyOnSnapshotUpdate) ?? true
        systemNotifyOnDesktopToggle           = try c.decodeIfPresent(Bool.self,                   forKey: .systemNotifyOnDesktopToggle) ?? false
        quietSingleRestoreWhenInPlace         = try c.decodeIfPresent(Bool.self,                   forKey: .quietSingleRestoreWhenInPlace) ?? true

        func migrateSound(_ name: String?, fallback: String = SystemSound.stargaze.rawValue) -> String {
            guard let name = name else { return fallback }
            switch name {
            case "Complete", "complete": return SystemSound.welcome.rawValue
            case "Chord", "chord": return SystemSound.droplet.rawValue
            case "Circles", "circles": return SystemSound.milestone.rawValue
            case "Chimes", "Silk", "Uplift", "Waves", "Twinkle", "Daybreak", "Reflection", "reflection": return SystemSound.stargaze.rawValue
            case "Sosumi", "sosumi", "Basso", "basso", "Bottle", "bottle", "Blow", "blow": return SystemSound.glass.rawValue
            default:
                if SystemSound(rawValue: name) != nil { return name }
                return fallback
            }
        }

        // Per-event sound flags (notch)
        defaultNotificationSound              = migrateSound(try c.decodeIfPresent(String.self, forKey: .defaultNotificationSound), fallback: SystemSound.stargaze.rawValue)
        notchSoundOnFullRestore               = try c.decodeIfPresent(Bool.self,                   forKey: .notchSoundOnFullRestore) ?? true
        notchSoundOnSingleRestore             = try c.decodeIfPresent(Bool.self,                   forKey: .notchSoundOnSingleRestore) ?? true
        notchSoundOnDisplayChange             = try c.decodeIfPresent(Bool.self,                   forKey: .notchSoundOnDisplayChange) ?? false
        notchSoundOnSnapshotUpdate            = try c.decodeIfPresent(Bool.self,                   forKey: .notchSoundOnSnapshotUpdate) ?? true
        notchSoundOnDesktopToggle             = try c.decodeIfPresent(Bool.self,                   forKey: .notchSoundOnDesktopToggle) ?? true
        notchSoundNameFullRestore             = migrateSound(try c.decodeIfPresent(String.self, forKey: .notchSoundNameFullRestore), fallback: SystemSound.passage.rawValue)
        notchSoundNameSingleRestore           = migrateSound(try c.decodeIfPresent(String.self, forKey: .notchSoundNameSingleRestore), fallback: SystemSound.glass.rawValue)
        notchSoundNameDisplayChange           = migrateSound(try c.decodeIfPresent(String.self, forKey: .notchSoundNameDisplayChange), fallback: SystemSound.welcome.rawValue)
        notchSoundNameSnapshotUpdate          = migrateSound(try c.decodeIfPresent(String.self, forKey: .notchSoundNameSnapshotUpdate), fallback: SystemSound.slide.rawValue)
        notchSoundNameDesktopToggle           = migrateSound(try c.decodeIfPresent(String.self, forKey: .notchSoundNameDesktopToggle), fallback: SystemSound.submarine.rawValue)
        // Per-event sound flags (system)
        systemSoundOnFullRestore              = try c.decodeIfPresent(Bool.self,                   forKey: .systemSoundOnFullRestore) ?? false
        systemSoundOnSingleRestore            = try c.decodeIfPresent(Bool.self,                   forKey: .systemSoundOnSingleRestore) ?? false
        systemSoundOnDisplayChange            = try c.decodeIfPresent(Bool.self,                   forKey: .systemSoundOnDisplayChange) ?? true
        systemSoundOnSnapshotUpdate           = try c.decodeIfPresent(Bool.self,                   forKey: .systemSoundOnSnapshotUpdate) ?? false
        systemSoundOnDesktopToggle            = try c.decodeIfPresent(Bool.self,                   forKey: .systemSoundOnDesktopToggle) ?? false
        systemSoundNameFullRestore            = migrateSound(try c.decodeIfPresent(String.self, forKey: .systemSoundNameFullRestore), fallback: SystemSound.stargaze.rawValue)
        systemSoundNameSingleRestore          = migrateSound(try c.decodeIfPresent(String.self, forKey: .systemSoundNameSingleRestore), fallback: SystemSound.glass.rawValue)
        systemSoundNameDisplayChange          = migrateSound(try c.decodeIfPresent(String.self, forKey: .systemSoundNameDisplayChange), fallback: SystemSound.welcome.rawValue)
        systemSoundNameSnapshotUpdate         = migrateSound(try c.decodeIfPresent(String.self, forKey: .systemSoundNameSnapshotUpdate), fallback: SystemSound.slide.rawValue)
        systemSoundNameDesktopToggle          = migrateSound(try c.decodeIfPresent(String.self, forKey: .systemSoundNameDesktopToggle), fallback: SystemSound.cheers.rawValue)
        // Notch event filters
        notchNotifyOnFullRestore              = try c.decodeIfPresent(Bool.self,                   forKey: .notchNotifyOnFullRestore) ?? true
        notchNotifyOnSingleRestore            = try c.decodeIfPresent(Bool.self,                   forKey: .notchNotifyOnSingleRestore) ?? true
        notchNotifyOnDisplayChange            = try c.decodeIfPresent(Bool.self,                   forKey: .notchNotifyOnDisplayChange) ?? true
        notchNotifyOnSnapshotUpdate           = try c.decodeIfPresent(Bool.self,                   forKey: .notchNotifyOnSnapshotUpdate) ?? true
        notchNotifyOnDesktopToggle            = try c.decodeIfPresent(Bool.self,                   forKey: .notchNotifyOnDesktopToggle) ?? true
    }

    init() {}
}

