//
//  VorssaintNotchCoordinator.swift
//  RememberMyWindows
//
//  Coordinates with the third-party Vorssaint utility (com.vorssaint.utils)
//  to temporarily shift its "Dynamic Island" notch window off-screen when
//  RememberMyWindows displays any notch pill, restoring it upon pill dismissal.
//

import AppKit
import ApplicationServices

@MainActor
final class VorssaintNotchCoordinator {
    static let shared = VorssaintNotchCoordinator()

    private let bundleID = "com.vorssaint.utils"
    private let targetWindowTitle = "Dynamic Island"

    private var originalPosition: CGPoint?
    private var shiftedWindowElement: AXUIElement?
    private var activePillCount = 0
    private var pendingRestoreWorkItem: DispatchWorkItem?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Checks whether Vorssaint is currently running and has an active Dynamic Island window.
    func isVorssaintNotchActive() -> Bool {
        guard let window = findVorssaintIslandWindow() else { return false }
        return getWindowPosition(window) != nil
    }

    /// Checks whether the Vorssaint application is currently running.
    func isVorssaintRunning() -> Bool {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
              !app.isTerminated else { return false }
        return true
    }

    /// Loads the Vorssaint app icon (32x32) from the installed app, bundled resources, or local file.
    func loadVorssaintIcon() -> NSImage? {
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: appUrl.path)
            icon.size = NSSize(width: 32, height: 32)
            return icon
        }
        if let resourceUrl = Bundle.main.url(forResource: "VorssaintAppIcon", withExtension: "png"),
           let img = NSImage(contentsOf: resourceUrl) {
            img.size = NSSize(width: 32, height: 32)
            return img
        }
        let localPath = "WindowLayout/VorssaintAppIcon.png"
        if FileManager.default.fileExists(atPath: localPath),
           let img = NSImage(contentsOfFile: localPath) {
            img.size = NSSize(width: 32, height: 32)
            return img
        }
        return nil
    }

    /// Prepares the notch area for an upcoming RememberMyWindows pill.
    /// If Vorssaint is active, shifts its Dynamic Island window off-screen immediately
    /// and invokes `completion` to allow the pill to drop down.
    /// If Vorssaint is not running or inactive, `completion` is called immediately with zero latency.
    func prepareForPill(completion: @escaping () -> Void) {
        // Cancel any pending restoration so Vorssaint stays hidden while the new pill is active
        pendingRestoreWorkItem?.cancel()
        pendingRestoreWorkItem = nil

        activePillCount += 1

        // If Vorssaint is already shifted by a previous overlapping pill, proceed immediately.
        if activePillCount > 1, shiftedWindowElement != nil {
            completion()
            return
        }

        guard let window = findVorssaintIslandWindow(),
              let currentPos = getWindowPosition(window) else {
            completion()
            return
        }

        // Only store original position if it's currently on-screen (not already negative Y)
        if originalPosition == nil || currentPos.y >= 0 {
            originalPosition = currentPos
        }
        shiftedWindowElement = window

        // Shift Vorssaint off-screen immediately, then wait 0.25s breathing room before showing the pill
        shiftWindowOffscreen(window, from: currentPos)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            completion()
        }
    }

    /// Called when any RememberMyWindows notch pill has finished its dismiss animation
    /// and completely closed. Restores Vorssaint after a 1.0s pause once all active pills have dismissed.
    func didDismissPill() {
        activePillCount = max(0, activePillCount - 1)

        guard activePillCount == 0 else { return }

        // Cancel previous pending restore if any
        pendingRestoreWorkItem?.cancel()

        // Wait a comfortable 1.0s pause after the pill vanishes before restoring Vorssaint
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.activePillCount == 0 else { return }
            self.restoreWindowPosition()
            self.pendingRestoreWorkItem = nil
        }
        pendingRestoreWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    // MARK: - Internal Helpers

    private func findVorssaintIslandWindow() -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
              !app.isTerminated else { return nil }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let axWindows = windowsRef as? [AXUIElement] else { return nil }

        for window in axWindows {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
               let title = titleRef as? String,
               title == targetWindowTitle {
                return window
            }
        }
        return nil
    }

    private func getWindowPosition(_ window: AXUIElement) -> CGPoint? {
        var posRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(posRef as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func shiftWindowOffscreen(_ window: AXUIElement, from currentPos: CGPoint) {
        var offscreenPoint = CGPoint(x: currentPos.x, y: -1200)
        guard let offscreenVal = AXValueCreate(.cgPoint, &offscreenPoint) else { return }
        _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, offscreenVal)
    }

    private func restoreWindowPosition() {
        guard let window = shiftedWindowElement ?? findVorssaintIslandWindow(),
              let original = originalPosition else {
            originalPosition = nil
            shiftedWindowElement = nil
            return
        }

        var restorePoint = original
        if let restoreVal = AXValueCreate(.cgPoint, &restorePoint) {
            _ = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, restoreVal)
        }

        originalPosition = nil
        shiftedWindowElement = nil
    }

    @objc private func handleAppWillTerminate() {
        pendingRestoreWorkItem?.cancel()
        pendingRestoreWorkItem = nil
        restoreWindowPosition()
    }
}

