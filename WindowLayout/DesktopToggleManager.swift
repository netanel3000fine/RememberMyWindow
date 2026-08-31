import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class DesktopToggleManager: ObservableObject {
    static let shared = DesktopToggleManager()

    /// Whether the global desktop-toggle shortcut is active.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "enableDesktopToggleShortcut")
            if isEnabled { start() } else { stop() }
        }
    }

    /// Whether to automatically run window restoration when unhiding apps.
    @Published var restoreOnUnhide: Bool {
        didSet {
            UserDefaults.standard.set(restoreOnUnhide, forKey: "desktopToggleRestoreOnUnhide")
        }
    }

    /// Whether to focus the configured session frontmost app on unhide.
    @Published var focusConfiguredAppOnUnhide: Bool {
        didSet {
            UserDefaults.standard.set(focusConfiguredAppOnUnhide, forKey: "desktopToggleFocusConfiguredAppOnUnhide")
        }
    }

    /// The global shortcut that toggles the desktop. User-mappable; the binding
    /// is persisted and re-registered the moment it changes.
    @Published var hotkey: HotkeyConfig {
        didSet {
            guard hotkey != oldValue else { return }
            hotkey.save(HotkeyKeys.desktopToggle)
            if isEnabled { start() }
        }
    }

    /// True on the first launch after upgrading from a build where the shortcut
    /// was hardcoded. The binding is left exactly as it was; this only drives a
    /// one-time notice saying it is now the user's to change.
    @Published var needsShortcutMigrationNotice: Bool = false

    private let hotkeys = HotkeyManager()

    // Toggle state
    private var isDesktopHidden = false
    private var previouslyVisibleApps: Set<String> = []
    private var previousFrontmostAppBundleID: String?
    private var finderHadWindows = false

    private init() {
        UserDefaults.standard.register(defaults: [
            "enableDesktopToggleShortcut": true,
            "desktopToggleFocusConfiguredAppOnUnhide": true
        ])
        self.isEnabled = UserDefaults.standard.bool(forKey: "enableDesktopToggleShortcut")
        self.restoreOnUnhide = UserDefaults.standard.bool(forKey: "desktopToggleRestoreOnUnhide")
        self.focusConfiguredAppOnUnhide = UserDefaults.standard.bool(forKey: "desktopToggleFocusConfiguredAppOnUnhide")

        // Choosing the binding, in priority order:
        //
        //   1. the user has already chosen one, so use it;
        //   2. the app has run before, so this is an upgrade from the build
        //      where the shortcut was hardcoded to command+D. Seed exactly
        //      that, so the upgrade changes nothing, and raise a one-time
        //      notice explaining that it is now configurable;
        //   3. fresh install, so use the default. There is nothing to explain,
        //      so mark the notice as already seen.
        let defaults = UserDefaults.standard
        let stored = defaults.data(forKey: HotkeyKeys.desktopToggle)
        let hasRunBefore = defaults.bool(forKey: "hasCompletedOnboarding")

        if let stored, let cfg = try? JSONDecoder().decode(HotkeyConfig.self, from: stored) {
            self.hotkey = cfg
        } else if hasRunBefore {
            self.hotkey = .legacyDesktopToggle
            self.needsShortcutMigrationNotice = !defaults.bool(forKey: HotkeyKeys.acknowledgedShortcutChange)
        } else {
            self.hotkey = .defaultDesktopToggle
            defaults.set(true, forKey: HotkeyKeys.acknowledgedShortcutChange)
        }
        // Persist immediately so the binding is stable from here on, whichever
        // branch produced it.
        self.hotkey.save(HotkeyKeys.desktopToggle)

        if self.isEnabled { start() }
    }

    // MARK: - Hotkey lifecycle

    /// Dismiss the one-time upgrade notice. The binding is whatever the user
    /// left it as; accepting the notice is not itself a change.
    func acknowledgeShortcutChange() {
        UserDefaults.standard.set(true, forKey: HotkeyKeys.acknowledgedShortcutChange)
        needsShortcutMigrationNotice = false
    }

    func start() {
        guard isEnabled else { return }
        let registered = hotkeys.register(hotkey, slot: .desktopToggle) {
            DesktopToggleManager.shared.toggleDesktop()
        }
        if registered {
            WindowManager.shared.log(
                "Desktop toggle shortcut (\(HotkeyFormatter.glyphs(for: hotkey))) enabled",
                type: .system
            )
        } else {
            // The one thing here the user has to be told about: a shortcut that
            // silently failed to bind looks identical to a broken feature.
            WindowManager.shared.log(
                "Could not register the desktop toggle shortcut \(HotkeyFormatter.glyphs(for: hotkey)). Another application probably holds it. Choose a different one in Settings.",
                level: .necessary,
                type: .system
            )
        }
    }

    func stop() {
        hotkeys.unregister(slot: .desktopToggle)
    }

    /// Releases the binding while the settings recorder is capturing.
    ///
    /// A registered hotkey fires ahead of any NSEvent monitor, so without this
    /// step pressing the current shortcut in order to re-record it would toggle
    /// the desktop instead of being captured.
    func suspendForRecording() {
        hotkeys.unregister(slot: .desktopToggle)
    }

    func resumeAfterRecording() {
        if isEnabled { start() }
    }

    // MARK: - Toggle

    func toggleDesktop() {
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        WindowManager.shared.log(
            "\(HotkeyFormatter.glyphs(for: hotkey)) pressed. Focused: \(frontApp) (\(frontID))",
            level: .verbose
        )

        if isDesktopHidden {
            WindowManager.shared.log("Desktop toggle: showing desktop apps", type: .system)
            showDesktop()
        } else {
            if isCurrentSpaceFullScreen() {
                WindowManager.shared.log("Desktop toggle: escaping full-screen app", type: .system)
            } else {
                WindowManager.shared.log("Desktop toggle: hiding desktop apps", type: .system)
            }
            hideDesktop()
        }
    }

    // MARK: - Hide

    private func hideDesktop() {
        let workspace = NSWorkspace.shared
        
        // Avoid overwriting state if already hidden (e.g. rapid double-press)
        guard !isDesktopHidden else {
            WindowManager.shared.log("Desktop already hidden, ensuring space switch", level: .verbose)
            if isCurrentSpaceFullScreen() {
                if let finder = workspace.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
                    finder.activate()
                }
            }
            return
        }

        let frontmostApp = workspace.frontmostApplication
        previousFrontmostAppBundleID = frontmostApp?.bundleIdentifier

        // If already on a full-screen Space, we'll switch to the Desktop space
        // so the user actually sees it.
        if isCurrentSpaceFullScreen() {
            WindowManager.shared.log("Full-screen state detected — forcing space switch", type: .system)
            if let finder = workspace.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
                // 1. Standard activation
                finder.activate()
                
                // 2. AppleScript activation (more forceful)
                _ = executeAppleScript("tell application \"Finder\" to activate")
                
                // 3. System Events focus
                _ = executeAppleScript("tell application \"System Events\" to tell process \"Finder\" to set frontmost to true")
            }
        }

        // Hide all regular windowed apps.
        var visibleApps: Set<String> = []
        var hiddenNames: [String] = []
        for app in workspace.runningApplications {
            guard app.bundleIdentifier != "com.apple.finder" else { continue }
            
            if !app.isHidden && app.activationPolicy == .regular {
                if let bundleID = app.bundleIdentifier { 
                    visibleApps.insert(bundleID)
                    hiddenNames.append(app.localizedName ?? bundleID)
                }
                app.hide()
            }
        }
        previouslyVisibleApps = visibleApps
        WindowManager.shared.log("Apps hidden: \(hiddenNames.isEmpty ? "None" : hiddenNames.joined(separator: ", "))", level: .verbose)

        // Collapse any open Finder windows.
        let checkScript = "tell application \"Finder\" to return (count of windows) > 0"
        if let res = executeAppleScript(checkScript), res.booleanValue {
            finderHadWindows = true
            WindowManager.shared.log("Collapsing Finder windows", level: .verbose)
            _ = executeAppleScript("tell application \"Finder\" to set collapsed of windows to true")
        } else {
            finderHadWindows = false
        }

        isDesktopHidden = true
        WindowManager.shared.deliverNotification(type: .desktopToggle, title: "Desktop Clean", subtitle: "All windows hidden", isCompact: true)
    }

    // MARK: - Show

    private func showDesktop() {
        let workspace = NSWorkspace.shared
        var restoredNames: [String] = []

        // Unhide apps that were visible before.
        for app in workspace.runningApplications {
            guard app.bundleIdentifier != "com.apple.finder" else { continue }
            if let bundleID = app.bundleIdentifier, previouslyVisibleApps.contains(bundleID) {
                app.unhide()
                restoredNames.append(app.localizedName ?? bundleID)
            }
        }
        WindowManager.shared.log("Apps restored: \(restoredNames.isEmpty ? "None" : restoredNames.joined(separator: ", "))", level: .verbose)

        // Restore Finder windows.
        if finderHadWindows {
            WindowManager.shared.log("Restoring Finder windows", level: .verbose)
            _ = executeAppleScript("tell application \"Finder\" to set collapsed of windows to false")
        }

        // Restore the previously active app or the configured frontmost app.
        var targetBundleID = previousFrontmostAppBundleID
        
        if focusConfiguredAppOnUnhide {
            let fp = ScreenFingerprint.current()
            let store = WindowManager.shared.store
            let candidate: LayoutSnapshot?
            if let defaultID = store.defaultSnapshotIDs[fp.key],
               let snap = store.snapshots[defaultID], !snap.isAutoSave {
                candidate = snap
            } else {
                candidate = store.snapshots.values
                    .filter { $0.screenKey == fp.key && !$0.isAutoSave }
                    .sorted { $0.updatedAt > $1.updatedAt }
                    .first
            }
            if let configuredID = candidate?.foregroundBundleID {
                targetBundleID = configuredID
                WindowManager.shared.log("Desktop toggle unhide: Found configured session front app '\(configuredID)'", level: .verbose)
            }
        }
        
        if let bundleID = targetBundleID,
           let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            WindowManager.shared.log("Re-activating: \(app.localizedName ?? bundleID)", level: .verbose)
            app.activate()
        }

        isDesktopHidden = false
        previouslyVisibleApps.removeAll()
        previousFrontmostAppBundleID = nil
        
        // Auto-restore layout if enabled.
        if restoreOnUnhide {
            WindowManager.shared.log("Desktop toggle: triggering layout restore", type: .system)
            WindowManager.shared.restoreNow()
        } else {
            WindowManager.shared.deliverNotification(type: .desktopToggle, title: "Windows Restored", subtitle: "All windows unhidden", isCompact: true)
        }
    }

    // MARK: - AppleScript helper

    private func executeAppleScript(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            let result = script.executeAndReturnError(&error)
            if let err = error { print("AppleScript error: \(err)") }
            return result
        }
        return nil
    }

    // MARK: - Space detection

    /// Returns true when the current Space is a native full-screen Space,
    /// OR when the frontmost application is in full-screen mode.
    private func isCurrentSpaceFullScreen() -> Bool {
        // 1. Check if the frontmost app is in AX full-screen mode (most reliable)
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 0.15)
            var value: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
               let windows = value as? [AXUIElement] {
                for window in windows {
                    var isFullScreen: AnyObject?
                    if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &isFullScreen) == .success,
                       let fsNumber = isFullScreen as? NSNumber, fsNumber.boolValue {
                        WindowManager.shared.log("Full-screen detected via AX (Frontmost: \(frontApp.localizedName ?? frontApp.bundleIdentifier ?? "Unknown"))", level: .verbose)
                        return true
                    }
                }
            }
        }

        // 2. Fallback to CGSSpace private SPI (less reliable with multi-monitor)
        typealias CGSConnectionID = UInt32
        typealias CGSSpaceID      = UInt64

        guard
            let cgsBundleURL = Bundle(identifier: "com.apple.CoreGraphics")?.bundleURL
                ?? Bundle(path: "/System/Library/Frameworks/CoreGraphics.framework")?.bundleURL,
            let cgsHandle = dlopen(cgsBundleURL.appendingPathComponent("CoreGraphics").path, RTLD_NOLOAD | RTLD_LAZY)
        else { return false }
        defer { dlclose(cgsHandle) }

        typealias CGSMainConnectionFn = @convention(c) () -> CGSConnectionID
        typealias CGSGetActiveSpaceFn = @convention(c) (CGSConnectionID) -> CGSSpaceID
        typealias CGSSpaceGetTypeFn   = @convention(c) (CGSConnectionID, CGSSpaceID) -> Int32

        guard
            let mainConnSym  = dlsym(cgsHandle, "CGSMainConnectionID"),
            let activeSpSym  = dlsym(cgsHandle, "CGSGetActiveSpace"),
            let spaceTypeSym = dlsym(cgsHandle, "CGSSpaceGetType")
        else { return false }

        let getConn:       CGSMainConnectionFn = unsafeBitCast(mainConnSym,  to: CGSMainConnectionFn.self)
        let getActiveSpace: CGSGetActiveSpaceFn = unsafeBitCast(activeSpSym,  to: CGSGetActiveSpaceFn.self)
        let getSpaceType:   CGSSpaceGetTypeFn   = unsafeBitCast(spaceTypeSym, to: CGSSpaceGetTypeFn.self)

        let conn      = getConn()
        let spaceID   = getActiveSpace(conn)
        let spaceType = getSpaceType(conn, spaceID)
        
        let result = (spaceType == 1)
        if result {
            WindowManager.shared.log("Full-screen detected via CGSSpace (Type: \(spaceType))", level: .verbose)
        }
        return result
    }
}

extension HotkeyFormatter {
    /// The live desktop-toggle binding, for interface copy that names the
    /// shortcut. Interpolating it means the copy cannot disagree with what is
    /// actually bound, which is what nine hardcoded strings used to risk.
    @MainActor
    static var desktopToggleGlyphs: String {
        glyphs(for: DesktopToggleManager.shared.hotkey)
    }
}
