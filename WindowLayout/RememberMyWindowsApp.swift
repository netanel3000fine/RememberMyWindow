// this file is the main entry point of the app
import SwiftUI
import AppKit
import CoreGraphics
import Combine
import IOKit.hid

@main
struct RememberMyWindowsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @AppStorage("themeColor") private var themeColor: ThemeColor = .default
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    init() {
        UserDefaults.standard.register(defaults: [
            "minimalVisualAnimations": true
        ])

        let langStr = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        if langStr == "en" {
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        } else if langStr == "he" {
            UserDefaults.standard.set(["he"], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
    }

    var body: some Scene {
        Window("RememberMyWindows", id: "main") {
            ContentView()
                .environmentObject(WindowManager.shared)
                .tint(themeColor.color(seed: 0))
                .environment(\.locale, currentLocale)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1150, height: 750)
        .handlesExternalEvents(matching: ["main"])

        Settings {
            SettingsView()
                .environmentObject(WindowManager.shared)
                .environment(\.locale, currentLocale)
        }
    }
}

// MARK: - Quick Key Restore Manager (Fn Long-Press & Double-Tap Caps Lock)

/// Monitors global modifier events for the user-configured quick restore trigger:
/// 1. `fn` Long-Press: Holds the Fn / Globe (🌐) key for `quickKeyHoldDuration` (default 1.0s).
/// 2. Double-Tap Caps Lock: Double-taps the Caps Lock (⇪) key within 0.65s.
@MainActor
final class QuickKeyRestoreManager {
    static let shared = QuickKeyRestoreManager()
    private(set) var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?

    // Fn hold tracking
    private var fnHoldWorkItem: DispatchWorkItem?
    private var isFnDown = false

    // Caps Lock double-tap tracking
    private var lastCapsLockTapTime: Date?
    private var capsLockResetTimer: Timer?

    private init() {}

    // MARK: Install / Remove

    func setup() {
        guard WindowManager.shared.store.quickKeyRestoreEnabled,
              !WindowManager.shared.store.autoSaveEnabled else { return }
        guard eventTap == nil else { return }

        guard AXIsProcessTrusted() else {
            retryTimer?.invalidate()
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    if WindowManager.shared.store.quickKeyRestoreEnabled,
                       !WindowManager.shared.store.autoSaveEnabled,
                       self?.eventTap == nil {
                        self?.setup()
                    }
                }
            }
            return
        }

        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { (_, type, event, _) -> Unmanaged<CGEvent>? in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = QuickKeyRestoreManager.shared.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return nil
                }

                let flags = event.flags
                let keycode = event.getIntegerValueField(.keyboardEventKeycode)

                DispatchQueue.main.async {
                    QuickKeyRestoreManager.shared.handleFlagsChanged(flags: flags, keycode: keycode)
                }
                return nil
            },
            userInfo: nil
        )

        if let tap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            WindowManager.shared.log("Quick Key Restore monitoring enabled", level: .moderate, type: .system)
        } else {
            retryTimer?.invalidate()
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    if WindowManager.shared.store.quickKeyRestoreEnabled,
                       !WindowManager.shared.store.autoSaveEnabled,
                       self?.eventTap == nil {
                        self?.setup()
                    }
                }
            }
        }
    }

    func teardown() {
        retryTimer?.invalidate()
        retryTimer = nil
        cancelFnHold()
        isFnDown = false
        lastCapsLockTapTime = nil
        capsLockResetTimer?.invalidate()
        capsLockResetTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        WindowManager.shared.log("Quick Key Restore monitoring disabled", level: .moderate, type: .system)
    }

    // MARK: Event Handling

    private func handleFlagsChanged(flags: CGEventFlags, keycode: Int64) {
        guard WindowManager.shared.store.quickKeyRestoreEnabled,
              !WindowManager.shared.store.autoSaveEnabled else { return }

        let trigger = WindowManager.shared.store.quickKeyTrigger

        // Process Fn hold if enabled for fnLongPress or both
        if trigger == .fnLongPress || trigger == .both {
            let fnPressed = flags.contains(.maskSecondaryFn)
            if fnPressed && !isFnDown {
                isFnDown = true
                startFnHold()
            } else if !fnPressed && isFnDown {
                isFnDown = false
                cancelFnHold()
            }
        }

        // Process Caps Lock double-tap if enabled for capsLockDoubleTap or both
        if trigger == .capsLockDoubleTap || trigger == .both {
            if keycode == 57 /* Caps Lock */ {
                handleCapsLockTap()
            }
        }
    }

    // MARK: Fn Hold

    private func startFnHold() {
        cancelFnHold()
        let duration = WindowManager.shared.store.quickKeyHoldDuration
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.isFnDown else { return }
            self.cancelFnHold()
            self.fireRestore(triggerSubtitle: "fn")
        }
        fnHoldWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func cancelFnHold() {
        fnHoldWorkItem?.cancel()
        fnHoldWorkItem = nil
    }

    // MARK: Caps Lock Double-Tap

    private func handleCapsLockTap() {
        let now = Date()
        if let last = lastCapsLockTapTime, now.timeIntervalSince(last) < 0.65 {
            // Double-tap succeeded!
            lastCapsLockTapTime = nil
            capsLockResetTimer?.invalidate()
            capsLockResetTimer = nil

            // Reset Caps Lock state to OFF
            resetCapsLockStateIfNeeded()
            fireRestore(triggerSubtitle: "⇪⇪")
        } else {
            // First tap: start timeout window
            lastCapsLockTapTime = now
            capsLockResetTimer?.invalidate()
            capsLockResetTimer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: false) { [weak self] _ in
                // scheduledTimer runs on the current run loop, which is the main
                // one here, so this already executes on the main actor. Saying so
                // keeps the double-tap window exact; hopping instead would let a
                // second tap land while the first is still being forgotten.
                MainActor.assumeIsolated { self?.lastCapsLockTapTime = nil }
            }
        }
    }

    private func resetCapsLockStateIfNeeded() {
        if NSEvent.modifierFlags.contains(.capsLock) {
            let src = CGEventSource(stateID: .hidSystemState)
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0x39, keyDown: true)
            let up = CGEvent(keyboardEventSource: src, virtualKey: 0x39, keyDown: false)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }

    // MARK: Restore Action

    private func fireRestore(triggerSubtitle: String? = nil) {
        guard !WindowManager.shared.isScreenLocked else { return }
        guard WindowManager.shared.store.quickKeyRestoreEnabled,
              !WindowManager.shared.store.autoSaveEnabled else { return }

        let mode = WindowManager.shared.store.quickKeyRestoreMode
        WindowManager.shared.log("🚀 Quick Key Restore fired! Mode: \(mode.rawValue)", level: LogLevel.necessary, type: EventType.restore)
        MenuBarIconManager.shared.triggerActionState(minDuration: 0.6)

        switch mode {
        case .fullRestore:
            WindowManager.shared.restoreNow(triggerSubtitle: triggerSubtitle)

        case .frontAppRestore:
            let frontApp = NSWorkspace.shared.frontmostApplication
            let frontAppID = frontApp?.bundleIdentifier
            let frontAppName = frontApp?.localizedName ?? (frontAppID ?? "App")
            let ourBundleID = Bundle.main.bundleIdentifier

            let targetAppID: String? = (frontAppID != nil && frontAppID != ourBundleID) ? frontAppID : nil

            guard let source = WindowManager.shared.automaticRestoreSnapshot(forAppLaunch: targetAppID) else {
                WindowManager.shared.showNotchNotificationPublic(
                    title: String(format: lz("%@ is not in this layout"), frontAppName),
                    subtitle: triggerSubtitle ?? "",
                    isCompact: true,
                    bundleID: targetAppID
                )
                DispatchQueue.main.async {
                    (NSApp.delegate as? AppDelegate)?.openMenuDropdown(forAppID: targetAppID)
                }
                return
            }

            if let targetID = targetAppID, source.snapshot.records.contains(where: { $0.windowID.appBundleID == targetID }) {
                WindowManager.shared.restore(
                    snapshot: source.snapshot,
                    specificAppBundleID: targetID,
                    showNotification: true,
                    // Geometry only from an Auto layout. It has no chosen foreground
                    // app and no exclusions, so nothing justifies sending
                    // Command+Shift+R into whatever happens to be focused.
                    skipCommandSend: source.isAuto,
                    triggerSubtitle: triggerSubtitle
                )
            } else {
                // Frontmost app is not in the active snapshot -> notify and open menu bar list
                WindowManager.shared.showNotchNotificationPublic(
                    title: String(format: lz("%@ is not in this layout"), frontAppName),
                    subtitle: triggerSubtitle ?? "",
                    isCompact: true,
                    bundleID: targetAppID
                )
                DispatchQueue.main.async {
                    (NSApp.delegate as? AppDelegate)?.openMenuDropdown(forAppID: targetAppID)
                }
            }
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum AutoSaveMenuLayout {
        static let sharedMenuWidth: CGFloat = 270
        static var rootWidth: CGFloat { sharedMenuWidth }
        static var previewWidth: CGFloat { sharedMenuWidth }
        static let windowListSubmenuWidth: CGFloat = 280
        static let leadingColumnWidth: CGFloat = 30
        static let submenuColumnWidth: CGFloat = 20
        static let keyEquivalentColumnWidth: CGFloat = 36
        static let trailingInset: CGFloat = 8
        static let captureTitleTrailingInset: CGFloat = 8
        // AppKit reserves the submenu arrow column; title truncation needs only this small inset.
        static var titleWidth: CGFloat {
            rootWidth - leadingColumnWidth - captureTitleTrailingInset
        }
        static let marqueeStartDelay: TimeInterval = 0.5
        static let marqueeInterval: TimeInterval = 0.16
    }

    private struct AutoSaveMenuMarqueeEntry {
        let item: NSMenuItem
        let fullTitle: String
        let initialTitle: String
    }

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var lastFrontmostAppID: String?
    private var autoSaveMenuIconVariants: [ObjectIdentifier: (normal: NSImage, highlighted: NSImage)] = [:]
    private var autoSaveMenuMarqueeEntries: [ObjectIdentifier: AutoSaveMenuMarqueeEntry] = [:]
    private weak var highlightedAutoSaveMenuItem: NSMenuItem?
    private weak var activeAutoSaveMenuMarqueeItem: NSMenuItem?
    private var autoSaveMenuMarqueeStartWorkItem: DispatchWorkItem?
    private var autoSaveMenuMarqueeTimer: Timer?
    private var autoSaveMenuMarqueeOffset = 0
    private var windowServerCursorCancellable: AnyCancellable?
    private var hasWindowServerCursorOverride = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce single instance: If another copy of RememberMyWindows is already running, activate it and terminate this new instance
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.netanel.remembermywindows")
        if runningApps.count > 1 {
            if let existingApp = runningApps.first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
                existingApp.activate()
                if let url = URL(string: "remembermywindows://main") {
                    NSWorkspace.shared.open(url)
                }
            }
            NSApp.terminate(nil)
            return
        }

        // Determine if launched by user (active) or by system login item (inactive)
        // For new users who haven't completed onboarding, always show the UI
        let isUserLaunch = NSApp.isActive
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let shouldShowUI = isUserLaunch || !hasCompletedOnboarding
        
        if shouldShowUI {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        setupStatusItem()
        setupWindowObservers()
        setupWindowServerCursorOverride()

        // Capture/show the SwiftUI window immediately so the UI is responsive
        DispatchQueue.main.async {
            if shouldShowUI {
                self.showMainWindow()
            } else {
                self.captureAndHideMainWindow()
            }
        }

        // Start background managers & tracking asynchronously
        _ = DesktopToggleManager.shared
        WindowManager.shared.startTracking()

        // Start Quick Key restore tap if enabled and compatible with the active mode.
        if WindowManager.shared.store.quickKeyRestoreEnabled,
           !WindowManager.shared.store.autoSaveEnabled {
            QuickKeyRestoreManager.shared.setup()
        }

        // Check GitHub once after launch (with a persisted 24-hour throttle),
        // then check again when the app becomes active later in the day.
        UpdateManager.shared.startAutomaticChecks()

        // Re-configure tap whenever the setting is toggled from Settings
        NotificationCenter.default.addObserver(
            forName: .quickKeyRestoreSettingChanged,
            object: nil,
            queue: .main
        ) { _ in
            // Delivered on .main by the queue: argument above, so this body runs
            // on the main thread already.
            MainActor.assumeIsolated {
                if WindowManager.shared.store.quickKeyRestoreEnabled,
                   !WindowManager.shared.store.autoSaveEnabled {
                    QuickKeyRestoreManager.shared.setup()
                } else {
                    QuickKeyRestoreManager.shared.teardown()
                }
            }
        }
    }

    private func setupWindowObservers() {
        // Automatically show/hide Dock icon based on window visibility
        let nc = NotificationCenter.default
        
        nc.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updateActivationPolicy()
            }
        }
        
        nc.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { [weak self] _ in
            // Wait a tiny bit to see if another window is becoming key
            DispatchQueue.main.async {
                Task { @MainActor in
                    self?.updateActivationPolicy()
                }
            }
        }

        nc.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] notification in
            guard let closingWindow = notification.object as? NSWindow else { return }

            let isClosingMainWindow = MainActor.assumeIsolated {
                self?.isMainWindow(closingWindow) ?? false
            }
            guard isClosingMainWindow else { return }

            // Wait until the main window finishes closing before dismissing
            // the separate SwiftUI Settings scene.
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    self?.closeSettingsWindow()
                }
            }
        }
    }

    private func updateActivationPolicy() {
        // Wait a tiny bit to ensure isVisible state is accurately updated by the system
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let hasVisibleWindows = NSApp.windows.contains { window in
                // Only count windows that are visible, not panels/status items, 
                // and belong to our app's main UI
                window.isVisible && !(window is NSPanel) && self.isAppWindow(window)
            }
            
            if hasVisibleWindows {
                if NSApp.activationPolicy() != .regular {
                    NSApp.setActivationPolicy(.regular)
                }
            } else {
                if NSApp.activationPolicy() != .accessory {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }

    private func isAppWindow(_ w: NSWindow) -> Bool {
        // Match the main window or any potential settings/secondary windows
        return w.title == "RememberMyWindows" || 
               w.identifier?.rawValue.contains("main") == true || 
               w.title == "Settings" ||
               w.identifier?.rawValue == "software-update"
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        endWindowServerCursorOverride()
        WindowManager.shared.stopTracking()
    }

    // MARK: - WindowServer launch feedback

    private func setupWindowServerCursorOverride() {
        windowServerCursorCancellable = WindowManager.shared.$isWindowServerInitializing
            .removeDuplicates()
            .sink { [weak self] isInitializing in
                Task { @MainActor [weak self] in
                    if isInitializing {
                        self?.beginWindowServerCursorOverride()
                    } else {
                        self?.endWindowServerCursorOverride()
                    }
                }
            }
    }

    /// Keeps the app's pointer familiar while its own startup scan is running.
    /// This is intentionally scoped and balanced; macOS may still show its
    /// beach-ball cursor if the process is genuinely unresponsive.
    private func beginWindowServerCursorOverride() {
        guard !hasWindowServerCursorOverride else { return }
        NSCursor.arrow.push()
        hasWindowServerCursorOverride = true
    }

    private func endWindowServerCursorOverride() {
        guard hasWindowServerCursorOverride else { return }
        NSCursor.pop()
        hasWindowServerCursorOverride = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Window management

    private func captureAndHideMainWindow() {
        if let window = NSApplication.shared.windows.first(where: { isMainWindow($0) }) {
            // Hide immediately so the window doesn't flash at launch
            window.orderOut(nil)
        }
    }

    private func isMainWindow(_ w: NSWindow) -> Bool {
        w.title == "RememberMyWindows" || w.identifier?.rawValue.contains("main") == true
    }

    private func closeSettingsWindow() {
        for window in NSApp.windows where isSettingsWindow(window) {
            window.performClose(nil)
        }
    }

    private func isSettingsWindow(_ w: NSWindow) -> Bool {
        w.title == "Settings" || w.identifier?.rawValue.localizedCaseInsensitiveContains("settings") == true
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            MenuBarIconManager.shared.bind(button: button)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    // MARK: - Status Item Click

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if WindowManager.shared.store.autoSaveEnabled {
            let frontmostAppID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            if let appID = frontmostAppID, appID != "com.netanel.remembermywindows" {
                self.lastFrontmostAppID = appID
            }
            openMenuDropdown(forAppID: lastFrontmostAppID)
            return
        }

        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp || (NSEvent.modifierFlags.contains(.control))

        if isRightClick {
            // Right-click: native menu bar highlight + white tint, then restore full layout
            animateRightClickStatusButton()
            MenuBarIconManager.shared.triggerActionState(minDuration: 0.6)
            // No layout was named, so the Auto layout wins when it is switched on.
            WindowManager.shared.restoreNow(automatic: true)
        } else {
            let restoreOnLeftClick = UserDefaults.standard.object(forKey: "restoreFocusedAppOnLeftClick") as? Bool ?? true
            let frontmostAppID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            if let appID = frontmostAppID, appID != "com.netanel.remembermywindows" {
                self.lastFrontmostAppID = appID
            }
            
            // A left click names an app, never a layout, so the Auto layout wins
            // when it is switched on. `automaticRestoreSnapshot` already refuses a
            // layout that holds no record for the app, which is the test that used
            // to sit on the line below.
            if restoreOnLeftClick,
               let appID = lastFrontmostAppID,
               let source = WindowManager.shared.automaticRestoreSnapshot(forAppLaunch: appID) {
                let snap = source.snapshot
                
                let hasCommandShortcut = snap.commandExcludedBundleIDs.contains(appID)
                
                // Signal the action here, not at the top of the branch. Above this
                // point the click may still resolve to "just open the menu", and the
                // icon must not announce a restore that is not going to happen.
                MenuBarIconManager.shared.triggerActionState(minDuration: 0.6)

                if hasCommandShortcut {
                    // When ⌘⇧R is enabled for this app:
                    // Maintain sequential restore to ensure ⌘⇧R lands on the app before menu steals focus.
                    WindowManager.shared.restore(
                        snapshot: snap,
                        animated: false,
                        specificAppBundleID: appID,
                        showNotification: true,
                        skipCommandSend: false,
                        completion: { [weak self] in
                            self?.openMenuDropdown(forAppID: appID)
                        }
                    )
                    return
                } else {
                    // When ⌘⇧R is toggled off:
                    // Reposition window in background and pop up menu instantaneously (0ms delay)!
                    WindowManager.shared.restore(
                        snapshot: snap,
                        animated: false,
                        specificAppBundleID: appID,
                        showNotification: true,
                        skipCommandSend: true
                    )
                    openMenuDropdown(forAppID: appID)
                    return
                }
            }
            
            // Default fallback: open menu list instantly if no saved record matches or left-click restore is off
            openMenuDropdown(forAppID: lastFrontmostAppID)
        }
    }

    /// Configures and opens the status bar dropdown menu.
    func openMenuDropdown(forAppID appID: String? = nil) {
        if let appID = appID {
            self.lastFrontmostAppID = appID
        }
        setupMenu()
        guard let menu = self.menu else { return }
        menu.delegate = self
        statusItem?.menu = menu

        // Activate app and open menu dropdown instantly
        NSApp.activate(ignoringOtherApps: true)
        // `popUpMenu(_:)` has been deprecated since 10.14. The documented
        // replacement is to hand the menu to the status item — done on the line
        // above — and then click its button, which opens the same dropdown in
        // the same place.
        self.statusItem?.button?.performClick(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        menu.update()
    }

    /// Tints and animates the menu bar button on left-click restore.
    private func flashStatusButton() {
        guard let button = statusItem?.button else { return }
        button.contentTintColor = NSColor.controlAccentColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            button.contentTintColor = nil
        }
    }





    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        guard menu === self.menu else { return }

        restoreHighlightedAutoSaveMenuIcon()
        stopAutoSaveMenuMarquee()
        guard let item else { return }

        if let icons = autoSaveMenuIconVariants[ObjectIdentifier(item)] {
            item.image = icons.highlighted
            highlightedAutoSaveMenuItem = item
        }

        guard autoSaveMenuMarqueeEntries[ObjectIdentifier(item)] != nil else { return }
        activeAutoSaveMenuMarqueeItem = item

        let startWorkItem = DispatchWorkItem { [weak self, weak item] in
            guard let self,
                  let item,
                  self.activeAutoSaveMenuMarqueeItem === item,
                  !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }

            self.autoSaveMenuMarqueeTimer = Timer.scheduledTimer(
                withTimeInterval: AutoSaveMenuLayout.marqueeInterval,
                repeats: true
            ) { [weak self, weak item] _ in
                MainActor.assumeIsolated {
                    guard let self,
                          let item,
                          self.activeAutoSaveMenuMarqueeItem === item else { return }
                    self.advanceAutoSaveMenuMarquee(for: item)
                }
            }
        }
        autoSaveMenuMarqueeStartWorkItem = startWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AutoSaveMenuLayout.marqueeStartDelay,
            execute: startWorkItem
        )
    }

    private func restoreHighlightedAutoSaveMenuIcon() {
        guard let item = highlightedAutoSaveMenuItem else { return }
        item.image = autoSaveMenuIconVariants[ObjectIdentifier(item)]?.normal
        highlightedAutoSaveMenuItem = nil
    }

    private func stopAutoSaveMenuMarquee() {
        autoSaveMenuMarqueeStartWorkItem?.cancel()
        autoSaveMenuMarqueeStartWorkItem = nil
        autoSaveMenuMarqueeTimer?.invalidate()
        autoSaveMenuMarqueeTimer = nil

        if let item = activeAutoSaveMenuMarqueeItem,
           let entry = autoSaveMenuMarqueeEntries[ObjectIdentifier(item)] {
            item.title = entry.initialTitle
        }

        activeAutoSaveMenuMarqueeItem = nil
        autoSaveMenuMarqueeOffset = 0
    }

    private func advanceAutoSaveMenuMarquee(for item: NSMenuItem) {
        let itemID = ObjectIdentifier(item)
        guard let entry = autoSaveMenuMarqueeEntries[itemID] else {
            stopAutoSaveMenuMarquee()
            return
        }

        let characters = Array(entry.fullTitle)
        guard !characters.isEmpty else { return }
        let cycleLength = characters.count + 3
        autoSaveMenuMarqueeOffset = (autoSaveMenuMarqueeOffset + 1) % cycleLength

        let repeatedTitle = characters + Array("   ") + characters
        var visibleTitle = ""
        for character in repeatedTitle.dropFirst(autoSaveMenuMarqueeOffset) {
            let candidate = visibleTitle + String(character)
            guard menuTitleWidth(candidate) <= AutoSaveMenuLayout.titleWidth else { break }
            visibleTitle = candidate
        }
        item.title = visibleTitle
    }

    private func setAutoSaveMenuTitle(_ title: String, on item: NSMenuItem) {
        let itemID = ObjectIdentifier(item)
        autoSaveMenuMarqueeEntries.removeValue(forKey: itemID)

        let initialTitle = truncatedMenuTitle(title, maxWidth: AutoSaveMenuLayout.titleWidth)
        item.title = initialTitle
        item.setAccessibilityLabel(title)

        if initialTitle != title {
            autoSaveMenuMarqueeEntries[itemID] = AutoSaveMenuMarqueeEntry(
                item: item,
                fullTitle: title,
                initialTitle: initialTitle
            )
        }
    }

    private func truncatedMenuTitle(_ title: String, maxWidth: CGFloat) -> String {
        guard menuTitleWidth(title) > maxWidth else { return title }

        let ellipsis = "…"
        var visiblePrefix = ""
        for character in title {
            let candidate = visiblePrefix + String(character) + ellipsis
            guard menuTitleWidth(candidate) <= maxWidth else { break }
            visiblePrefix += String(character)
        }
        return visiblePrefix.isEmpty ? ellipsis : visiblePrefix + ellipsis
    }

    private func setRootMenuTitle(_ title: String, on item: NSMenuItem) {
        let submenuWidth = item.submenu == nil ? 0 : AutoSaveMenuLayout.submenuColumnWidth
        let keyEquivalentWidth = item.keyEquivalent.isEmpty ? 0 : AutoSaveMenuLayout.keyEquivalentColumnWidth
        let trailingInset = submenuWidth == 0 && keyEquivalentWidth == 0
            ? AutoSaveMenuLayout.trailingInset
            : 0
        let titleWidth = max(
            0,
            AutoSaveMenuLayout.rootWidth - AutoSaveMenuLayout.leadingColumnWidth
                - submenuWidth - keyEquivalentWidth - trailingInset
        )
        item.title = truncatedMenuTitle(title, maxWidth: titleWidth)
        item.setAccessibilityLabel(title)
    }

    private func menuTitleWidth(_ title: String) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuFont(ofSize: 0)
        ]
        return ceil((title as NSString).size(withAttributes: attributes).width)
    }

    // Called right after the menu closes so we can detach it
    func menuDidClose(_ menu: NSMenu) {
        stopAutoSaveMenuMarquee()
        restoreHighlightedAutoSaveMenuIcon()
        autoSaveMenuIconVariants.removeAll()
        autoSaveMenuMarqueeEntries.removeAll()
        statusItem?.menu = nil
    }

    // MARK: - Menu

    private func checkForUpdatesAccessibilityLabel(_ title: String, hasAvailableUpdate: Bool) -> String {
        guard hasAvailableUpdate else { return title }
        return "\(title), \(lz("A new version of RememberMyWindows is available!"))"
    }

    private func menuSymbolImage(_ symbolName: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
            return nil
        }
        let targetSize = NSSize(width: 16, height: 16)
        let img = NSImage(size: targetSize, flipped: false) { rect in
            let bSize = base.size
            if bSize.width > 0 && bSize.height > 0 {
                let scale = min(targetSize.width / bSize.width, targetSize.height / bSize.height)
                let w = bSize.width * scale
                let h = bSize.height * scale
                let x = (targetSize.width - w) / 2
                let y = (targetSize.height - h) / 2
                base.draw(in: NSRect(x: x, y: y, width: w, height: h))
            } else {
                base.draw(in: rect)
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    private func applicationIconMenuImage() -> NSImage? {
        guard let appIcon = NSApplication.shared.applicationIconImage else {
            return nil
        }

        let targetSize = NSSize(width: 20, height: 20)
        let image = NSImage(size: targetSize, flipped: false) { rect in
            let iconSize = appIcon.size
            guard iconSize.width > 0, iconSize.height > 0 else { return false }

            let scale = min(rect.width / iconSize.width, rect.height / iconSize.height)
            let width = iconSize.width * scale
            let height = iconSize.height * scale
            let drawRect = NSRect(
                x: rect.midX - width / 2,
                y: rect.midY - height / 2,
                width: width,
                height: height
            )
            appIcon.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            return true
        }
        image.isTemplate = false
        return image
    }

    private func menuColoredSymbolImage(_ symbolName: String, color: NSColor) -> NSImage? {
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [color])
        let config = sizeConfig.applying(colorConfig)
        guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
            return nil
        }
        let targetSize = NSSize(width: 18, height: 16)
        let img = NSImage(size: targetSize, flipped: false) { rect in
            let bSize = base.size
            if bSize.width > 0 && bSize.height > 0 {
                let scale = min(targetSize.width / bSize.width, targetSize.height / bSize.height)
                let w = bSize.width * scale
                let h = bSize.height * scale
                let x = (targetSize.width - w) / 2
                let y = (targetSize.height - h) / 2
                base.draw(in: NSRect(x: x, y: y, width: w, height: h))
            } else {
                base.draw(in: rect)
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    private func menuAddedWindowsBadgeImage(_ count: Int, color: NSColor = .systemGreen) -> NSImage? {
        let countStr = "\(count)"
        let numberFont = NSFont.systemFont(ofSize: 11, weight: .bold)
        let plusFont = NSFont.systemFont(ofSize: 8.5, weight: .bold)

        let attrStr = NSMutableAttributedString()
        attrStr.append(NSAttributedString(
            string: countStr,
            attributes: [
                .font: numberFont,
                .foregroundColor: color
            ]
        ))
        attrStr.append(NSAttributedString(
            string: "+",
            attributes: [
                .font: plusFont,
                .foregroundColor: color,
                .baselineOffset: 2.0
            ]
        ))

        let textSize = attrStr.size()
        let targetWidth = max(18.0, ceil(textSize.width))
        let targetHeight: CGFloat = 16.0
        let targetSize = NSSize(width: targetWidth, height: targetHeight)

        let img = NSImage(size: targetSize, flipped: false) { _ in
            let x = (targetWidth - textSize.width) / 2
            let y = (targetHeight - textSize.height) / 2
            attrStr.draw(at: NSPoint(x: x, y: y))
            return true
        }
        img.isTemplate = false
        return img
    }

    private func setupMenu() {
        let menu = NSMenu()
        self.menu = menu
        menu.delegate = self
        menu.minimumWidth = AutoSaveMenuLayout.rootWidth

        if WindowManager.shared.store.autoSaveEnabled {
            setupAutoSaveMenu(menu)
            return
        }

        let activeAppID = lastFrontmostAppID ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let activeAppName: String? = {
            guard let appID = activeAppID, appID != "com.netanel.remembermywindows" else { return nil }
            return NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == appID })?.localizedName ?? appID
        }()

        // Only show app name in the title when that app is actually saved in the current session
        let activeAppIsSaved: Bool = {
            guard let appID = activeAppID,
                  let snap = WindowManager.shared.currentApplicableSnapshot else { return false }
            return snap.records.contains { $0.windowID.appBundleID == appID }
        }()

        let openTitle: String
        if let appName = activeAppName, activeAppIsSaved {
            openTitle = String(format: lz("Open RememberMyWindows (%@)"), appName)
        } else {
            openTitle = lz("Open RememberMyWindows")
        }

        let openItem = menu.addItem(withTitle: openTitle, action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.image = applicationIconMenuImage() ?? menuSymbolImage("macwindow.on.rectangle")
        setRootMenuTitle(openTitle, on: openItem)
        menu.addItem(NSMenuItem.separator())

        if let snap = WindowManager.shared.currentApplicableSnapshot {
            // Named after the layout the item will actually restore, which is the
            // Auto layout while that is on. `snap` stays the saved session for the
            // update item below, because there is nothing to update on an Auto
            // layout.
            let restoreSource = WindowManager.shared.automaticRestoreSnapshot()?.snapshot ?? snap
            let restoreTitle = String(format: lz("Full Restore '%@'"), restoreSource.displayName)
            let restoreItem = menu.addItem(withTitle: restoreTitle, action: #selector(restoreNow), keyEquivalent: "r")
            restoreItem.image = menuSymbolImage("arrow.counterclockwise")
            setRootMenuTitle(restoreTitle, on: restoreItem)

            let updateTitle = String(format: lz("Update Full Layout '%@'"), snap.displayName)
            let updateItem = menu.addItem(withTitle: updateTitle, action: #selector(saveLayout), keyEquivalent: "s")
            updateItem.isEnabled = !WindowManager.shared.isUpdateRestricted
            updateItem.image = menuSymbolImage("arrow.triangle.2.circlepath")
            setRootMenuTitle(updateTitle, on: updateItem)
            
            // Native Single App Add / Update Menu Item
            if let appID = activeAppID, appID != "com.netanel.remembermywindows" {
                let appName = activeAppName ?? appID
                let isSaved = snap.records.contains { $0.windowID.appBundleID == appID }
                
                let itemTitle = isSaved
                    ? String(format: lz("Update '%@' position"), appName)
                    : String(format: lz("Add '%@' to '%@'"), appName, snap.displayName)
                
                let singleAppItem = menu.addItem(withTitle: itemTitle, action: #selector(updateOrAddFrontmostApp), keyEquivalent: "")

                // Show the frontmost app's real icon at 16×16 instead of an SF Symbol
                let appIcon: NSImage? = NSWorkspace.shared.runningApplications
                    .first(where: { $0.bundleIdentifier == appID })?.icon
                if let icon = appIcon {
                    let scaled = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
                        icon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
                        return true
                    }
                    singleAppItem.image = scaled
                } else {
                    singleAppItem.image = menuSymbolImage(isSaved ? "arrow.clockwise" : "plus")
                }
                setRootMenuTitle(itemTitle, on: singleAppItem)
            }
            
            let groupSubmenu = WindowManager.shared.store.groupOtherAppsInSubmenu
            let uniqueRecords = snap.records.deduplicatedByApp
            let frontmostRecords = uniqueRecords.filter { $0.windowID.appBundleID == activeAppID }
            let activeRecords = groupSubmenu ? frontmostRecords : uniqueRecords
            let otherRecords = groupSubmenu
                ? uniqueRecords.filter { rec in !activeRecords.contains { $0.id == rec.id } }
                : []

            if !activeRecords.isEmpty {
                let listViewItem = NSMenuItem()
                let displayRecords = activeRecords
                let hostingView = NSHostingView(rootView: MenuWindowListView(snapshot: snap, activeBundleID: lastFrontmostAppID, specificRecords: displayRecords)
                    .environmentObject(WindowManager.shared)
                    .environment(\.locale, currentLocale))
                hostingView.wantsLayer = true
                hostingView.layout()
                let size = hostingView.fittingSize
                let viewHeight = size.height > 0 ? size.height : CGFloat(displayRecords.count * 36 + 12)
                hostingView.frame = CGRect(x: 0, y: 0, width: AutoSaveMenuLayout.rootWidth, height: viewHeight)
                hostingView.autoresizingMask = [.width]
                listViewItem.view = hostingView
                menu.addItem(listViewItem)
            }

            if groupSubmenu && !otherRecords.isEmpty {
                let otherAppsMenu = NSMenu()
                otherAppsMenu.minimumWidth = AutoSaveMenuLayout.windowListSubmenuWidth
                let otherAppsItem = NSMenuItem(title: lz("Others Saved in your session"), action: nil, keyEquivalent: "")
                otherAppsItem.image = menuSymbolImage("square.stack.3d.up")
                otherAppsItem.submenu = otherAppsMenu
                setRootMenuTitle(otherAppsItem.title, on: otherAppsItem)

                let submenuItem = NSMenuItem()
                let subHostingView = NSHostingView(rootView: MenuWindowListView(snapshot: snap, activeBundleID: lastFrontmostAppID, specificRecords: otherRecords)
                    .environmentObject(WindowManager.shared)
                    .environment(\.locale, currentLocale))
                subHostingView.wantsLayer = true
                subHostingView.layout()
                let subSize = subHostingView.fittingSize
                let subViewHeight = subSize.height > 0 ? subSize.height : CGFloat(otherRecords.count * 36 + 12)
                subHostingView.frame = CGRect(x: 0, y: 0, width: AutoSaveMenuLayout.windowListSubmenuWidth, height: subViewHeight)
                subHostingView.autoresizingMask = [.width]
                submenuItem.view = subHostingView
                otherAppsMenu.addItem(submenuItem)

                menu.addItem(otherAppsItem)
            }
        } else {
            let updateTitle = lz("Update Full Layout")
            let updateItem = menu.addItem(withTitle: updateTitle, action: #selector(saveLayout), keyEquivalent: "s")
            updateItem.isEnabled = !WindowManager.shared.isUpdateRestricted
            updateItem.image = menuSymbolImage("arrow.triangle.2.circlepath")
            setRootMenuTitle(updateTitle, on: updateItem)
            
            let restoreTitle = lz("Full Restore Default Layout")
            let restoreItem = menu.addItem(withTitle: restoreTitle, action: #selector(restoreNow), keyEquivalent: "r")
            restoreItem.image = menuSymbolImage("arrow.counterclockwise")
            setRootMenuTitle(restoreTitle, on: restoreItem)
        }

        // Saved sessions submenu
        let savedMenu = NSMenu()
        let savedItem = NSMenuItem(title: lz("Saved Sessions"), action: nil, keyEquivalent: "")
        savedItem.image = menuSymbolImage("folder")
        savedItem.submenu = savedMenu
        setRootMenuTitle(savedItem.title, on: savedItem)

        let savedSnapshots = WindowManager.shared.store.snapshots.values
            .filter { !$0.isAutoSave }
            .sorted { $0.updatedAt > $1.updatedAt }

        if savedSnapshots.isEmpty {
            savedMenu.addItem(withTitle: lz("No saved sessions"), action: nil, keyEquivalent: "")
        } else {
            let currentSnap = WindowManager.shared.currentApplicableSnapshot
            let themeStr = UserDefaults.standard.string(forKey: "themeColor") ?? "Default"
            let currentTheme = ThemeColor(rawValue: themeStr) ?? .default
            let languageString = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
            let menuLanguage = AppLanguage(rawValue: languageString) ?? .auto

            for snap in savedSnapshots {
                let isApplicable = (currentSnap?.id == snap.id)
                let itemTint = isApplicable ? currentTheme.color(seed: 0) : Color.primary
                let item = NSMenuItem(title: snap.displayName, action: #selector(restoreSpecificSnapshot(_:)), keyEquivalent: "")
                item.representedObject = snap.id.uuidString
                let badgeStatus: ScreenLayoutThumbnail.BadgeStatus? = isApplicable ? .live : nil
                if let thumb = ScreenLayoutThumbnail.renderImage(
                    screenKey: snap.screenKey,
                    tint: itemTint,
                    isLive: isApplicable,
                    badgeStatus: badgeStatus,
                    language: menuLanguage
                ) {
                    item.image = thumb
                }
                if let badgeStatus {
                    item.setAccessibilityLabel("\(snap.displayName), \(badgeStatus.localizedTitle(for: menuLanguage))")
                }
                savedMenu.addItem(item)
            }
        }
        menu.addItem(savedItem)

        menu.addItem(NSMenuItem.separator())
        addCheckForUpdatesMenuItem(to: menu)
        menu.addItem(makeVersionFooterMenuItem())

        menu.addItem(NSMenuItem.separator())
        let quitItem = menu.addItem(withTitle: lz("Quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.image = menuSymbolImage("power")
        setRootMenuTitle(quitItem.title, on: quitItem)
    }

    private func setupAutoSaveMenu(_ menu: NSMenu) {
        let openItem = NSMenuItem(
            title: lz("Open RememberMyWindows"),
            action: #selector(openMainWindow),
            keyEquivalent: "o"
        )
        openItem.target = self
        openItem.image = applicationIconMenuImage() ?? menuSymbolImage("macwindow.on.rectangle")
        setRootMenuTitle(openItem.title, on: openItem)
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())

        let headerTitle = lz("Recent Auto Captures")
        let headerItem = NSMenuItem()
        headerItem.isEnabled = false
        let headerView = NSView(frame: NSRect(x: 0, y: 0, width: AutoSaveMenuLayout.rootWidth, height: 20))
        let headerLabel = NSTextField(labelWithString: headerTitle)
        headerLabel.frame = NSRect(x: 16, y: 2, width: AutoSaveMenuLayout.rootWidth - 32, height: 16)
        headerLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        headerLabel.textColor = .secondaryLabelColor
        headerView.addSubview(headerLabel)
        headerItem.view = headerView
        menu.addItem(headerItem)

        let currentScreenKey = WindowManager.shared.currentFingerprint.key
        let captures = AutoLayoutCapturePresentation.make(
            from: WindowManager.shared.autoSaveStore?.entries(forScreenKey: currentScreenKey) ?? [],
            displayScreenKey: currentScreenKey,
            currentScreenKey: currentScreenKey
        )
        let matchingEntries = captures.compactMap { capture -> (AutoLayoutCapturePresentation, LayoutSnapshot)? in
            guard let snap = WindowManager.shared.snapshot(from: capture.entry) else { return nil }
            return (capture, snap)
        }

        if matchingEntries.isEmpty {
            let emptyItem = NSMenuItem(title: lz("No auto captures yet"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            setAutoSaveMenuTitle(emptyItem.title, on: emptyItem)
            menu.addItem(emptyItem)
        } else {
            let themeStr = UserDefaults.standard.string(forKey: "themeColor") ?? "Default"
            let currentTheme = ThemeColor(rawValue: themeStr) ?? .default
            let tint = currentTheme.color(seed: 0)
            let langStr = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
            let appLanguage = AppLanguage(rawValue: langStr) ?? .auto

            for (capture, snap) in matchingEntries {
                let entry = capture.entry
                let title = capture.title(at: Date(), language: appLanguage)

                let item = NSMenuItem(
                    title: title,
                    action: #selector(restoreAutoSaveEntry(_:)),
                    keyEquivalent: ""
                )
                setAutoSaveMenuTitle(title, on: item)
                item.representedObject = entry.id.uuidString

                let indicator = capture.changeIndicator

                let normalIcon: NSImage?
                let highlightedIcon: NSImage?
                switch indicator {
                case .sameWindowCount:
                    normalIcon = menuColoredSymbolImage(
                        "rectangle.and.arrow.up.right.and.arrow.down.left",
                        color: indicator.nsColor
                    )
                    highlightedIcon = menuColoredSymbolImage(
                        "rectangle.and.arrow.up.right.and.arrow.down.left",
                        color: .black
                    )
                case .addedWindows(let difference):
                    normalIcon = menuAddedWindowsBadgeImage(difference, color: indicator.nsColor)
                    highlightedIcon = menuAddedWindowsBadgeImage(difference, color: .black)
                case .history:
                    normalIcon = menuColoredSymbolImage("clock.arrow.circlepath", color: indicator.nsColor)
                    highlightedIcon = menuColoredSymbolImage("clock.arrow.circlepath", color: .black)
                case .displayConnected:
                    normalIcon = menuColoredSymbolImage("display.2", color: indicator.nsColor)
                    highlightedIcon = menuColoredSymbolImage("display.2", color: .black)
                case .displayDisconnected:
                    normalIcon = menuSymbolImage("laptopcomputer")
                    highlightedIcon = menuSymbolImage("laptopcomputer")
                }

                item.image = normalIcon
                if let normalIcon, let highlightedIcon {
                    autoSaveMenuIconVariants[ObjectIdentifier(item)] = (
                        normal: normalIcon,
                        highlighted: highlightedIcon
                    )
                }

                // Hover flyout showing the visual preview and its title-row restore action.
                let previewMenu = NSMenu()
                previewMenu.minimumWidth = AutoSaveMenuLayout.previewWidth
                let previewMenuItem = NSMenuItem()
                let entryID = entry.id

                let previewView = AutoSavePreviewCardView(
                    snapshot: snap,
                    menuWidth: AutoSaveMenuLayout.previewWidth,
                    indicator: indicator,
                    activityApps: capture.activityApps,
                    triggeringRecordIDs: capture.triggeringRecordIDs,
                    tint: tint,
                    language: appLanguage,
                    onRestore: {
                        NSApp.sendAction(#selector(NSMenu.cancelTracking), to: nil, from: nil)
                        WindowManager.shared.restoreAutoLayout(entryID: entryID, showNotification: true)
                    }
                )

                let hostingView = NSHostingView(rootView: previewView)
                hostingView.wantsLayer = true
                hostingView.frame = CGRect(x: 0, y: 0, width: AutoSaveMenuLayout.previewWidth, height: 210)
                previewMenuItem.view = hostingView
                previewMenu.addItem(previewMenuItem)

                item.submenu = previewMenu
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())
        addCheckForUpdatesMenuItem(to: menu)
        menu.addItem(makeVersionFooterMenuItem())

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: lz("Quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = menuSymbolImage("power")
        setRootMenuTitle(quitItem.title, on: quitItem)
        menu.addItem(quitItem)
    }

    private func addCheckForUpdatesMenuItem(to menu: NSMenu) {
        let title = lz("Check for Updates…")
        let item = NSMenuItem(title: title, action: #selector(checkForUpdates), keyEquivalent: "")
        item.target = self
        item.image = menuSymbolImage("arrow.down.circle")
        let hasAvailableUpdate = UpdateManager.shared.hasAvailableUpdate
        let displayTitle = hasAvailableUpdate ? "\(title)\(lz(" (Update Available)"))" : title
        setRootMenuTitle(displayTitle, on: item)
        item.setAccessibilityLabel(
            checkForUpdatesAccessibilityLabel(title, hasAvailableUpdate: hasAvailableUpdate)
        )
        menu.addItem(item)
    }

    private func makeVersionFooterMenuItem() -> NSMenuItem {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let versionText = "RememberMyWindows v\(version)"
        let item = NSMenuItem()
        item.isEnabled = false

        let footerView = NSView(frame: NSRect(x: 0, y: 0, width: AutoSaveMenuLayout.rootWidth, height: 20))
        footerView.autoresizingMask = [.width]

        let label = NSTextField(labelWithString: versionText)
        label.frame = NSRect(x: 16, y: 2, width: AutoSaveMenuLayout.rootWidth - 32, height: 16)
        label.autoresizingMask = [.width]
        label.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        footerView.addSubview(label)

        item.view = footerView
        return item
    }

    @objc private func restoreAutoSaveEntry(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let id = UUID(uuidString: idString) else { return }
        WindowManager.shared.restoreAutoLayout(entryID: id, showNotification: true)
    }

    /// Native macOS menu bar item background highlight + white icon tint for 0.3s on right-click restore.
    private func animateRightClickStatusButton() {
        guard let button = statusItem?.button else { return }
        
        button.isHighlighted = true
        button.contentTintColor = .white
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            button.isHighlighted = false
            button.contentTintColor = nil
        }
    }

    // MARK: - Actions

    @objc private func openMainWindow() {
        let manager = WindowManager.shared
        if manager.store.autoSaveEnabled {
            // Auto Layout has no named saved session to select. Clear the
            // saved-session context so the Auto Layout screen starts cleanly.
            manager.selectedSnapshotKey = nil
            manager.selectedAppBundleID = nil
        } else if let snapshot = manager.currentApplicableSnapshot,
                  let key = manager.store.snapshots.first(where: { $0.value.id == snapshot.id })?.key {
            // The menu was built from this current session. Keep that same
            // session selected when opening the main window, then pass along
            // the app that was frontmost before the menu took focus. The
            // detail view uses this ID to center the matching saved card.
            manager.selectedSnapshotKey = key
            let currentAppID = lastFrontmostAppID
            manager.selectedAppBundleID = currentAppID.flatMap { appID in
                snapshot.records.contains { $0.windowID.appBundleID == appID } ? appID : nil
            }
        } else {
            // No saved session matches the current displays; fall back to the
            // live layout rather than leaving the detail pane without content.
            manager.selectedSnapshotKey = WindowManager.liveKey
            manager.selectedAppBundleID = nil
        }
        showMainWindow()
    }

    func showMainWindow() {
        // Just ensure activation policy is correct; updateActivationPolicy will handle it too
        NSApp.setActivationPolicy(.regular)

        if let existingWindow = NSApp.windows.first(where: { isMainWindow($0) }) {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Use the URL scheme to trigger SwiftUI's Window handling if window was destroyed.
        if let url = URL(string: "remembermywindows://main") {
            NSWorkspace.shared.open(url)
        }

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // Holds a strong reference to the position HUD while it's shown
    private var positionHUD: NotchPositionHUDWindow?

    @objc private func updateOrAddFrontmostApp() {
        let activeAppID = lastFrontmostAppID ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard let appID = activeAppID else { return }

        let appName = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == appID })?
            .localizedName ?? appID

        // Dismiss any existing HUD before showing a new one
        positionHUD?.close()
        positionHUD = nil

        let presentHUD = { [weak self] in
            guard let self = self else { return }
            let hud = NotchPositionHUDWindow(appName: appName, bundleID: appID)
            if WindowManager.shared.store.coexistWithVorssaintNotch {
                hud.onDismissCompleted = {
                    VorssaintNotchCoordinator.shared.didDismissPill()
                }
            }
            hud.onDone = { [weak self] in
                WindowManager.shared.updateOrAddAppInActiveSnapshot(bundleID: appID)
                self?.positionHUD = nil
            }
            hud.onCancel = { [weak self] in
                self?.positionHUD = nil
            }
            hud.show()
            self.positionHUD = hud
        }

        if WindowManager.shared.store.coexistWithVorssaintNotch {
            VorssaintNotchCoordinator.shared.prepareForPill(completion: presentHUD)
        } else {
            presentHUD()
        }
    }

    @objc private func saveLayout() {
        WindowManager.shared.saveNow()
    }

    @objc private func restoreNow() {
        WindowManager.shared.restoreNow(automatic: true)
    }

    @objc private func restoreSelected() {
        if let key = WindowManager.shared.selectedSnapshotKey {
            WindowManager.shared.restore(key: key)
        } else {
            WindowManager.shared.restoreNow(automatic: true)
        }
    }

    @objc private func restoreSpecificSnapshot(_ sender: NSMenuItem) {
        if let idString = sender.representedObject as? String,
           let key = WindowManager.shared.store.snapshots.first(where: { $0.value.id.uuidString == idString })?.key {
            WindowManager.shared.restore(key: key)
        }
    }

    @objc private func restoreSpecificApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String,
              let source = WindowManager.shared.automaticRestoreSnapshot(forAppLaunch: bundleID) else { return }
        WindowManager.shared.restore(snapshot: source.snapshot,
                                     specificAppBundleID: bundleID,
                                     skipCommandSend: source.isAuto)
    }

    @objc private func checkForUpdates() {
        UpdateManager.shared.checkForUpdates(manual: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let quickKeyRestoreSettingChanged = Notification.Name("quickKeyRestoreSettingChanged")
    static let capsLockRestoreSettingChanged = Notification.Name("quickKeyRestoreSettingChanged")
}
